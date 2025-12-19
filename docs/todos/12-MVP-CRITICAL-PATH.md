# MVP Critical Path (Solo)

This is the **minimal ordered** set of work that must be complete to reach an MVP launch for the flagship workflow:
**ServiceNow incident → summarize/classify → propose assignment → HITL approve → reversible writeback + evidence bundle + cost-per-ticket reporting.**

> This file references the phase TODOs. You should complete phases **in order**, but keep this critical path as your “north star”.

## P0 / Critical (must be done before launch)

### Milestone 0 — Repo boots + delivery system ✅
- [x] Complete **all P0s in 01-PHASE-0-Repo-and-Delivery-System.md**
  - ✅ Unpack scaffold, versioning, local dev (make dev), CI pipeline (12 jobs), contracts as truth, baseline security hygiene
  - **Completed:** December 18, 2025

### Milestone 1 — Multi-tenant control plane + identity (US/EU pinning)
- [ ] Complete **all P0s in 02-PHASE-1-Control-Plane-MultiTenancy-and-Identity.md**
- [ ] Pick the **first tenant type**: “single-workspace enterprise” (still multi-tenant architecture) for initial pilots.

### Milestone 2 — Agent (outbound-only) + secure connectivity
- [ ] Complete **all P0s in 03-PHASE-2-Agent-and-Connectivity.md**
- [ ] Ensure “no inbound firewall changes” story is true for ServiceNow + Slack.

### Milestone 3 — Workflow runtime + policy fail-closed + idempotent reversible writes
- [ ] Complete **all P0s in 04-PHASE-3-Workflow-Runtime-and-Tools.md**
- [ ] Add caps: runs/min, concurrency, write caps, tool allow-lists.

### Milestone 4 — Governance: approvals, audit (hash chain), evidence bundles
- [ ] Complete **all P0s in 05-PHASE-4-Governance-Policy-Audit-and-Evidence.md**

### Milestone 5 — Connectors: ServiceNow + Slack (HITL) (GitHub optional for MVP)
- [ ] Complete **all P0s in 06-PHASE-5-Connectors-ServiceNow-Slack-GitHub.md**
- [ ] Validate webhooks-first + polling reconciliation safety net.

### Milestone 6 — UI / operator experience + reporting
- [ ] Complete **all P0s in 07-PHASE-6-UI-Workbench-HITL-and-Reporting.md**

### Milestone 7 — Reliability + security hardening
- [ ] Complete **all P0s in 08-PHASE-7-Reliability-Security-and-Operations.md**

### Milestone 8 — Launch readiness (design partners → paying)
- [ ] Complete **all P0s in 09-PHASE-8-Demo-Story-and-Design-Partner-Pilot.md**
- [ ] Complete **all P0s in 10-PHASE-9-Commercial-Onboarding-and-Customer-Readiness.md**

## P1 / High (strongly recommended before launch, but negotiable)

- [ ] Work through **P1s** in phases 1–7 that reduce onboarding friction (SSO polish, installer UX, better error messages).
- [ ] Add at least one “boring but vital” operational loop:
  - [ ] Daily backup validation OR
  - [ ] Automated canary run of the flagship workflow.

## P2 / Medium (post-MVP candidates)

- [ ] GitHub connector full workflow (keep only auth + minimal read operations for MVP if needed).
- [ ] External audit anchoring for hash-chains.
- [ ] RAG / indexing (explicitly deferred per scope lock).
