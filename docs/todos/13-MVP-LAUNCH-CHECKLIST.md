# MVP Launch Checklist

Use this once the demo drill is stable in **staging** and you’re preparing to run **production** tenants.

## P0 / Critical

### Security + governance
- [ ] Fail-closed policy verified for: writes, provider access, connector scopes, region constraints.
- [ ] BYO keys flow works end-to-end (OpenAI, Azure OpenAI, Anthropic) and keys are stored + rotated safely.
- [ ] Audit log is append-only and hash-chained per tenant/workspace; export works.
- [ ] Evidence bundles generated for: incident processing runs + HITL approvals + writebacks.

### Reliability + operations
- [ ] Observability: dashboards for agent health, connector errors, workflow latency, cost/runs.
- [ ] Backup & restore: at least one successful restore in a non-prod environment.
- [ ] Runbook: “connector outage”, “provider outage”, “bad policy rollout”, “stuck workflow”.
- [ ] Rate limits + caps enforced (runs/min, concurrency, write caps, token/cost caps).

### Customer onboarding
- [ ] Onboarding path is documented (and tested) for:
  - [ ] ServiceNow OAuth app registration
  - [ ] Slack app + scopes
  - [ ] Agent install + outbound connectivity
- [ ] Region pinning validated (US/EU) and customer can see/verify it.
- [ ] “Metadata-only by default” is enforced; content indexing is opt-in and auditable.

### Legal / commercial minimum
- [ ] Terms + Privacy policy + security page (plain-language) published.
- [ ] Billing workflow for first 10 tenants is workable (even if “manual invoicing” initially).

## P1 / High

- [ ] 2-person approval policy option is testable (even if UI is simple).
- [ ] Customer-facing status page (can be lightweight).
- [ ] Basic security questionnaire answers ready (template).

## P2 / Medium

- [ ] SOC2 readiness tracker (post-MVP).
- [ ] BYOC roadmap doc (v1).
