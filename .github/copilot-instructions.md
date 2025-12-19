# AI Coding Agent Instructions for Governed AI Delivery Factory

**Updated:** 2025-12-18  
**Project:** AI Workflow Governance Platform (MVP: ITSM Triage)

---

## 1. Architecture Overview

This is a **multi-tenant SaaS platform** for governed AI workflow automation. The MVP focuses on **ITSM ticket triage** (ServiceNow incident → summarize/classify/route → HITL approval → write back).

### Core Principle: Deny-by-Default, Evidence-First
- **All external tool actions** (reads/writes) go through a **Policy Enforcement Point (PEP)** before execution.
- **No cross-tenant access**; isolation via tenant_id + workspace_id + RLS.
- **Evidence bundle** (audit logs, decision traces, redacted transcripts) is **mandatory** for every run.
- **Fail-closed policy:** if policy evaluation unavailable or stale, deny the action.

### Four Major Services
1. **Control Plane** (Go) — tenancy, workflows (YAML), policy bundles, approvals, metering, audit
2. **Execution Plane** (Rust core + Go) — Run/Step state machine, LLM adapter, policy PEP, evidence emitters
3. **Connector Gateway** (Rust/Go) — final PEP for outbound calls; schema validation, idempotency, normalized error taxonomy
4. **Agent** (Rust, optional) — outbound-only connectivity for private/restricted networks

See `docs/RFC-0001-architecture.md` (§2–3) and `service-boundaries.md` for detailed service ownership.

---

## 2. Deployment Model & Data Locality

- **Cell-based multi-tenant SaaS:** each region (US, EU) runs independent cells (Kubernetes or ECS).
- **Regional pinning:** workspaces are pinned to a region; no cross-region data replication by default.
- **Docker Compose for local dev:** `docker compose up -d` starts Postgres, Redis, MinIO (stub S3).
- **Infrastructure-as-Code:** `iac/terraform/modules/cell/` + region examples (us, eu).

**Tenant isolation enforced at:**
- Database RLS (Row-Level Security) per tenant_id
- Workspace region constraint (workspace.region = "us-east-1" or "eu-west-1")
- Service authentication (mTLS for agent; API keys scoped to tenant/workspace)

---

## 3. Key Technical Patterns

### 3.1 Workflow Definition (YAML, Canonical, Pinned)
- **Format:** YAML, stored as text in `workflow_versions.definition_yaml`
- **Pinning:** every version has a `definition_digest` (sha256 of canonicalized YAML) for traceability
- **Model pinning:** per workflow version (no silent model drift); `model_pin` stores `{"provider": "openai", "model": "gpt-4", ...}`
- **No arbitrary code:** only predefined tools, templating, and JSON schema validation
- **Builder:** hybrid UI + code (form helpers, generators, templates)

### 3.2 Policy-as-Code (OPA/Rego)
- **Source:** `contracts/policy/policy.rego`
- **Distribution:** signed bundles with TTL (5–15 min refresh)
- **Decisions:** `ALLOW | DENY | REQUIRE_HITL | REQUIRE_STEP_UP | THROTTLE | ROUTE`
- **Evaluation inputs:** actor, scope, action (tool_action_id, risk_labels), governance (risk_tier, approval_artifact_present), operational (within_write_caps)
- **Fail-closed:** any tool action (read or write) fails if PDP unavailable or bundle stale beyond TTL

**Example patterns** (see policy.rego):
- Reads allowed only if explicitly allowlisted
- Reversible writes (assignment, labels, notes) require approval artifact + within write caps
- High-risk tier or scope changes require step-up (e.g., supervisor approval)

### 3.3 ToolActions & Connector Gateway
- **ToolAction** = smallest externally effectful unit (e.g., `servicenow.update_incident_reversible`)
- **Validation:** JSON schema at connector gateway (no invalid payloads reach external APIs)
- **Idempotency key:** required for all writes; canonical form: `tenant_id + workspace_id + connector_instance_id + tool_action_id + target_resource_id + upstream_event_id + action_hash`
  - **Example:** `12345678-1234-5678-1234-567812345678:prod:sn-instance-1:servicenow.add_work_note:INC0123456:webhook-sn-20251218-001:abcd1234`
  - **Regenerate internally:** don't trust upstream-provided keys; use hash(canonical_tuple) to ensure stability
  - **Use case:** on timeout/network error, same idempotency key + retry = safe (Connector Gateway dedupes via Redis cache or DB lookup)
- **Error taxonomy:** normalized categories (`POLICY_DENIED`, `AUTH_ERROR`, `RATE_LIMITED`, `UPSTREAM_5XX`, `TIMEOUT`, `CONFLICT`, `NOT_FOUND`, etc.) for consistent retry/DLQ decisions
- **Retries:** bounded exponential backoff + jitter (e.g., 1s, 2s, 4s, 8s, 16s max); exhausted → DLQ with manual replay UI
- **DLQ semantics:** failed action logs to `tool_calls` table with `status='dlq'`; ops can inspect + manually trigger `/v1/tool_calls/{id}/replay` to re-execute

### 3.4 Runtime State Machine (Queue-Driven, At-Least-Once)
- **Run:** instance of workflow_version executing against a trigger (e.g., ServiceNow webhook)
  - `trigger_type` (e.g., "servicenow_webhook"), `trigger_ref` (used for dedup on replay)
  - `status`: queued → running → completed/failed/paused_approval
- **Step:** atomic unit (tool call, transform, LLM call); identified by stable `step_id` from YAML
  - `lease_owner` + `lease_expires_at` (worker grabs step with time-bound lease; expired → re-queue)
  - `idempotency_key` (required for all ToolAction steps)
  - `status`: queued → running → completed/failed/requires_approval
- **Approval:** created when policy requires HITL; blocks step execution
  - `tier` (low/med/high) + optional `two_person` gate (policy flag)
  - `status`: requested → approved/rejected/expired/canceled
  - **Slack integration:** approval_id + tenant_id + workspace_id bound to Slack message (no PII in message)
- **Action Receipt:** every external tool call logs `request_metadata` (what was attempted) + `response_metadata` (what happened) + `is_reversible` + `reverse_instruction`
- **Sequence (ServiceNow triage example):**
  1. Webhook → create Run (status=queued)
  2. Worker claims Step 1 (fetch incident) with lease
  3. Execute tool, emit ToolCall record (completed)
  4. Step 2 (LLM summarize) → policy allows (ALLOW)
  5. Step 3 (proposed assignment) → policy says REQUIRE_HITL, create Approval
  6. Wait for approver (Slack interaction)
  7. On approval: Step 4 (write assignment + note) → policy allows (approval_artifact_present=true)
  8. Execute tool, emit Evidence bundle + metering event
  9. Run completes, emit AuditLogEvent (with hash-chain link to previous)

See `runtime/state-machine.md` for full state diagram and semantics.

### 3.5 Audit & Evidence
- **AuditLogEvent:** append-only, hash-chained per tenant/workspace (integrity chain, not blockchain)
  - Schema: `{ audit_log_event_id, tenant_id, workspace_id, actor, action_type, resource_type, resource_id, decision, previous_hash, created_at, ...}`
  - `previous_hash` = sha256(json(previous event)) ensures tampering is detected
  - Examples: "workflow_deployed", "policy_bundle_updated", "approval_granted", "tool_call_executed", "run_completed"
- **Evidence bundle:** includes run metadata, actor, policy decision, tool-call transcript (redacted), idempotency keys, cost summary
  - **Exported as:** JSON (queryable) or PDF (human-readable); stored in S3 or long-term archive
  - **Retention:** 14–30 days operational; years for audit artifacts (configurable per workspace)
  - **Redaction rules:** mask LLM responses (first 50 chars only), omit API keys, hide PII in ServiceNow incident details
- **Traceability:** every action traces back:
  - upstream event (webhook ID, trigger timestamp)
  - approval artifact (approver, decision time, via Slack or UI)
  - cost (cost per tool call + total run cost)
  - policy decision path (which rules matched ALLOW vs. DENY)
- **Cross-service evidence flow:**
  1. Execution Plane executes tool → emits DecisionRecord (policy input/output) + ToolCall transcript
  2. Connector Gateway confirms write → emits ActionReceipt (idempotency key, response status)
  3. Execution Plane aggregates → emits AuditLogEvent (with previous_hash link)
  4. Indexer (async) builds evidence bundle + computes cost-per-ticket

---

## 4. Developer Workflows

### 4.1 Build (Local)
```bash
docker compose up -d      # Start Postgres, Redis, MinIO
make build                # Build all services
  # → cd services/control-plane && go build ./...
  # → cd services/connector-gateway && go build ./...
  # → cd services/execution-plane && cargo build
  # → cd services/agent && cargo build
```

### 4.2 Service Dependencies
- **Control Plane** → Postgres (tenancy, workflows, policies), Redis (session cache)
  - **Exposes:** workflow CRUD, policy bundle publish, approval records, metering aggregates, audit query APIs
  - **Calls:** Execution Plane (trigger run), Connector Gateway (simulator sandbox)
- **Execution Plane** → Postgres (Run/Step state, audit logs), SQS-like queue (Redis or AWS SQS), Connector Gateway PEP
  - **Receives:** run creation (HTTP or async queue)
  - **Executes:** step logic (fetch context, call LLM, validate decision)
  - **Calls:** Connector Gateway (via PEP stub; gateway validates + executes)
  - **Emits:** DecisionRecord (policy trace), ToolCall (transcript), AuditLogEvent (hash-chained)
- **Connector Gateway** → Postgres (connector instance config, cached rate limits), external APIs (ServiceNow, Slack, GitHub)
  - **Receives:** ToolAction requests (from Execution Plane)
  - **Validates:** JSON schema + idempotency key + policy decision
  - **Executes:** external call with retries/backoff
  - **Emits:** ActionReceipt (success/failure + response), redacted transcript
  - **Dedupes:** on idempotency key (Redis cache or DB query), returns cached response if repeat attempt
- **Agent** (optional) → mTLS to platform (tenant/workspace cert), local connector calls
  - **Receives:** tasks from Execution Plane (HTTP poll or WebSocket)
  - **Executes:** connector calls locally (if agent-configured)
  - **Telemetry:** store-and-forward (batch up events, send on next heartbeat)
- **Indexer** (async) → Postgres (audit logs), S3 (evidence bundles)
  - **Async job:** processes completed runs, builds evidence bundles, computes cost-per-ticket, publishes to S3

**Cross-service call example (ServiceNow write):**
```
Execution Plane
  → calls: POST /connector-gateway/v1/execute_tool
       { tool_action_id: "servicenow.add_work_note",
         idempotency_key: "12345:prod:sn1:...",
         connector_instance_id: "...",
         input: { incident_id: "INC123", note: "..." } }
  
Connector Gateway
  → validates: schema OK, policy OK (approval_artifact_present=true), idempotency key new
  → executes: POST https://company.service-now.com/api/now/table/incident/INC123/..
  → on success: emit ActionReceipt { status: "success", response: {...}, is_reversible: true, reverse_instruction: {...} }
  
Execution Plane
  → aggregate: emit AuditLogEvent { action_type: "tool_call_executed", tool_action_id: "...", previous_hash: "..." }
  
Indexer
  → reads AuditLogEvent, ToolCall, ActionReceipt
  → builds evidence bundle (JSON + redacted transcript)
  → stores in S3 + Postgres evidence_artifacts table
```

### 4.3 Testing & Validation
- **Policy simulation API:** `POST /v1/policy/simulate` — dry-run policy decisions without executing
- **Unit tests:** per service; Rust services use `cargo test`, Go services use `go test`
- **Contract tests:** JSON Schemas in `contracts/events/`, `contracts/openapi/` validate payloads
- **Local integration:** docker-compose + make targets (TBD: full test suite)

### 4.4 Deployment (Terraform)
- **Module:** `iac/terraform/modules/cell/` provisions a single region
- **Examples:** `iac/terraform/examples/us/`, `iac/terraform/examples/eu/`
- **Outputs:** ECS/Fargate services, RDS Postgres (RLS enabled), SQS queues, KMS keys, CloudWatch

---

## 5. Critical Files & Conventions

### Architecture & Decisions
- `docs/RFC-0001-architecture.md` — **START HERE** for design, scope, NFRs, data flows
- `docs/RFC-0002-execution-plan.md` — phased rollout (phases 0–9)
- `service-boundaries.md` — service ownership, API scope

### Data & Contracts
- `data/db-schema.md` — Postgres schema, RLS, multi-tenancy, audit chain
- `contracts/openapi/openapi.yaml` — REST API surface (v1 endpoints)
- `contracts/events/*.schema.json` — event schemas (approval.required, incident.created, etc.)
- `contracts/policy/policy.rego` — deny-by-default policy rules
- `contracts/connectors/README.md` — ToolAction definitions, idempotency, error taxonomy

### Runtime & Operations
- `runtime/state-machine.md` — Run/Step/Approval state machine and transitions
- `diagrams/sequences/01-intake.mmd` to `05-runtime-itsm.mmd` — flow diagrams (Mermaid)
- `nfr/` — SLOs, reliability, security model, privacy compliance

### Code Layout
```
services/
  control-plane/      (Go: tenancy, workflows, policies, approvals)
  execution-plane/    (Rust + Go: state machine, LLM adapter, PEP)
  connector-gateway/  (Rust/Go: outbound PEP, idempotency, retries)
  agent/              (Rust: outbound-only agent for private networks)
apps/
  web/                (TS/React: admin, builder, operator UIs)
iac/terraform/        (AWS cell provisioning)
contracts/            (OpenAPI, event schemas, policy, connector manifests)
```

---

## 6. Critical Code Paths & Implementation Patterns

### 6.1 ServiceNow Webhook Intake → Evidence Bundle (MVP Flagship)
**Files to reference:** `docs/diagrams/sequences/01-intake.mmd` + `03-eval.mmd`

**Flow with code touchpoints:**
1. **Webhook ingestion** (Control Plane HTTP handler)
   - Verify HMAC signature (ServiceNow signing key in Postgres)
   - Extract `incident_id`, `number`, `created` from payload
   - Create Run: `INSERT INTO runs (run_id, tenant_id, workspace_id, workflow_version_id, trigger_type, trigger_ref, status) VALUES (..., 'servicenow_webhook', incident_id, 'queued')`
   - Enqueue Step 1: `INSERT INTO steps (step_id, run_id, step_index, tool_name, idempotency_key, status) VALUES ('fetch_incident', ..., 'GET', 'queued')`

2. **Step execution** (Execution Plane worker, leased)
   - Claim step with lease: `UPDATE steps SET lease_owner=$1, lease_expires_at=now()+30s WHERE step_id=$2 AND status='queued'`
   - Execute: call Connector Gateway PEP → `/connector-gateway/v1/execute_tool`
     - Input: `{ tool_action_id: "servicenow.get_incident", connector_instance_id: "...", input: { incident_id: "INC123" } }`
     - No idempotency key (read-only)
   - Emit ToolCall record: `INSERT INTO tool_calls (tool_call_id, step_id, tool_action_id, status, response_code, transcript_redacted) VALUES (...)`
   - Enqueue Step 2: LLM summarization

3. **Policy evaluation & HITL** (Execution Plane + Control Plane)
   - Step 3 (proposed write): call `/v1/policy/simulate` with:
     ```json
     {
       "actor": { "principal_id": "workflow:...", "authenticated": true },
       "scope": "servicenow.update_incident_reversible",
       "action": { "tool_action_id": "servicenow.add_work_note", "risk_labels": ["write", "reversible"] },
       "governance": { "risk_tier": "low", "approval_artifact_present": false },
       "operational": { "within_write_caps": true }
     }
     ```
   - Policy returns: `{ "decision": "REQUIRE_HITL", "reason": "reversible_write_requires_approval" }`
   - Create Approval: `INSERT INTO approvals (approval_id, run_id, step_id, tier, status) VALUES (..., 'low', 'requested')`
   - Emit Slack message with approval link + incident summary

4. **Approval & write-back** (Control Plane + Execution Plane)
   - Approver clicks Slack button → `/v1/approvals/{approval_id}/decide { decision: 'approve' }`
   - Update Approval: `UPDATE approvals SET status='approved', approved_at=now(), approved_by=$1 WHERE approval_id=$2`
   - Emit AuditLogEvent: `{ action_type: 'approval_granted', previous_hash: <hash of previous event> }`
   - Resume Run → enqueue Step 4 (write)
   - Step 4 executes: call Connector Gateway → `/connector-gateway/v1/execute_tool`
     - Input: `{ tool_action_id: "servicenow.add_work_note", idempotency_key: "tenant:prod:sn1:...", connector_instance_id: "...", input: { incident_id: "INC123", note: "..." } }`
     - Connector Gateway validates, dedupes (idempotency key check), executes, emits ActionReceipt
   - Emit ToolCall: `{ status: 'success', response_code: 201 }`
   - Emit AuditLogEvent: `{ action_type: 'tool_call_executed', previous_hash: <...> }`

5. **Evidence bundle** (Indexer async job)
   - Query Postgres: reads Run + Steps + ToolCalls + Approvals + AuditLogEvents for run_id
   - Build evidence JSON:
     ```json
     {
       "run_id": "...",
       "incident_id": "INC123",
       "workflow_version": "1.0.0",
       "trigger": { "type": "servicenow_webhook", "timestamp": "..." },
       "steps": [
         { "step_id": "fetch_incident", "status": "completed", "duration_ms": 234 },
         { "step_id": "summarize_llm", "status": "completed", "duration_ms": 2341, "cost_usd": 0.002 },
         { "step_id": "approve_write", "status": "completed", "approval": { "decision": "approve", "actor": "user@company.com" } },
         { "step_id": "write_incident", "status": "completed", "tool_call": { "response_code": 201 } }
       ],
       "total_cost_usd": 0.005,
       "audit_chain_valid": true
     }
     ```
   - Store in S3 + Postgres: `INSERT INTO evidence_artifacts (artifact_id, run_id, tenant_id, content_s3_key, content_hash) VALUES (...)`

### 6.2 Connector Instance Registration & Credential Management
**No credentials in DB; only CredentialRef pointers to KMS/vault**

**Flow:**
1. Tenant calls: `POST /v1/connectors/instances`
   ```json
   {
     "connector_type": "servicenow",
     "instance_name": "prod",
     "auth_type": "oauth",
     "credential_ref": "arn:aws:kms:us-east-1:111:key/abc123",
     "scopes": ["incident:read", "incident:write:reversible"],
     "metadata": { "instance_url": "https://company.service-now.com" }
   }
   ```
2. Control Plane validates credential_ref (KMS key exists, tenant owns it)
3. Store: `INSERT INTO connector_instances (connector_instance_id, tenant_id, connector_type, credential_ref, scopes) VALUES (...)`
4. On tool call (Connector Gateway):
   - Lookup: `SELECT credential_ref FROM connector_instances WHERE connector_instance_id=$1`
   - Fetch secret: call KMS decrypt(credential_ref) → gets OAuth token or API key
   - Use token in outbound call
   - Never log the token (redact before ToolCall record)

### 6.3 Policy Bundle Refresh & TTL Enforcement
**Policy is versioned, signed, cache-aware; default TTL 5–15 min**

**Flow:**
1. Tenant publishes policy: `POST /v1/policies/publish`
   ```json
   {
     "name": "governance",
     "version": "1.0.0",
     "rego_source": "package policy\n...",
     "ttl_seconds": 300
   }
   ```
2. Control Plane:
   - Validate Rego syntax (compile check)
   - Compute digest: `sha256(rego_source)`
   - Sign: `sign(digest, tenant_signing_key)` → signature
   - Store: `INSERT INTO policies (policy_id, tenant_id, name, version, policy_digest, signature, ttl_seconds) VALUES (...)`

3. Execution Plane caches policy:
   - On startup or TTL expiry, fetch: `GET /v1/policies/active?workspace_id=...`
   - Verify signature: `verify(digest, signature, tenant_key)`
   - Cache in Redis with TTL
   - Track `policy_bundle_fetched_at`

4. At policy evaluation time:
   - If cached policy NOT stale: use it
   - If stale: fail-closed (deny) + async refresh in background
   - On next request: use fresh policy if available

### 6.4 Idempotency Key Generation (Execution Plane → Connector Gateway)
**Example implementation pattern:**

```python
def generate_idempotency_key(tenant_id, workspace_id, connector_instance_id, 
                            tool_action_id, resource_id, upstream_event_id, action_hash):
    """
    Canonical tuple for stable idempotency key.
    action_hash = sha256(json(sorted(action_input)))
    """
    canonical = f"{tenant_id}:{workspace_id}:{connector_instance_id}:{tool_action_id}:{resource_id}:{upstream_event_id}:{action_hash}"
    return canonical  # Or base64(sha256(canonical)) for brevity if needed in headers

# Usage:
idempotency_key = generate_idempotency_key(
    tenant_id="12345678-...",
    workspace_id="prod-ws-...",
    connector_instance_id="sn-prod-1",
    tool_action_id="servicenow.add_work_note",
    resource_id="INC0123456",
    upstream_event_id="webhook-sn-20251218-001",
    action_hash=sha256(json({"note": "Routed to backend team"}))
)
```

---

## 6. Project-Specific Conventions

### 7.1 Multi-Tenant Isolation Enforcement
**Three-layer defense (belt + suspenders):**

1. **API Authentication & Authorization**
   - Extract tenant_id from JWT/API key: `auth_header → parse(jwt) → tenant_id`
   - Store in request context: `request.context.tenant_id = "..."`
   - All SQL queries must include tenant_id filter (even with RLS enabled)

2. **Row-Level Security (RLS) at database**
   - Enable RLS on all tenant-scoped tables:
     ```sql
     ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;
     CREATE POLICY tenant_isolation ON workflows
       USING (tenant_id = current_setting('app.tenant_id')::uuid);
     ```
   - Set tenant context per transaction: `SET app.tenant_id = $1`
   - RLS denies reads/writes if tenant_id mismatch

3. **App-layer validation**
   - Every query filters: `WHERE tenant_id = $1 AND ...`
   - Example (wrong): `SELECT * FROM workflows WHERE workflow_id = $1`
   - Correct: `SELECT * FROM workflows WHERE tenant_id = $1 AND workflow_id = $2`
   - Queries to audit log, evidence, approvals: all scoped by tenant_id

**Test pattern (verify isolation):**
```go
// Given: two tenants T1, T2
// When: T1 user requests workflow of T2
// Then: 404 Not Found (or 403 Forbidden) + audit log

func TestTenantIsolation(t *testing.T) {
  t.Run("tenant_cannot_access_other_tenant_workflow", func(t *testing.T) {
    workflow := createWorkflow(tenantT2)
    
    req := httptest.NewRequest("GET", "/v1/workflows/"+workflow.ID, nil)
    req.Header.Set("Authorization", "Bearer "+tokenT1)
    
    res := handler(req)
    assert.Equal(t, 404, res.StatusCode)
  })
}
```

### 7.2 Request Context Pattern
**Recommended: use context.Context throughout call chain**

```go
// In middleware:
ctx := r.Context()
claims := parseJWT(r.Header.Get("Authorization"))
ctx = context.WithValue(ctx, "tenant_id", claims.TenantID)
ctx = context.WithValue(ctx, "workspace_id", claims.WorkspaceID)
ctx = context.WithValue(ctx, "actor_id", claims.Subject)

// In handler:
func handleCreateWorkflow(w http.ResponseWriter, r *http.Request) {
  ctx := r.Context()
  tenantID := ctx.Value("tenant_id").(string)
  
  // All queries include tenantID
  workflow := db.CreateWorkflow(ctx, tenantID, req.Name)
}
```

### 7.3 Audit Logging Requirements
**Every action must emit AuditLogEvent:**

```sql
INSERT INTO audit_log_events (
  audit_log_event_id,
  tenant_id,
  workspace_id,
  actor,
  action_type,                    -- 'workflow_created', 'approval_granted', 'tool_call_executed'
  resource_type,                  -- 'workflow', 'run', 'approval', 'policy_bundle'
  resource_id,
  decision,                        -- 'ALLOW', 'DENY', 'REQUIRE_HITL' (for policy actions)
  details_json,                   -- free-form metadata (redacted)
  previous_hash,                  -- sha256(previous event); null if first
  created_at
) VALUES (
  gen_random_uuid(),
  tenant_id,
  workspace_id,
  actor,
  'approval_granted',
  'approval',
  approval_id,
  'APPROVE',
  jsonb_build_object('approver', approver_id, 'timestamp', now()),
  (SELECT event_hash FROM audit_log_events WHERE tenant_id=$1 AND workspace_id=$2 ORDER BY created_at DESC LIMIT 1),
  now()
);
```

**Hash chain validation (periodic integrity check):**
```python
def validate_audit_chain(tenant_id, workspace_id):
    """Verify no events tampered with (hash links are correct)"""
    events = db.query(
        "SELECT audit_log_event_id, previous_hash FROM audit_log_events "
        "WHERE tenant_id=$1 AND workspace_id=$2 ORDER BY created_at",
        tenant_id, workspace_id
    )
    
    prev_hash = None
    for event in events:
        if event.previous_hash != prev_hash:
            raise TamperDetectedError(f"Event {event.id} hash chain broken")
        # Recompute hash to ensure not modified
        computed = sha256(json(event))
        if computed != event.event_hash:
            raise TamperDetectedError(f"Event {event.id} content modified")
        prev_hash = event.event_hash
    
    return True
```

### 6.1 IDs & Identifiers
- **All IDs are UUIDs** (not auto-increment integers); ensures global uniqueness and safe multi-region merging
- **step_id:** stable string from YAML (e.g., "fetch_incident", "approve_routing", "write_assignment")
- **idempotency_key:** required for all external writes; stable across retries (include tenant_id, upstream_event_id, action_hash)

### 6.2 YAML for Workflow Definitions
- **Canonical format:** workflows stored as YAML text (not JSON) for diffability and pinning
- **Model pinning:** declared in `model_pin` field (separate from workflow logic)
- **No code execution:** steps reference predefined tool names and simple transforms (templating, validation)
- **Versioning:** SemVer per workflow; version + digest together ensure exact reproducibility

### 6.3 Tenant Isolation (Strict)
- **Every query:** must include tenant_id filter or RLS will deny
- **Workspaces:** subdivide tenant (optional in MVP); pinned to region
- **Cross-tenant operations:** forbidden (no sharing, no delegation)
- **Credentials:** stored as CredentialRef (pointer) only; actual secrets in KMS/vault outside DB

### 6.4 Evidence & Auditability
- **Hash chain:** each AuditLogEvent includes hash of previous event (per tenant/workspace); tampering detected
- **Redaction:** tool call transcripts redact secrets/PII before logging
- **Idempotency keys:** logged alongside every external action for trace-back to upstream trigger
- **Cost tracking:** every tool call emits metering events (cost-per-action + aggregates)

### 6.5 Reversible vs. Irreversible Writes
- **Reversible:** assignment changes, labels, internal notes (allowed if policy permits + within caps)
- **Irreversible:** deletion, state transitions, schema changes (require escalation or explicit policy override)
- **Policy gates:** reversible writes allowed in low/medium risk tiers (after approval); irreversible always high-risk

### 6.6 Error Handling & Retries
- **Normalized taxonomy:** POLICY_DENIED, VALIDATION_ERROR, AUTH_ERROR, RATE_LIMITED, UPSTREAM_5XX, TIMEOUT, etc.
- **Retryable:** network errors, timeouts, rate limits (with backoff)
- **Non-retryable:** validation error, auth error, permission error, policy denial (log + DLQ)
- **DLQ:** failed actions after N retries land in dead-letter queue; ops can inspect and manually replay

---

## 7. Integration Points & External Dependencies

### 7.1 BYO LLM Models
- **Supported:** OpenAI, Azure OpenAI, Anthropic (MVP)
- **Pinning:** per workflow version (model + provider + config/temperature pinned)
- **Key injection:** secrets bound to tenant/workspace; no shared keys
- **Fallback:** policy-driven; allowed fallback providers configurable per workspace

### 7.2 External Systems (Connectors)
- **ServiceNow:** read incidents + reversible writes (category, priority, assignment, internal notes)
- **Slack:** HITL approval requests + notifications (no persistent state in Slack)
- **GitHub:** read PRs + comments (minimal MVP support; seed for phase 5)

### 7.3 Infrastructure
- **Postgres:** tenancy, workflows, policies, audit logs (RLS-enabled); schema in `db/schema.sql`
- **Redis:** session cache, rate limit counters, optional run state cache
- **S3/MinIO:** evidence bundles, policy bundle distribution, optional content storage
- **SQS:** run/step queue, retry queue, DLQ (or Redis queue for local dev)
- **CloudWatch/OTel:** observability; all services emit OTel traces

---

## 8. Common Pitfalls & Best Practices

### ✓ DO
- **Always include tenant_id in queries** (let RLS enforce, but also filter at app layer)
- **Create idempotency keys for external writes** (include upstream_event_id so retries are safe)
- **Regenerate idempotency keys internally** (hash canonical tuple: tenant + workspace + connector + tool + resource + upstream + action hash)
- **Emit AuditLogEvent with previous_hash** (chain integrity; tampering detection; required for audit)
- **Simulate policy before executing** (use `/v1/policy/simulate` for dry runs in tests)
- **Emit evidence and metering for every action** (required for audit and cost tracking)
- **Pin models/policies/workflows** (avoid silent drift; pin by digest or version)
- **Fail closed:** if policy unavailable or stale, deny the action (default decision is DENY)
- **Redact transcripts before logging** (omit API keys, LLM responses, PII in incident details)
- **Handle idempotency cache misses gracefully** (if DLQ replay hits missing cache entry, re-execute with same key)

### ✗ DON'T
- **Don't skip tenant isolation:** every table has tenant_id; RLS is second line of defense
- **Don't make writes without idempotency keys** (unsafe under retries; breaks audit chain)
- **Don't trust upstream-provided idempotency keys** (regenerate internally for external calls)
- **Don't hardcode model names** (use model_pin; allow dynamic fallback via policy)
- **Don't log secrets/PII:** redact tool call transcripts before emitting to audit store
- **Don't assume policy is always available:** implement fail-closed timeout + retry (policy bundle TTL)
- **Don't skip hash-chaining on AuditLogEvent** (required for integrity; tamper detection)
- **Don't leave failed actions in queue without DLQ** (log to DLQ + emit operational alert)
- **Don't assume Slack webhook payloads are idempotent** (Slack may retry; use idempotency key in approval ID)
- **Don't inline secrets in logs** (log redacted versions + full secret to secure vault only)

---

## 9. Key References

- **Start:** `docs/START-HERE.md` (3 commands + next vertical slice)
- **Architecture:** `docs/RFC-0001-architecture.md` (comprehensive; sections 2–4 for services + data flows)
- **Execution:** `runtime/state-machine.md` (Run/Step/Approval state machine)
- **Data model:** `data/db-schema.md` (Postgres schema, RLS, multi-tenancy)
- **API:** `contracts/openapi/openapi.yaml` + `contracts/events/`
- **Policy:** `contracts/policy/policy.rego` + `contracts/policy/README.md`
- **Connectors:** `contracts/connectors/README.md` + `contracts/connectors/{github,servicenow,slack}/`
- **Deployment:** `iac/terraform/README.md` (AWS cell template)
- **Roadmap:** `roadmap/mvp-v1-v2.md` (phases; v0–v2 scope)
- **Security/NFR:** `nfr/security-model.md`, `nfr/slo-sli.md`, `nfr/reliability-patterns.md`

---

## 10. Quick Checklists

### When Adding a New ToolAction
- [ ] Define input/output JSON schemas in `contracts/connectors/{system}/`
- [ ] Document risk labels (read, write, destructive, etc.)
- [ ] Add idempotency key field to input schema (required for writes)
- [ ] Add to policy allowlist or REQUIRE_HITL rule in `contracts/policy/policy.rego`
- [ ] Implement validation + retry logic in Connector Gateway
- [ ] Add normalized error handling for that system's error responses

### When Adding a Workflow
- [ ] Write YAML definition in `services/control-plane/workflows/` (or via builder API)
- [ ] Pin model (provider + version + config) in `model_pin`
- [ ] Assign risk_tier (low/med/high)
- [ ] Test policy simulation via `/v1/policy/simulate`
- [ ] Verify audit logging + evidence generation in local run
- [ ] Add to docs/todos/ with phases and owner

### When Debugging a Failed Run
- [ ] Check audit logs in Postgres: `audit_log_events` table (hash chain integrity)
- [ ] Inspect run status + step leases in `runs` + `steps` tables
- [ ] Review policy decision in run metadata (look for DENY vs. REQUIRE_HITL)
- [ ] Check DLQ for failed tool calls (connector_gateway logs)
- [ ] Validate idempotency key (should match upstream_event_id for retries)
- [ ] Test policy in isolation via `/v1/policy/simulate`

**Query examples (useful for debugging):**

```sql
-- Find all runs for a tenant in last hour
SELECT run_id, status, created_at, trigger_ref FROM runs
WHERE tenant_id = $1 AND created_at > now() - interval '1 hour'
ORDER BY created_at DESC;

-- Check step status and lease expiry
SELECT step_id, tool_name, status, lease_owner, lease_expires_at, error_message
FROM steps
WHERE run_id = $1
ORDER BY step_index;

-- Validate audit hash chain (detect tampering)
SELECT audit_log_event_id, action_type, previous_hash, created_at
FROM audit_log_events
WHERE tenant_id = $1 AND workspace_id = $2
ORDER BY created_at;

-- Check for stuck approvals (requested but never decided)
SELECT approval_id, run_id, tier, status, created_at
FROM approvals
WHERE tenant_id = $1 AND status = 'requested'
AND created_at < now() - interval '10 minutes';

-- Review DLQ tool calls (failed after retries)
SELECT tool_call_id, tool_action_id, status, error_category, attempt, created_at
FROM tool_calls
WHERE tenant_id = $1 AND status = 'dlq'
ORDER BY created_at DESC LIMIT 10;

-- Inspect policy decision for a run (why was approval required?)
SELECT decision_record_id, tool_action_id, policy_decision, reason_json
FROM decision_records
WHERE run_id = $1;
```

---

**Last updated:** 2025-12-18 | **For questions:** refer to RFC-0001 or service boundary docs.
