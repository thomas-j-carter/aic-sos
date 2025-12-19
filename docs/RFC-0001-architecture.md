
# Architecture Bundle v0.1.1 — Governed AI Delivery Factory (MVP: ITSM Triage)

**Status:** Draft (implementation-ready target)  
**Date:** 2025-12-18  
**MVP theme:** Governed, repeatable AI workflows with enterprise controls, multi-tenant SaaS from day 1, BYO model keys, fail-closed policy, evidence-first.

---

## 0) Executive summary (1–2 pages)

### What we are building
A horizontal **AI-enabled developer/DevOps productivity and workflow automation platform** that provides a governed “AI delivery factory”:
**intake → build → evaluate → approve → deploy → run → monitor → audit → optimize cost**.

**MVP flagship workflow family:** **ITSM ticket triage & routing** (ServiceNow first), with Slack for HITL approvals/ops surfaces.

### Why customers buy it
Organizations struggle to turn AI pilots into production due to:
- unclear governance & auditability,
- unsafe tool actions (prompt injection / confused deputy),
- inability to measure cost/ROI,
- brittle integrations,
- lack of repeatable delivery process.

We provide a **control plane** (governance, approvals, policy-as-code, inventory, metering) and an **execution plane** (policy-enforced runtime, connector gateway, audit evidence) to safely ship and operate AI workflows across existing systems-of-record.

### MVP demo scenario (week 10–12)
**“New ServiceNow incident → summarize + classify + propose assignment → HITL approve → write back (category/priority/assignment + internal note) → evidence bundle + cost-per-ticket reporting.”**

### Non-negotiable invariants (the “constitution”)
- **Deny-by-default**; **fail closed** for tool actions when policy cannot be evaluated or bundle is stale beyond TTL.
- **No cross-tenant access/sharing**; multi-tenant isolation from day 1.
- **ToolAction-level permissions**; all external calls go through a **connector gateway PEP** (no bypass).
- **Evidence-first**: every governed run produces an audit-ready bundle; logs are append-only + hash-chained per tenant/workspace.
- **BYO keys** in MVP; supported providers: **OpenAI, Azure OpenAI, Anthropic**.
- **Metadata-only by default** (no content storage); opt-in content persistence later.
- **Outbound-only agent supported from day 1** (for “no inbound firewall changes” customers).
- **AWS-first**; region-pinned cells in **US + EU** from day 1.
- **No Bazel**.

---

## 1) Product scope boundary (MVP vs enabled vs later)

### In scope (platform owns end-to-end)
- Policy-as-code (OPA/Rego) authoring, publishing, distribution; PEP enforcement (API + runtime + connector gateway)
- Simple approvals (single approver per tier; optional 2-person high-risk via policy)
- Execution/orchestration of workflows/agents (queue-driven Run/Step state machine)
- Connector artifacts + gateway (versioned, pinned, signed); ServiceNow + Slack in MVP; GitHub included as next family seed
- Audit logs + tamper-evidence (hash chain)
- Evidence export bundles (run/approval)
- FinOps: metering + budgets/quotas + cost-per-ticket reporting
- Observability (OTel everywhere; internal backend)

### Explicitly out of scope (MVP)
- RAG / content indexing (no RAG MVP)
- Arbitrary customer code execution
- iPaaS replacement or generic workflow engine replacement
- SIEM replacement; IAM replacement; DLP replacement

---

## 2) Architecture overview

### 2.1 Planes and major subsystems
**Control Plane (Go)**
- Tenancy/workspaces/environments/projects
- Workflow definitions (canonical YAML) + versioning
- Policies (OPA/Rego bundles) + simulation API
- Approvals + release records
- Connector registry + connector instance config (CredentialRef only)
- Metering/budgets/quotas + reporting

**Execution Plane (Rust core + Go orchestrator)**
- Run/Step state machine workers (queue-driven)
- Tool broker + parameter validation
- Policy Enforcement Point (PEP) for runtime actions
- Connector Gateway PEP for all outbound calls
- Idempotency, retries, DLQ, replay tooling
- Evidence emitters: DecisionRecord, ToolCall transcript (redacted), AuditLogEvent

**Outbound-only Agent/Runner (Rust)**
- Optional placement for private connectivity or restricted networks
- mTLS identity bound to tenant/workspace/environment; store-and-forward telemetry
- Runs connector calls locally when configured (agent-only connectors or private endpoints)

**UI Surfaces (TS/React)**
- Admin console (tenant/workspace/policy/connectors/budgets/audit)
- Builder/workbench (YAML + form editor; sandbox tests)
- Operator dashboards (queues/DLQ, connector health, incidents)
- Approvals UI (and Slack approval cards)

### 2.2 Deployment topology (MVP)
- **Multi-tenant SaaS**, **cell-based**, region-pinned **US + EU**.
- Each region has multiple **cells** (Kubernetes clusters or equivalent).
- Control plane services live in-region; execution plane workers live in-region.
- Shared global services hold **no tenant data** (only routing/metadata allowed).
- Data stores per region/cell: Postgres, S3, SQS, Redis, OTel Collector pipeline.

---

## 3) Core data flows (MVP flagship: ServiceNow triage)

### Runtime sequence (simplified)
1. ServiceNow webhook → Ingestion API (verified)
2. Create Run + enqueue steps
3. Step: fetch incident context (read ToolAction)
4. Step: LLM summarize/classify/route (BYO keys)
5. Step: require HITL approval (Slack + UI)
6. On approval: queue write ToolActions (assignment/category/priority + internal work note)
7. Connector Gateway PEP validates schema + idempotency + policy decision
8. Execute write(s), retry/backoff, DLQ on exhaustion
9. Emit evidence (audit + decision trace) and metering; compute cost-per-ticket

**Autonomy stance:** reversible writes allowed (assignment/labels/notes) with caps + policy + idempotency.

---

## 4) Key design decisions

### 4.1 Workflow authoring
- Canonical format: **YAML** (diffable/pinnable)
- Builder: **hybrid** UI + code helpers (generators, templates)
- No arbitrary code execution: only predefined tools and safe transforms (templating, JSON schema validation)

### 4.2 Policy system
- Language: **OPA/Rego**
- Distribution: signed bundles with TTL refresh (5–15 min)
- Decisions: `ALLOW | DENY | REQUIRE_HITL | REQUIRE_STEP_UP | THROTTLE | ROUTE`
- Fail closed for:
  - any external tool action (reads/writes) if PDP unavailable or stale beyond TTL
  - all high-risk actions and any write action

### 4.3 Evidence integrity
- `AuditLogEvent` append-only with per tenant/workspace hash chaining
- Evidence bundle always includes:
  - actor, run, versions, policy decision, tool-call transcript (redacted), idempotency keys, cost summary
- External anchoring (e.g., transparency log / blockchain) deferred to v1+

### 4.4 Multi-tenancy and isolation
- Tenant isolation via cell partitioning + per-tenant keys + strict tenant scoping in DB
- No cross-tenant sharing; templates only (data-free)

### 4.5 Provider strategy (MVP)
- BYO keys for: **OpenAI**, **Azure OpenAI**, **Anthropic**
- Model pinning per workflow version (no silent drift)
- Provider routing is policy-driven; fallback only if allowed

### 4.6 Data handling
- Default: **metadata-only**
- No RAG MVP; no content indexing
- Minimal runtime retention (14–30 days) for operational traces; long retention for audit artifacts (years; configurable)

---

## 5) MVP journeys (the “factory spine”)
1. **Use case intake → scoring → approval** (lightweight in MVP; can be template-driven)
2. **Build workflow → connect systems → configure permissions** (ServiceNow + Slack)
3. **Evaluation gate → approve for prod** (minimal gates in MVP, expanding in v1)
4. **Deploy → canary → monitor → rollback** (rings + pinning; minimal canary)
5. **Runtime: ITSM triage & routing** (flagship)

See sequence diagrams in `diagrams/sequences/*.mmd`.

---

## 6) Contracts and interfaces
- REST APIs (`/v1/...`) documented in `contracts/openapi/openapi.yaml`
- Event contracts as JSON Schema in `contracts/events/`
- Connector manifests and ToolAction definitions in `contracts/connectors/`
- Policy bundle schema and SemVer rules in `contracts/policy/`

---

## 7) NFRs (MVP targets)
- Control plane SLO: **99.5%**
- Execution plane SLO: **99.0%**
- ITSM triage p95 (event → writeback): **12–20s** (p99 45–90s)
- Fail-closed correctness for denied tool calls: **≥99.0%**
- Default trace retention: **14 days** (configurable 30)

Full NFR pack in `nfr/`.

---

## 8) Repo skeleton and delivery artifacts
See `repo/monorepo-layout.md` and `repo/service-boundaries.md` for the concrete code layout and service split.

---

## 9) Open questions (MVP-timeboxed)
- Exact ServiceNow auth patterns supported (OAuth vs basic + mid-server constraints) per customer
- Slack approval UI details and interactive components packaging
- Policy bundle TTL and cache strategy under intermittent partitions (agent)
- Minimum eval suite for MVP “promotion” gate (initially small)

---

---

## Addenda (v0.1.1)

- **DB sketch + RLS notes:** see `data/db-schema.md` (and `repo/db/schema.sql`).
- **Runtime semantics:** see `repo/runtime/state-machine.md` for the queue/worker lease + HITL state machines.
- **AWS cell Terraform skeleton:** see `repo/iac/terraform/` (module + US/EU examples).

These are intentionally “MVP-sufficient” sketches: enough structure to code against, while leaving room for hardening (WAF, HA, private connectivity, external audit anchoring) post-MVP.

