
# Risk register (starter)

| Risk | Trigger | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|
| Policy bypass (external calls not gated) | connector code path bypasses gateway | severe (never event) | enforce single egress path; integration tests; network egress policies | Security/Runtime | Open |
| Cross-tenant leakage | missing tenant scoping or RLS bug | severe | cell isolation + strict tenant key checks + automated tests | Platform | Open |
| Duplicate writes | missing idempotency on ToolActions | high | mandatory idempotency keys; retry + DLQ; fixtures | Runtime | Open |
| Excess telemetry cost | tag cardinality explosion | medium-high | enforced sampling, tag caps, per-cell budgets | SRE | Open |
| Vendor webhook drift | ServiceNow schema changes | medium | contract tests + recorded fixtures; reconciliation polling | Connector Owner | Open |
| IAM outage impact | IdP down | medium | cached claims within TTL; degrade login | Platform | Open |
| Model provider outage | provider down | medium | policy-approved fallback; queue/degrade | Runtime | Open |
| Multi-region MVP complexity | US+EU from day1 | high schedule risk | limit features; identical stacks; automate IaC; phased tenants | SRE | Open |
