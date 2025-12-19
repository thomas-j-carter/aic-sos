# PHASE 3 — Execution Plane: Workflow Runs and Agents

**Goal:** Implement the run-time that can execute a workflow version deterministically with **model pinning**, **idempotency**, **HITL gates**, and optional outbound-only agent execution.

Primary references in the architecture bundle:
- `specs/runtime/run-orchestrator.md`
- `specs/runtime/runner-sandbox.md`
- `specs/runtime/agent.md`
- `specs/workflows/yaml-spec.md`

## P0 / Critical

- [ ] **Workflow YAML schema + validator**
  - Must support:
    - Trigger (webhook) → steps (LLM summarize/classify) → approval gate → writeback
    - Step inputs/outputs typing
    - Version pinning to connector + model pins
  - DoD:
    - Invalid workflows are rejected at publish time (not at run time).

- [ ] **Run state machine implementation**
  - States: created → running → awaiting_approval → running → completed/failed/cancelled
  - Include retry strategy (bounded) + idempotency.
  - DoD:
    - `docs` (or code) includes state diagram + invariant tests.

- [ ] **Tool execution contract**
  - Standard request/response envelope for tool calls:
    - includes tenant/workspace, workflow version, step id, idempotency key, policy context
  - DoD:
    - Runner refuses unscoped calls; all calls produce audit events.

- [ ] **LLM provider abstraction with BYO keys**
  - OpenAI + Azure OpenAI + Anthropic:
    - Model selection pinned per workflow version
    - Request timeouts, retries, and usage capture (tokens, latency)
  - DoD:
    - Provider outages degrade gracefully with bounded retries and clear failure modes.

- [ ] **Idempotency + receipts for reversible writes**
  - For write tools:
    - Generate/store idempotency key per (run, step, action)
    - Store action receipt (remote system ID + prior values if needed)
  - DoD:
    - Safe to replay a run without duplicating writes.

- [ ] **Outbound-only agent (MVP-minimum support)**
  - Agent can:
    - Establish outbound mTLS connection
    - Pull jobs / receive tasks
    - Execute connector actions (future-proof for customer network)
  - DoD:
    - A “hello agent” job works end-to-end in a dev environment.
    - Agent identity is bound to tenant/workspace and policies.

- [ ] **Cancellation + timeouts**
  - Support operator cancellation and max runtime per run/step.
  - DoD:
    - Cancelled runs stop further tool calls; audit reflects cancellation.

## P1 / High

- [ ] **Concurrency controls**
  - Per tenant/workspace: max concurrent runs + per-workflow cap.
- [ ] **Dead letter handling**
  - Poison message detection; manual retry tooling.

## P2 / Medium

- [ ] **Step caching for metadata-only mode**
  - Avoid storing content, but allow computed classifications to persist.

## P3 / Low

- [ ] **Plugin/provider architecture for on-device models**
  - Defer; keep interface stable.

## Exit gate

- [ ] Given a published workflow version, the system can execute a run from a webhook trigger through HITL and writeback, with policy checks on every action, idempotent retries, and optional agent execution support.
