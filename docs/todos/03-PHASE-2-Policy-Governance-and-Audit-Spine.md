# PHASE 2 — Policy, Governance, and Audit Spine

**Goal:** Deliver **fail-closed** policy enforcement, approvals, and **hash-chained** audit integrity sufficient for enterprise governance expectations.

Primary references in the architecture bundle:
- `specs/governance/policy-engine.md`
- `specs/governance/audit-spine.md`
- `specs/governance/approvals.md`

## P0 / Critical

- [ ] **Policy bundle format + signing**
  - Define:
    - Bundle structure (rego + data + metadata)
    - Versioning and pinning to workflow versions (no silent drift)
    - Signature mechanism (e.g., KMS sign + verify in runtime)
  - DoD:
    - Runtime refuses to execute with missing/invalid signatures.

- [ ] **Fail-closed policy evaluation**
  - For every tool/action request:
    - Evaluate policy → allow/deny + rationale + obligations (caps, required approvals)
    - If evaluation errors or policy missing → **deny**
  - DoD:
    - Unit tests prove “policy service down” blocks writes and risky actions.

- [ ] **Policy simulation (“dry run”) endpoint**
  - Input: proposed scopes/actions/workflow + tenant settings
  - Output: what would be allowed/denied + why
  - DoD:
    - UI can display simulation results before enabling connector scopes.

- [ ] **Approval model: simple but sufficient**
  - Support:
    - Single approver per risk tier
    - Optional 2-person approval for “high risk” (policy setting)
  - DoD:
    - Approval requests are immutable records.
    - Approver identity is captured and hashed into audit chain.

- [ ] **Write caps + reversible writes**
  - Enforce caps per workflow version:
    - max writes per run
    - allowed write types (assignment, labels, internal note)
    - field-level allowlist for ServiceNow writeback
  - DoD:
    - Exceeding caps fails the run with a clear reason and audit record.

- [ ] **Audit spine: hash-chained append-only**
  - Implement per tenant/workspace:
    - `AuditEvent` with `prev_hash`, `event_hash`, `sequence`
    - Hash includes canonical event payload + prev hash
  - DoD:
    - Tampering with any event breaks chain verification.
    - Provide “verify audit chain” CLI or admin endpoint.

- [ ] **Evidence bundle structure (governance-ready)**
  - Minimum bundle contents for each run:
    - Run metadata (workflow version pinned, model pins)
    - Inputs (redacted as required by data mode)
    - All tool calls + responses (redacted as required)
    - Policy decisions + approvals
    - Cost + token usage
  - DoD:
    - Evidence bundle is exportable as a single archive (zip/tar) and referenced in audit.

## P1 / High

- [ ] **Human-readable policy explanations**
  - “Denied because: missing scope X” + “Allowed but requires approval tier Y”.
- [ ] **Admin policy templates**
  - Starter policies for ITSM triage + safe writeback.

## P2 / Medium

- [ ] **External anchoring hooks**
  - Stub: daily anchor of audit chain head to external store (later).
- [ ] **Signed evidence bundles**
  - Sign bundle manifests (not just audit events).

## P3 / Low

- [ ] **Policy authoring UI**
  - MVP can ship with YAML + rego in repo; UI later.

## Exit gate

- [ ] Every run produces a verifiable audit chain and evidence bundle; any missing/invalid policy causes deny-by-default; policy simulation works before enabling scopes.
