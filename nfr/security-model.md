
# Security model (MVP)

## Authn
- SSO-only for enterprise tenants (SAML/OIDC; Okta/Entra first-class)
- Short-lived access tokens; refresh/session TTLs
- Step-up required for: scope grants, policy changes, prod promotion, exports

## Authz
- RBAC for platform access + ABAC policy-as-code (OPA/Rego) for contextual decisions
- Deny-by-default; tool actions require explicit allow + appropriate approval artifact where needed

## Secrets
- No raw secrets in DB; store CredentialRef only
- Secrets in AWS Secrets Manager + KMS envelope encryption

## Supply chain
- MVP: first-party connectors only
- Connector artifacts are versioned and signed; tenant pinning; patch auto-update only

## “Never events”
- cross-tenant leakage
- policy failing open for writes
- secrets in logs/traces/prompts
- destructive/high-impact actions without HITL
