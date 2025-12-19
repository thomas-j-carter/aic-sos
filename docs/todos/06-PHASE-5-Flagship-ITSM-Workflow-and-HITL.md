# PHASE 5 — Flagship ITSM Workflow and HITL

**Goal:** Deliver the Week 10–12 demo scenario as a repeatable, tenant-safe, governance-compliant workflow:  
**“New ServiceNow incident → summarize + classify + propose assignment → HITL approve → write back → evidence bundle + cost-per-ticket reporting.”**

Primary references in the architecture bundle:
- `workflows/itsm-triage/` (if present) or the roadmap doc `roadmap/mvp-v1-v2.md`

## P0 / Critical

- [ ] **Define the canonical ITSM triage workflow YAML (v1)**
  - Steps (minimum):
    1) Ingest webhook payload → normalize → fetch full incident (if allowed)
    2) LLM summarize (metadata-only safe output)
    3) LLM classify (category/priority) + propose assignment (group/user)
    4) Build “write proposal” object + compute risk tier
    5) HITL approval gate (Slack)
    6) Apply reversible writes to ServiceNow (with caps + idempotency)
    7) Emit evidence bundle + metering events
  - DoD:
    - Workflow is versioned and pinned to specific model + connector versions.

- [ ] **Prompting + structured outputs**
  - Require strict JSON output with validation:
    - summary, category, priority, assignment suggestion, confidence, rationale
  - DoD:
    - Invalid JSON output triggers retry with bounded attempts; otherwise fails safely.

- [ ] **HITL approval payload & UX**
  - Approver sees:
    - summary + key fields
    - proposed changes
    - cost estimate + risk tier
    - approve/deny buttons
  - DoD:
    - Deny path leaves incident unchanged; audit reflects decision.

- [ ] **Safe writeback mapping (field allowlist)**
  - Explicitly map:
    - assignment_group, assigned_to, category, priority, internal note field
  - DoD:
    - No other fields can be written even if workflow tries.

- [ ] **Run book for the live demo**
  - Script:
    - Setup tenant/workspace
    - Install connectors + keys
    - Enable policy
    - Trigger test incident
    - Approve in Slack
    - Verify ServiceNow changes
    - Export evidence + cost report
  - DoD:
    - A new operator can execute the demo without tribal knowledge.

## P1 / High

- [ ] **Operator triage console (UI)**
  - View incoming incidents, classification results, approvals queue, and run status.
- [ ] **Fallback classification logic**
  - If LLM fails: conservative defaults + require approval.

## P2 / Medium

- [ ] **Multi-approver routing rules**
  - “If assignment_group = SecurityOps → approver must be in that group”.

## P3 / Low

- [ ] **Auto-approve low risk**
  - Might be desirable later; MVP should stay conservative.

## Exit gate

- [ ] The flagship workflow runs end-to-end on a fresh tenant with metadata-only default, with Slack HITL, reversible ServiceNow writeback, and reproducible demo results.
