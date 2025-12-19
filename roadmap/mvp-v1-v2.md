
# Roadmap: MVP → v1 → v2

## MVP (10–12 weeks)
- ServiceNow + Slack vertical slice (webhook → policy → HITL → reversible writeback)
- Multi-tenant cell-based SaaS in US + EU
- SSO (SAML/OIDC), RBAC
- OPA/Rego policy with fail-closed PEPs (runtime + connector gateway)
- Evidence spine: audit hash chain + export bundle
- Metering + budgets/quotas + cost-per-ticket
- Outbound agent available (mTLS) for no-inbound environments

## v1 (4–6 months after MVP)
- BYOC execution/data plane (customer cloud) while control plane remains SaaS
- SCIM provisioning
- Expanded eval gates (regression, injection/tool misuse suites)
- More connectors: Jira/JSM/Zendesk, GitLab, Teams/M365
- BYOK for platform keys (enterprise tiers)
- OTel export to customer backends

## v2 (9–12 months after MVP)
- On-prem / air-gapped packaging (subset)
- Legal hold / eDiscovery exports
- Partner/marketplace connectors (signed + sandbox + approvals)
