# PHASE 1 — Control Plane: Multi-Tenancy and Identity

**Goal:** Establish the multi-tenant control plane foundations (tenants/workspaces, identity, config, secrets, region pinning) that every other capability relies on.

## P0 / Critical

- [ ] **Data model + migrations (multi-tenant from day 1)**
  - Minimum tables/entities:
    - Tenant, Workspace, User/Principal, Role/Group mapping
    - ProviderKey (BYO keys) + encryption metadata
    - ConnectorInstallations (per workspace)
    - Workflow (definition) + WorkflowVersion (pinned, immutable)
    - Run, Step, ApprovalRequest/Decision
    - AuditEvent (append-only hash chain pointers)
    - MeteringEvent (LLM usage + connector ops)
  - DoD:
    - DB migrations are idempotent.
    - Tenant/workspace isolation is enforced in queries (row-level scoping via app logic or RLS).

- [ ] **Identity: OIDC login + service auth**
  - Web UI + API:
    - OIDC login (enterprise IdP) with workspace membership mapping.
    - Service-to-service auth (mTLS or JWT with short TTL).
  - DoD:
    - A tenant admin can invite/map users and assign roles.
    - Every API call has an authenticated principal and workspace scope.

- [ ] **Authorization: minimal RBAC with governance roles**
  - Roles (suggested):
    - WorkspaceAdmin, Operator, Approver, Auditor (read-only), IntegrationAdmin
  - DoD:
    - Permissions enforced server-side on all endpoints.
    - Auditor cannot perform writes.

- [ ] **Region pinning: US + EU from day 1**
  - Per-tenant region field (immutable after creation, or controlled migration).
  - Ensure:
    - Data stores, queues, logs, and evidence bundles remain in-region.
  - DoD:
    - Tenant creation API requires region.
    - Cross-region calls are blocked by design (explicit deny).

- [ ] **Tenant data mode: metadata-only default**
  - Enforce “no content persistence/indexing” unless tenant opts in.
  - Clarify what is “content” vs “metadata” for ITSM:
    - Metadata: IDs, timestamps, classifications, categories, token counts, action receipts.
    - Content (optional): full ticket text, chat transcripts, attachments.
  - DoD:
    - Config flag per tenant/workspace.
    - Storage pipeline checks flag and redacts/avoids persistence.

- [ ] **BYO provider keys (OpenAI + Azure OpenAI + Anthropic)**
  - Store encrypted at rest (KMS envelope or equivalent).
  - Validate keys on entry (non-destructive test call + rate limit).
  - DoD:
    - Keys are never logged.
    - Rotation supported (new key becomes active without downtime).

- [ ] **Public API surface (control plane)**
  - Implement minimal endpoints for:
    - Tenant/workspace bootstrap
    - Workflow CRUD + version publish
    - Connector install + credential set
    - Run listing + detail
  - DoD:
    - OpenAPI updated + generated stubs compile.

## P1 / High

- [ ] **Workspace settings UI**
  - Region, data mode, retention, write caps, approval tiers.
- [ ] **API rate limits + quotas**
  - Per tenant/workspace (protect multi-tenant stability).

## P2 / Medium

- [ ] **SCIM / automated provisioning** (enterprise convenience)
- [ ] **Org hierarchy features**
  - Multiple workspaces per tenant with shared policies.

## P3 / Low

- [ ] **Self-serve signup**
  - Probably not needed for enterprise high-touch.

## Exit gate

- [ ] You can create a tenant + workspace in US or EU, log in via OIDC, store BYO keys, create/publish a workflow version, and list it via API/UI with isolation guarantees.
