# PHASE-1 Review: Control Plane Multi-Tenancy & Identity

**Status:** 🔍 REVIEWED  
**Date:** December 19, 2024  
**Reviewer:** GitHub Copilot  

## Summary

PHASE-1 establishes the multi-tenant control plane foundations. This is the **critical foundation** that every other capability (workflows, execution, connectors, evidence) depends on.

**Scope:** 6 P0 tasks (critical)  
**Estimated Effort:** 2-3 days (16-24 hours)  
**Exit Gate:** Create tenant + workspace → OIDC login → Store BYO keys → Publish workflow → List via API with isolation

## P0 Tasks (Critical) - Detailed Breakdown

### Task 1: Data Model + Migrations (Multi-Tenant from Day 1)

**Scope:**
- Create database schema with multi-tenant isolation from the start
- Migrations must be idempotent and reproducible

**Required Tables/Entities:**

1. **Tenancy Layer**
   - `tenants` — Organization container (USD or EU pinned)
   - `workspaces` — Isolated operation environments within tenant
   - `environments` — dev/test/prod tiers (mentioned but optional MVP)

2. **Identity Layer**
   - `users` — Human/service principals
   - `roles` — WorkspaceAdmin, Operator, Approver, Auditor, IntegrationAdmin
   - `role_bindings` — User ↔ Role ↔ Workspace assignments
   - `api_keys` — Service-to-service authentication

3. **Secrets & Configuration**
   - `provider_keys` — BYO OpenAI/Azure/Anthropic keys (encrypted at rest)
   - `connector_installations` — Per-workspace connector instances with credentials
   - `workspace_config` — Tenant/workspace settings (data mode, retention, quotas)

4. **Workflows (Immutable Versioning)**
   - `workflows` — Workflow definitions (template)
   - `workflow_versions` — Immutable pinned versions (publish once, never update)
   - `policy_bindings` — Which policies apply to which workflows

5. **Runtime (Execution Tracking)**
   - `runs` — Workflow execution instances
   - `steps` — Individual step executions within a run
   - `approval_requests` — HITL approval gates
   - `approval_decisions` — Approval outcomes

6. **Audit & Metering (Compliance)**
   - `audit_events` — Hash-chained append-only log
   - `metering_events` — LLM token usage + connector operations

**Design Constraints:**
- ✅ Tenant/workspace isolation enforced in all queries (row-level security or app logic)
- ✅ Foreign keys cascade on delete (except workflow_version_id on runs: restrict)
- ✅ Immutable versioning on workflow_versions (version is unique per workflow)
- ✅ Region field on workspace (immutable after creation)
- ✅ Timestamps (created_at, started_at, finished_at) for audit
- ✅ UUIDs for all primary keys (scalability, replication)

**Status in Repo:**
- ✅ `db/schema.sql` exists (187 lines, partial schema)
- ✅ `data/entities.md` exists (entity mapping)
- ✅ `data/db-schema.md` exists (RLS notes)
- ⏳ **Missing:** Migration framework (Migrate, Flyway, or hand-rolled in Go)

**DoD (Definition of Done):**
- [ ] Migration files created (01-tenancy.sql, 02-identity.sql, etc.)
- [ ] All tables have tenant_id foreign key
- [ ] Indexes on tenant_id, workspace_id for query performance
- [ ] Row-level security policy documented (RLS or app-level scoping)
- [ ] Migrations are idempotent (safe to rerun)
- [ ] Control plane can run migrations at startup

---

### Task 2: Identity - OIDC Login + Service Auth

**Scope:**
- User authentication (Web UI + API)
- Service-to-service authentication
- Workspace membership mapping
- Principal context on every API call

**Requirements:**

1. **OIDC (OpenID Connect) Login**
   - Enterprise IdP integration (Auth0, Okta, Azure AD, etc.)
   - Workspace membership discovered from ID token claims or provisioning API
   - Web UI: Redirect to IdP → Callback → Set session cookie → Authenticated
   - Mobile: JWT refresh token workflow (short-lived access token + long-lived refresh)

2. **Service Authentication**
   - Agents, connectors, or batch jobs: API key OR mTLS
   - Service account provisioning (create service principal with API key)
   - Key rotation without downtime

3. **Principal Context**
   - Every API call must include: `principal_id`, `workspace_id`, `tenant_id`
   - Middleware extracts from JWT claim or API key lookup
   - Request context carries principal for authorization + audit

**Design Decisions:**
- ✅ JWT is stateless (verify signature, extract claims)
- ✅ API keys are stored hashed (never stored in plaintext)
- ✅ Refresh tokens are long-lived (7-30 days), access tokens are short (15 min)
- ✅ OIDC discovery endpoint for IdP configuration

**Status in Repo:**
- ⏳ **Not yet implemented**
- ✅ RFC-0001 mentions OIDC but no code

**DoD (Definition of Done):**
- [ ] OIDC provider configured (Auth0, Okta, or local mock for dev)
- [ ] Web UI login redirects to IdP and handles callback
- [ ] JWT middleware in control-plane validates tokens
- [ ] API key endpoints (create/revoke/rotate)
- [ ] Test: Can log in, get JWT, call protected endpoint

---

### Task 3: Authorization - Minimal RBAC with Governance Roles

**Scope:**
- Define roles and permissions
- Enforce permissions server-side on all endpoints
- Role-based access control (not attribute-based for MVP)

**Roles (Suggested):**

| Role | Capabilities | Notes |
|------|--------------|-------|
| **WorkspaceAdmin** | Create/edit policies, manage users, view all runs | Full workspace control |
| **Operator** | Create/publish workflows, trigger runs, view logs | Day-to-day operations |
| **Approver** | Approve/reject pending steps, view audit logs | HITL decision maker |
| **Auditor** | Read-only access to all logs, runs, policies | Compliance officer (no writes) |
| **IntegrationAdmin** | Install connectors, manage BYO keys, config settings | Integration specialist |

**Permission Enforcement:**
- Server-side checks on every endpoint (not client-side)
- Fail-closed: If permission not found, deny by default
- Audit log every authorization decision

**Example Flows:**
- WorkspaceAdmin creates new policy → Check permission: "policy:create" → Allow
- Auditor tries to delete run → Check permission: "run:delete" → Deny (Auditor is read-only)
- Operator triggers workflow → Check permission: "run:create" + workflow accessible → Allow

**Status in Repo:**
- ⏳ **Not yet implemented**
- ✅ Role table exists in schema.sql (referenced but not fully defined)

**DoD (Definition of Done):**
- [ ] roles table populated with 5 suggested roles
- [ ] permissions table defines granular actions (policy:create, run:delete, etc.)
- [ ] role_binding table maps user → role → workspace
- [ ] Middleware checks permission before handler executes
- [ ] Test: Auditor cannot delete, Operator can trigger runs

---

### Task 4: Region Pinning - US + EU from Day 1

**Scope:**
- Enforce data residency per tenant
- Block cross-region operations
- Support future expansion to other regions

**Requirements:**

1. **Region Field on Workspace**
   - Immutable after creation (or controlled migration with DBA approval)
   - Values: "us-east-1", "eu-west-1" (or "US", "EU" for simplicity)
   - Validates at creation time

2. **Data Residency Enforcement**
   - PostgreSQL: Region-specific database (could be same cluster with RLS row-level enforcement)
   - Redis: Separate region-specific instances
   - MinIO: Region-specific buckets or separate instances
   - Logs: Ship to region-specific logging system

3. **Cross-Region Blocking**
   - If workspace is in US, any non-US data access is blocked
   - Query middleware checks workspace region before execution
   - Explicit deny (not just "no access", but logged security event)

4. **Future Expansion**
   - Service discovery: Determine database/cache/storage endpoint from workspace region
   - Example: `control_plane_db_${region}.aic-sos.internal` (us_db, eu_db)
   - Configuration management for region-to-endpoint mappings

**Status in Repo:**
- ✅ Workspace schema has region field (immutable in MVP)
- ✅ RFC mentions region pinning strategy
- ⏳ **Missing:** Enforcement middleware, region routing logic

**DoD (Definition of Done):**
- [ ] Workspace region field is required + immutable
- [ ] Query middleware validates principal workspace region == query region
- [ ] Test: EU workspace cannot query US data
- [ ] Config file maps region → database endpoint (for scaling)
- [ ] Cross-region attempts are logged as security events

---

### Task 5: Tenant Data Mode - Metadata-Only Default

**Scope:**
- Privacy by default: Store only metadata, not content
- Per-tenant opt-in for full content persistence
- Clear definition of "metadata" vs "content"

**Metadata vs Content (for ITSM context):**

| Data Type | Metadata | Content |
|-----------|----------|---------|
| **Tickets** | ID, number, status, severity, assigned_to, timestamp | Full ticket description, history, attachments |
| **Chat** | message_id, sender, timestamp, token_count | Actual transcript text |
| **Evidence** | evidence_id, type, hash, url, created_at | Full evidence bundle content |
| **Decisions** | decision_id, risk_tier, action_taken, timestamp | Justification text, reasoning |

**Design:**
- `workspace_config.data_persistence_mode` = "metadata_only" (default) or "full"
- Execution plane checks flag before storing
- Metadata always stored, content conditionally stored
- Even with full mode, sensitive data (credentials, keys) never stored

**Use Cases:**
- **EU Privacy-First Org:** metadata_only mode, zero content persistence
- **US-Based Large Org:** full mode, store everything for audit/investigation
- **Hybrid:** Different data modes per workspace within same tenant

**Status in Repo:**
- ⏳ **Not yet implemented**
- ✅ Mentioned in PHASE-1 requirements
- ⏳ **Missing:** Flag in workspace_config, pipeline checks

**DoD (Definition of Done):**
- [ ] workspace_config table has data_persistence_mode field
- [ ] Default is "metadata_only"
- [ ] Tenant can toggle mode (with audit log)
- [ ] Execution plane respects flag (unit test)
- [ ] Evidence generation redacts content if metadata_only

---

### Task 6: BYO Provider Keys (OpenAI + Azure OpenAI + Anthropic)

**Scope:**
- Customers bring their own LLM API keys
- Store encrypted at rest (KMS or similar)
- Validate keys on entry
- Support key rotation without downtime

**Requirements:**

1. **Key Storage**
   - Never store in plaintext
   - KMS envelope encryption or AWS Secrets Manager equivalent
   - Fields: key_type (openai/azure/anthropic), encrypted_value, created_at, last_rotated_at

2. **Key Validation**
   - On entry: Non-destructive test call (e.g., count tokens, get model list)
   - Rate limited: Max 3 validation calls per minute
   - Non-fatal: Validation failure logs warning but doesn't block storage (user can diagnose)

3. **Key Rotation**
   - New key becomes active immediately
   - Old key kept for 24-48 hours (in-flight requests can complete)
   - Background job: After TTL, delete old key
   - No downtime, no service interruption

4. **Multi-Provider Support**
   - OpenAI: API key format validation
   - Azure OpenAI: API key + endpoint URL
   - Anthropic: API key format validation
   - Future: Google PaLM, Cohere, etc.

**Status in Repo:**
- ✅ Schema has `provider_keys` table (partial)
- ⏳ **Missing:** Encryption implementation, validation logic

**DoD (Definition of Done):**
- [ ] provider_keys table with encryption_key_id, encrypted_value
- [ ] KMS or vault integration (decrypt on use only)
- [ ] Validation endpoint (POST /validate-key, returns success/error)
- [ ] Key rotation workflow (new key without delete)
- [ ] Test: Store key → Validate → Rotate → Old key works briefly, new key active

---

### Task 7: Public API Surface (Control Plane)

**Scope:**
- Minimal REST endpoints for bootstrap + CRUD
- OpenAPI schema updated
- Generated stubs compile

**Endpoints (Minimal):**

**Tenancy:**
- `POST /api/tenants` — Create tenant (admin only)
- `GET /api/tenants/{tenant_id}` — Get tenant details
- `POST /api/workspaces` — Create workspace (admin)
- `GET /api/workspaces/{workspace_id}` — Get workspace

**Workflows:**
- `POST /api/workflows` — Create workflow
- `PUT /api/workflows/{workflow_id}` — Update (creates new version, old immutable)
- `GET /api/workflows/{workspace_id}` — List workspace workflows
- `POST /api/workflows/{workflow_id}/publish` — Publish version

**Connectors:**
- `POST /api/connectors/install` — Install connector in workspace
- `PUT /api/connectors/{connector_id}/credentials` — Update BYO keys

**Runs:**
- `GET /api/runs` — List runs (filtered by workspace)
- `GET /api/runs/{run_id}` — Get run detail

**Health:**
- `GET /health` — Service health (readiness)
- `GET /readiness` — K8s readiness probe

**Metrics:**
- `GET /metrics` — Prometheus metrics (optional for MVP)

**Status in Repo:**
- ✅ OpenAPI schema skeleton exists
- ✅ Generated stubs for some endpoints
- ⏳ **Missing:** Implementation of handlers, database queries

**DoD (Definition of Done):**
- [ ] OpenAPI schema updated for all 13+ endpoints
- [ ] Generated server stubs compile
- [ ] Web UI can call endpoints (end-to-end)
- [ ] All endpoints validate tenant/workspace context
- [ ] Test: Create tenant → workspace → workflow → publish → list

---

## Implementation Order (Recommended)

Based on dependencies, suggest this sequence:

1. **Database Migrations** (Task 1)
   - Blocks all other tasks
   - Start here

2. **Identity: OIDC + JWT Middleware** (Task 2)
   - Needed for auth on all endpoints
   - Implement early for testing other tasks

3. **Authorization: RBAC** (Task 3)
   - Depends on: Identity (principal_id in context)
   - Middleware wraps endpoints

4. **Region Pinning** (Task 4)
   - Depends on: Database (workspace.region field)
   - Implement in query middleware alongside auth

5. **Tenant Data Mode** (Task 5)
   - Depends on: Database (workspace_config field)
   - Can be stubbed early, implementation in execution-plane later

6. **BYO Provider Keys** (Task 6)
   - Depends on: Database, KMS setup
   - Implement key management endpoints

7. **Public API Surface** (Task 7)
   - Depends on: All of above
   - Final integration, wires up all tasks

---

## Technical Stack for Implementation

**Language:** Go (control-plane service)  
**Database:** PostgreSQL 16 (already in docker-compose)  
**Auth:** OIDC + JWT + Auth0/Okta (or mock for dev)  
**Encryption:** AWS KMS or Go crypto package  
**HTTP Framework:** Go stdlib `net/http` or Gin  
**Logging:** Structured JSON logs (zap or logrus)  
**Testing:** Go testing package + httptest  

---

## Known Unknowns & Decisions Needed

### 1. Row-Level Security (RLS) vs App Logic?

**Option A: PostgreSQL RLS**
- Pro: Database enforces isolation (defense in depth)
- Con: Complex, requires Postgres expertise, harder to debug
- Typical: Enterprise systems use RLS

**Option B: App-Level Scoping**
- Pro: Easier to understand/test, explicit in Go code
- Con: Single bug breaks isolation for all tenants, must be careful

**Recommendation:** Start with **Option B (app-level)** for MVP speed. Add RLS in PHASE-2 for production hardening.

### 2. Data Persistence: Single DB vs Region-Specific Databases?

**Option A: Single Postgres + RLS**
- Pro: Simpler operations, easier migration
- Con: US/EU data physically collocated (compliance issue)

**Option B: Separate Postgres Instances**
- Pro: True data residency (EU data in EU)
- Con: Operational complexity, cross-tenant queries harder

**Recommendation:** Start with **Option A (single DB, RLS)** for MVP. Plan Option B for PHASE-2+ based on compliance requirements.

### 3. OIDC Provider?

**Options:**
- Auth0 (easiest, managed)
- Okta (enterprise, expensive)
- Azure AD (if customer already has)
- Mock OIDC server (for dev/testing)

**Recommendation:** Use **mock OIDC for dev**, support Auth0 for testing. Customers will bring their own IdP.

### 4. Encryption at Rest?

**Options:**
- AWS KMS (if on AWS)
- Go crypto (local key, less secure but simpler)
- HashiCorp Vault (enterprise, overkill for MVP)

**Recommendation:** **Go crypto package + local keyfile for MVP**. Upgrade to KMS/Vault in PHASE-2.

---

## Exit Gate Checklist

**The team has succeeded when:**

- [ ] Create tenant (name, region) via API
- [ ] Create workspace (tenant_id, name, region) via API
- [ ] Log in via OIDC (IdP redirects to login, returns JWT)
- [ ] Store BYO OpenAI key (encrypted, validated)
- [ ] Create workflow (YAML definition)
- [ ] Publish workflow version (immutable)
- [ ] List published workflows via API (filtered by workspace)
- [ ] Verify isolation: User from Workspace B cannot see Workspace A workflows
- [ ] Verify region pinning: US workspace cannot access EU data (blocked)
- [ ] Web UI displays tenant, workspace, logged-in user

**Success:** All above work, PHASE-1 Exit Gate passes → Ready for PHASE-2 (Execution Plane)

---

## Effort Estimate

| Task | Estimated Hours | Dependencies |
|------|-----------------|--------------|
| 1. Data Model + Migrations | 4-6 | None |
| 2. OIDC + JWT | 6-8 | Task 1 |
| 3. RBAC | 4-5 | Task 2 |
| 4. Region Pinning | 3-4 | Task 1, 2 |
| 5. Data Mode | 2-3 | Task 1 |
| 6. BYO Keys | 4-6 | Task 1, KMS setup |
| 7. API Surface | 4-5 | Task 2, 3, 6 |
| **Total** | **27-37 hours** | 3-5 calendar days (1-2 engineers) |

---

## Next Action

**Task:** Implement Milestone 1 P0 tasks in order (DB → Auth → RBAC → API)

**When Ready:** Move to TODO item 4 "Start Milestone 1 - Control Plane P0s"

---

**Reviewed by:** GitHub Copilot  
**Date:** December 19, 2024  
**Status:** ✅ Ready to proceed with implementation
