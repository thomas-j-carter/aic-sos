# PHASE 4 — Connectors: ServiceNow, Slack, GitHub

**Goal:** Ship the first 3 connectors (ranked): **ServiceNow**, **Slack**, **GitHub**, with OAuth where available, customer-managed app registrations, and webhook-first triggers with polling reconciliation as safety net.

Primary references in the architecture bundle:
- `specs/connectors/connector-manifest.md`
- `specs/connectors/credentialing.md`
- `specs/connectors/webhooks-and-polling.md`

## P0 / Critical

- [ ] **Connector framework + manifest validation**
  - Define:
    - Actions (read/write), scopes, risk tier, idempotency requirements
    - Input/output schemas for each action
  - DoD:
    - CI validates manifests + schemas.
    - Runtime refuses unknown/unsigned connector artifacts.

- [ ] **Credential storage + OAuth flows**
  - OAuth where available; customer-managed app registrations.
  - Store:
    - client_id/client_secret references (per tenant policy)
    - refresh/access tokens encrypted
  - DoD:
    - Token refresh works; tokens never appear in logs.

- [ ] **ServiceNow connector (cloud) — MVP workflow complete**
  - Triggers:
    - Inbound webhook endpoint (tenant/workspace secret)
    - Polling reconciliation job (periodic “catch missed events”)
  - Read actions (minimum):
    - Fetch incident by sys_id/number
  - Write actions (reversible subset only):
    - Update assignment group/user
    - Update category/priority
    - Add internal note/work note
  - DoD:
    - Full demo scenario works end-to-end and updates the incident as expected.

- [ ] **Slack connector — HITL approvals and notifications**
  - Capabilities:
    - Send approval request message with context + buttons
    - Handle interactive callbacks securely
    - Post decision + audit trail link
  - DoD:
    - Approver can approve/deny in Slack; run resumes correctly.

- [ ] **GitHub connector — MVP-minimal “committed integration”**
  - Minimum capabilities:
    - Auth via GitHub App or OAuth (prefer App for enterprise)
    - Read-only actions: list PRs/issues, fetch file contents (for future SDLC family)
  - DoD:
    - Connector installs and can perform at least one read action end-to-end.

- [ ] **Webhook security + tenancy routing**
  - Verify:
    - Per-connector signing/secret scheme
    - Tenant/workspace routing without leaking identifiers
  - DoD:
    - Invalid signature → rejected, audited.
    - Replay protection where possible.

## P1 / High

- [ ] **Connector “scopes enablement” UX**
  - Admin sees requested scopes + policy simulation result before enabling.
- [ ] **Rate limiting / backoff per connector**
  - Avoid getting customers’ SaaS instances throttled.

## P2 / Medium

- [ ] **Connector testing harness**
  - Contract tests with recorded fixtures; optional live tests in CI (gated).

## P3 / Low

- [ ] **Additional ITSM systems**
  - JSM/Zendesk after MVP.

## Exit gate

- [ ] ServiceNow webhooks trigger runs, Slack approves them, and the system writes back to ServiceNow with idempotency + policy enforcement; GitHub connector installs and performs at least one read action.
