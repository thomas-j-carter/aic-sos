# Postgres schema sketch + RLS (MVP)

This is a **sketch** of the MVP relational model that matches the locked decisions:

- **Multi-tenant from day 1** (tenant_id everywhere; optional workspace_id for subdivisions)
- **Fail-closed** access controls (RLS denies if tenant context is missing)
- **Metadata-only by default** (no content indexing/persistence unless opted-in)
- **Hash-chained append-only audit** (per tenant/workspace integrity chain)
- **Region pinning (US + EU)** (workspace pinned to region/cell; no cross-region replication by default)

> Conventions
> - `uuid` ids, `timestamptz` timestamps.
> - `jsonb` for tool/model/provider payloads (bounded + validated at the app layer).
> - `*_metadata` means **non-sensitive** and **tenant-approved** fields only.

## 1) Canonical tenancy

```sql
create table tenants (
  tenant_id uuid primary key,
  name text not null,
  created_at timestamptz not null default now()
);

-- A workspace is the unit of regional pinning + policy binding in MVP
create table workspaces (
  workspace_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  name text not null,
  -- e.g. "us-east-1", "eu-west-1"
  region text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, name)
);
create index on workspaces(tenant_id);
```

## 2) Workflow + policy versioning (pinned + diffable)

```sql
create table workflows (
  workflow_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  unique (workspace_id, name)
);

create table workflow_versions (
  workflow_version_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workflow_id uuid not null references workflows(workflow_id) on delete cascade,
  -- semver string (validated in app)
  version text not null,
  -- canonical YAML text stored for traceability; kept small (limits)
  definition_yaml text not null,
  -- sha256 of canonicalized YAML
  definition_digest bytea not null,
  -- model/provider pinning, e.g. {"provider":"openai","model":"gpt-5","temperature":0.2}
  model_pin jsonb not null,
  -- risk tier or labels used for governance gates (e.g. "low|med|high")
  risk_tier text not null default 'low',
  created_at timestamptz not null default now(),
  unique (workflow_id, version)
);
create index on workflow_versions(tenant_id, workflow_id);
```

```sql
create table policies (
  policy_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  name text not null,
  version text not null,
  policy_yaml text not null,
  policy_digest bytea not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, name, version)
);

-- binds a policy version to a workspace and optionally a workflow/version
create table policy_bindings (
  policy_binding_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  policy_id uuid not null references policies(policy_id) on delete cascade,
  workflow_id uuid null references workflows(workflow_id) on delete cascade,
  workflow_version_id uuid null references workflow_versions(workflow_version_id) on delete cascade,
  created_at timestamptz not null default now()
);
create index on policy_bindings(tenant_id, workspace_id);
```

## 3) Runs, steps, approvals, and action receipts

The runtime is **at-least-once**; therefore:
- steps must be **idempotent** (store idempotency keys + receipts)
- reversible writes are allowed (assignment/labels/internal notes), gated by policy + caps.

```sql
create type run_status as enum (
  'queued','running','waiting_approval','succeeded','failed_retryable','failed_terminal','canceled'
);

create table runs (
  run_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  workflow_version_id uuid not null references workflow_versions(workflow_version_id) on delete restrict,
  trigger_type text not null,        -- e.g. "webhook"
  trigger_ref text null,             -- connector's event id for idempotency
  status run_status not null default 'queued',
  started_at timestamptz null,
  finished_at timestamptz null,
  input_metadata jsonb not null default '{}'::jsonb,
  output_metadata jsonb not null default '{}'::jsonb,
  -- cost rollups
  total_cost_usd numeric(12,6) not null default 0,
  created_at timestamptz not null default now()
);
create index on runs(tenant_id, workspace_id, created_at desc);
create index on runs(tenant_id, status);
```

```sql
create type step_status as enum (
  'ready','running','waiting_approval','succeeded','failed_retryable','failed_terminal','canceled'
);

create table steps (
  step_pk uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  run_id uuid not null references runs(run_id) on delete cascade,
  -- stable identifier from YAML (e.g. "classify_incident")
  step_id text not null,
  step_index int not null,
  tool_name text not null,            -- e.g. "servicenow.update_incident"
  status step_status not null default 'ready',
  attempt int not null default 0,
  -- required for idempotency in at-least-once execution
  idempotency_key text not null,
  lease_owner text null,
  lease_expires_at timestamptz null,
  started_at timestamptz null,
  finished_at timestamptz null,
  input_metadata jsonb not null default '{}'::jsonb,
  output_metadata jsonb not null default '{}'::jsonb,
  last_error jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (run_id, step_id),
  unique (tenant_id, idempotency_key)
);
create index on steps(tenant_id, run_id, step_index);
create index on steps(tenant_id, status);
```

```sql
create type approval_status as enum ('requested','approved','rejected','expired','canceled');

create table approvals (
  approval_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  run_id uuid not null references runs(run_id) on delete cascade,
  step_id text not null,
  -- policy tier, e.g. "low|med|high" and optional "two_person"
  tier text not null,
  status approval_status not null default 'requested',
  requested_by text not null,     -- "system" or user id
  approver text null,             -- user id or email
  request_metadata jsonb not null default '{}'::jsonb,
  decision_metadata jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default now(),
  resolved_at timestamptz null
);
create index on approvals(tenant_id, workspace_id, requested_at desc);
create index on approvals(tenant_id, status);
```

```sql
-- Receipts for every external side-effect (including reversible writes)
create table action_receipts (
  receipt_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  run_id uuid not null references runs(run_id) on delete cascade,
  step_id text not null,
  connector_type text not null,   -- "servicenow" | "slack" | "github"
  operation text not null,        -- e.g. "incident.update"
  reversible boolean not null default false,
  reversed_by_receipt_id uuid null references action_receipts(receipt_id),
  request_metadata jsonb not null default '{}'::jsonb,
  response_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index on action_receipts(tenant_id, run_id, created_at);
```

## 4) Hash-chained append-only audit

In MVP we keep the audit table append-only and maintain a **hash chain** per `(tenant_id, workspace_id)`.

```sql
create table audit_log (
  audit_id bigserial primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  actor_type text not null,       -- "user" | "service" | "system"
  actor_id text not null,
  action text not null,           -- "policy.evaluate" | "connector.write" | ...
  resource_type text not null,    -- "run" | "ticket" | "workflow" | ...
  resource_id text not null,
  decision jsonb not null default '{}'::jsonb,
  policy_digest bytea null,
  prev_hash bytea null,
  entry_hash bytea not null,
  created_at timestamptz not null default now()
);
create index on audit_log(tenant_id, workspace_id, audit_id);
```

**Hashing rule (recommended):**
- `entry_hash = sha256(prev_hash || canonical_json(entry_without_hash_fields))`
- `prev_hash = entry_hash of the previous audit row for the same (tenant_id, workspace_id)`

This makes tampering detectable without external anchoring.

## 5) RLS (row-level security) + fail-closed pattern

### 5.1 Enable RLS
Enable RLS on all tenant-scoped tables:

```sql
alter table workspaces enable row level security;
alter table workflows enable row level security;
alter table workflow_versions enable row level security;
alter table policies enable row level security;
alter table policy_bindings enable row level security;
alter table runs enable row level security;
alter table steps enable row level security;
alter table approvals enable row level security;
alter table action_receipts enable row level security;
alter table audit_log enable row level security;
```

### 5.2 Tenant context function
Set tenant context per request/transaction in the app:

```sql
-- app sets these via SET LOCAL (inside transaction)
-- SET LOCAL app.tenant_id = '<uuid>';
-- SET LOCAL app.workspace_id = '<uuid>' (optional)

create or replace function app_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('app.tenant_id', true), '')::uuid
$$;
```

### 5.3 Fail-closed policies
Example for `runs`:

```sql
create policy runs_isolation on runs
  using (
    app_tenant_id() is not null
    and tenant_id = app_tenant_id()
  )
  with check (
    app_tenant_id() is not null
    and tenant_id = app_tenant_id()
  );
```

Repeat across tables (often `tenant_id = app_tenant_id()` plus optional `workspace_id = current_setting('app.workspace_id')`).

### 5.4 Service roles
Use dedicated DB roles:
- `app_reader` (read-only where appropriate)
- `app_writer` (write allowed)
- `migration` (DDL)
- Avoid `bypassrls` in runtime roles.

## 6) Notes for metadata-only default

**Do not store connector payload bodies** by default. Store only:
- external ids, timestamps, and normalized fields needed for routing/classification
- hashes + sizes for evidence tracking
- retention policies and explicit opt-ins for content persistence/indexing

Evidence bundles can be generated as export artifacts (`artifacts` table) with pointers to object storage (S3) and hashes.
