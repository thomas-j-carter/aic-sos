
# Reliability patterns (MVP)

- At-least-once delivery with idempotency on all writes
- Retries with exponential backoff + jitter; DLQ with operator replay
- Outbox/inbox pattern for state transitions and side effects
- Execution-time authz/policy re-check (TOCTOU protection)
- Store-and-forward for telemetry exports; internal evidence capture must not depend on external backends
- Graceful degradation:
  - If LLM provider down: route to approved fallback (policy) or queue/stop
  - If ServiceNow down: queue writes (idempotent) and expose backlog age
  - If policy unavailable: fail closed for tool actions
