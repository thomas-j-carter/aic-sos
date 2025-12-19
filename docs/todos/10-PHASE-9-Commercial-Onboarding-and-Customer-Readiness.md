# PHASE 9 — Commercial, Onboarding, and Customer Readiness

**Goal:** Make MVP usable by the first 10 paying tenants under an enterprise sales motion (even if some processes are manual at first).

## P0 / Critical (launch-blockers for paid tenants)

- [ ] **Tenant onboarding playbook (high-touch)**
  - Includes:
    - Security/IT questionnaire answers (standardized)
    - Key + connector setup steps (ServiceNow/Slack/GitHub)
    - Region selection + data mode decision tree
    - Policy simulation walkthrough before enabling writes
  - DoD:
    - A Solutions Engineer can onboard a tenant in < 2 hours with a checklist.

- [ ] **Support + escalation process**
  - Define:
    - support channels
    - severity levels
    - response targets
    - incident comms template
  - DoD:
    - You can handle a Sev-1 during onboarding with a defined owner and steps.

- [ ] **Minimum legal/compliance artifacts**
  - Prepare (even if lightweight):
    - Privacy policy + data processing summary
    - BYO keys responsibility model
    - Data residency statement (US/EU pinning)
    - Security overview (encryption, audit, access controls)
  - DoD:
    - Packaged as PDFs or docs that can be shared during procurement.

- [ ] **Pricing + metering policy aligned to “capacity units”**
  - Decide:
    - what is metered (runs/min, concurrency, write caps, retention/indexing)
    - overage behavior (throttle vs bill vs hard-fail) — recommend **throttle + notify**
  - DoD:
    - Admin UI shows current usage vs limit; system enforces limits.

## P1 / High

- [ ] **Customer-facing docs**
  - Quickstart per connector (ServiceNow/Slack/GitHub)
  - “How approvals work” + “How evidence bundles work”
- [ ] **Procurement accelerators**
  - Standard security questionnaire responses, architecture diagram, pen-test plan.

## P2 / Medium

- [ ] **DPA template + SCCs for EU**
  - Often required quickly once EU tenants appear.

## P3 / Low

- [ ] **Self-serve billing portal**
  - Not needed for high-touch year 1.

## Exit gate

- [ ] You can confidently onboard and support a paying tenant: docs, legal/security pack, usage limits, and a repeatable onboarding checklist all exist and are internally tested.
