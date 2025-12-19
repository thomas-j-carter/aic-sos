# TODO Pack: From Current Scaffold → MVP Launch

## New (v0.1.1): Solo-founder execution helpers

- **01-SOLO-FOUNDER-OPERATING-SYSTEM.md** — how to run the plan as a 1-person team
- **02-MVP-CRITICAL-PATH.md** — the minimal ordered set of P0s to reach MVP launch
- **03-MVP-LAUNCH-CHECKLIST.md** — final pre-prod checks (security/ops/onboarding)
Generated: **2025-12-18** (America/New_York)

This pack is an **ordered set of TODO markdown files** to go from where we are now (architecture bundle + monorepo scaffold) to **MVP launch** for the flagship workflow: **ITSM ticket triage + routing** (ServiceNow + Slack HITL, GitHub connector committed but minimal).

## Criticality labels

- **P0 / Critical**: Required for a secure, credible MVP and launch readiness.
- **P1 / High**: Strongly recommended for first 10 paying tenants; can slip slightly if the demo path is solid.
- **P2 / Medium**: Valuable but not required for MVP launch.
- **P3 / Low**: Post‑MVP backlog.

## Working assumptions (locked)

- Enterprise-first, multi-tenant **from day 1**
- **AWS-first** with **US + EU region pinning** (no cross-region replication by default)
- **BYO keys** in MVP (OpenAI + Azure OpenAI + Anthropic)
- Outbound-only **customer agent** supported in MVP (no inbound firewall changes)
- **Fail-closed policy** enforcement + dry-run policy simulation
- **Reversible writes** allowed in MVP (assignment/labels/internal notes) with caps + idempotency
- Default tenant data mode: **metadata-only** (content persistence/indexing opt-in)
- Audit integrity: **hash-chained append-only** per tenant/workspace (external anchoring later)
- No arbitrary customer code execution in MVP; no RAG in MVP

## How to use

1. Work files **in order**: `00` → `01` → … → `09`.
2. Treat each file’s “Exit gate” as the objective signal that the phase is done.
3. For each item: check the box only when the stated DoD is met.

---
## File order

1. `01-PHASE-0-Repo-and-Delivery-System.md`
2. `02-PHASE-1-Control-Plane-MultiTenancy-and-Identity.md`
3. `03-PHASE-2-Policy-Governance-and-Audit-Spine.md`
4. `04-PHASE-3-Execution-Plane-Workflow-Runs-and-Agents.md`
5. `05-PHASE-4-Connectors-ServiceNow-Slack-GitHub.md`
6. `06-PHASE-5-Flagship-ITSM-Workflow-and-HITL.md`
7. `07-PHASE-6-Metering-Evidence-and-Reporting.md`
8. `08-PHASE-7-AWS-Infra-Regions-Observability.md`
9. `09-PHASE-8-Security-Test-Gates-and-Launch-Runbook.md`
10. `10-PHASE-9-Commercial-Onboarding-and-Customer-Readiness.md`

## Quick critical path (one-line)

Repo+CI → Multi-tenant control plane → Policy fail-closed + audit hash chain → Workflow run engine → ServiceNow+Slack connectors → ITSM triage workflow end-to-end → Evidence+metering → Multi-region deploy → Security + test gates → Launch → Onboard first paying tenants.