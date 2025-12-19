# PHASE 8 — Security, Test Gates, and Launch Runbook

**Goal:** Make MVP launchable: security controls, testing rigor, operational readiness, and a clear launch checklist.

Primary references in the architecture bundle:
- `risk/risk-register.md`
- `roadmap/mvp-v1-v2.md`
- `specs/security/threat-model.md` (if present)

## P0 / Critical

- [ ] **Threat model + top risks addressed**
  - Must cover:
    - cross-tenant data leakage
    - prompt injection → unsafe tool writes
    - webhook spoofing/replay
    - secrets exposure (BYO keys, OAuth tokens)
    - policy bypass / “fail open”
  - DoD:
    - Mitigations implemented for top risks + tracked residual risk.

- [ ] **End-to-end test suite for the demo path**
  - Include:
    - webhook ingestion → run creation
    - LLM step with stubbed provider in CI
    - approval flow (Slack) with mocked callback
    - ServiceNow writeback with mock server (and optional live tests in staging)
  - DoD:
    - CI can run “demo path” test deterministically.

- [ ] **Security gates**
  - Required:
    - dependency vulnerability scanning
    - container image scanning
    - policy evaluation tests (fail-closed)
  - DoD:
    - Release cannot be cut if scans fail above threshold.

- [ ] **Operational runbooks**
  - Must include:
    - how to onboard a tenant
    - rotate provider keys / connector creds
    - investigate a failed run
    - verify audit chain and export evidence
    - incident response (security + availability)
  - DoD:
    - A non-author can follow runbooks successfully in staging.

- [ ] **Launch checklist (go/no-go)**
  - Security:
    - encryption at rest + in transit confirmed
    - least privilege IAM reviewed
    - WAF rules enabled
  - Product:
    - flagship workflow stable in US and EU
    - reporting and evidence export works
  - Ops:
    - alerts wired + on-call rotation named
    - backups/restores tested
  - DoD:
    - Signed-off checklist stored as an artifact.

## P1 / High

- [ ] **Pen-test readiness**
  - Harden headers, rate limits, abuse prevention, logging redaction review.
- [ ] **Customer-facing docs**
  - Security whitepaper-lite, data residency, and “how BYO keys work”.

## P2 / Medium

- [ ] **SOC2-readiness mapping**
  - Control mapping doc; evidence collection plan.

## P3 / Low

- [ ] **External audit chain anchoring**
  - Post-MVP.

## Exit gate

- [ ] You can run a full tenant onboarding + demo scenario in staging and production with test coverage, documented operational procedures, and security gates green.
