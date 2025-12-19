
# Service boundaries (MVP)

## control-plane (Go)
- tenancy/workspaces
- workflows (YAML), versions
- connector instances (CredentialRef pointers)
- approvals/releases
- policy bundle publishing + simulation API
- audit query + evidence export
- metering/budgets/quotas APIs

## execution-plane (Rust core + Go orchestration)
- queue workers running Run/Step state machine
- LLM call adapter (BYO keys)
- HITL tasks creation and waiting
- emits evidence + metering events

## connector-gateway (Rust/Go)
- final PEP before external calls
- schema validation + redaction
- idempotency + retries/backoff + DLQ integration
- normalized error taxonomy

## policy
- OPA bundles (Rego) + regression tests
- bundle signing + distribution metadata

## agent (Rust)
- outbound-only connectivity
- executes connector calls locally if configured
- store-and-forward for telemetry

## ui (TS/React)
- admin/builder/ops surfaces
