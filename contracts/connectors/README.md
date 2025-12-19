
# Connector contracts (MVP) — ToolActions, idempotency, error taxonomy

## 1) ToolAction = unit of permission and policy
A ToolAction is the smallest externally effectful capability the platform can invoke.

Each ToolAction has:
- `tool_action_id` (stable string)
- input JSON Schema (validated at gateway)
- output schema (for replay/shadow replay)
- required OAuth scopes / permissions
- risk labels: `read|write|destructive|customer_facing|admin|prod_impacting`
- idempotency policy (required for writes)

## 2) Idempotency (writes)
All external write ToolActions MUST accept an `idempotency_key` and MUST be safe under retries.

**Canonical idempotency key** (recommended):
`tenant_id + workspace_id + connector_instance_id + tool_action_id + target_resource_id + upstream_event_id + action_hash`

## 3) Retry/backoff and DLQ rules
- At-least-once delivery internally.
- External writes:
  - bounded retries with exponential backoff + jitter
  - stop on non-retryable errors (validation, authz, permission)
  - DLQ on exhaustion with replay UI

## 4) Error taxonomy (normalized)
Tool call failures are normalized into these categories:

- `POLICY_DENIED`
- `VALIDATION_ERROR`
- `AUTH_ERROR` (token invalid/expired)
- `PERMISSION_ERROR` (scope missing, RBAC)
- `RATE_LIMITED` (429)
- `UPSTREAM_5XX`
- `NETWORK_ERROR`
- `TIMEOUT`
- `CONFLICT` (409 / concurrency)
- `NOT_FOUND`

Each ToolCall record stores:
- `category`, `upstream_status`, `retryable`, `attempt`, `first_seen_at`

## 5) MVP connector set
- ServiceNow (cloud): flagship; read+reversible write
- Slack (cloud): HITL approvals + notifications
- GitHub (cloud): seed for next workflow family (read + comment) — minimal MVP support

See manifests in this folder.
