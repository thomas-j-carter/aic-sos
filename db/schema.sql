-- MVP schema sketch (see data/db-schema.md for rationale + RLS notes)
-- Intended for Postgres 15+.

-- NOTE: This file is intentionally not a complete migration set.
-- In-repo migrations should split DDL into ordered migration files.

-- Tenancy
create table if not exists tenants (
  tenant_id uuid primary key,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists workspaces (
  workspace_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  name text not null,
  region text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, name)
);
create index if not exists workspaces_tenant_idx on workspaces(tenant_id);

-- Workflows
create table if not exists workflows (
  workflow_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  unique (workspace_id, name)
);

create table if not exists workflow_versions (
  workflow_version_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workflow_id uuid not null references workflows(workflow_id) on delete cascade,
  version text not null,
  definition_yaml text not null,
  definition_digest bytea not null,
  model_pin jsonb not null,
  risk_tier text not null default 'low',
  created_at timestamptz not null default now(),
  unique (workflow_id, version)
);

-- Policies
create table if not exists policies (
  policy_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  name text not null,
  version text not null,
  policy_yaml text not null,
  policy_digest bytea not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, name, version)
);

create table if not exists policy_bindings (
  policy_binding_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  policy_id uuid not null references policies(policy_id) on delete cascade,
  workflow_id uuid null references workflows(workflow_id) on delete cascade,
  workflow_version_id uuid null references workflow_versions(workflow_version_id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Runtime
do $$ begin
  create type run_status as enum (
    'queued','running','waiting_approval','succeeded','failed_retryable','failed_terminal','canceled'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type step_status as enum (
    'ready','running','waiting_approval','succeeded','failed_retryable','failed_terminal','canceled'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type approval_status as enum ('requested','approved','rejected','expired','canceled');
exception when duplicate_object then null;
end $$;

create table if not exists runs (
  run_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  workflow_version_id uuid not null references workflow_versions(workflow_version_id) on delete restrict,
  trigger_type text not null,
  trigger_ref text null,
  status run_status not null default 'queued',
  started_at timestamptz null,
  finished_at timestamptz null,
  input_metadata jsonb not null default '{}'::jsonb,
  output_metadata jsonb not null default '{}'::jsonb,
  total_cost_usd numeric(12,6) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists steps (
  step_pk uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  run_id uuid not null references runs(run_id) on delete cascade,
  step_id text not null,
  step_index int not null,
  tool_name text not null,
  status step_status not null default 'ready',
  attempt int not null default 0,
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

create table if not exists approvals (
  approval_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  run_id uuid not null references runs(run_id) on delete cascade,
  step_id text not null,
  tier text not null,
  status approval_status not null default 'requested',
  requested_by text not null,
  approver text null,
  request_metadata jsonb not null default '{}'::jsonb,
  decision_metadata jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default now(),
  resolved_at timestamptz null
);

create table if not exists action_receipts (
  receipt_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  run_id uuid not null references runs(run_id) on delete cascade,
  step_id text not null,
  connector_type text not null,
  operation text not null,
  reversible boolean not null default false,
  reversed_by_receipt_id uuid null references action_receipts(receipt_id),
  request_metadata jsonb not null default '{}'::jsonb,
  response_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists artifacts (
  artifact_id uuid primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  run_id uuid null references runs(run_id) on delete set null,
  artifact_type text not null,     -- "evidence_bundle" | "export" | ...
  uri text not null,              -- s3://... or presigned url stored elsewhere
  sha256 bytea not null,
  size_bytes bigint not null,
  mime text not null,
  created_at timestamptz not null default now()
);

create table if not exists audit_log (
  audit_id bigserial primary key,
  tenant_id uuid not null references tenants(tenant_id) on delete cascade,
  workspace_id uuid not null references workspaces(workspace_id) on delete cascade,
  actor_type text not null,
  actor_id text not null,
  action text not null,
  resource_type text not null,
  resource_id text not null,
  decision jsonb not null default '{}'::jsonb,
  policy_digest bytea null,
  prev_hash bytea null,
  entry_hash bytea not null,
  created_at timestamptz not null default now()
);
