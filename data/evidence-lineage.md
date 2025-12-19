
# Evidence + lineage (ApprovalArtifact, audit chain, replay)

## Always-producible minimum bundle (metadata-only)
For any governed run:
- Who/what/when: principal_id, tenant/workspace/env, timestamps, request_id/run_id
- Versions: workflow_id, artifact_version, policy_bundle_version, connector_artifact_versions
- Policy decision record: inputs hash + decision + rule_ids fired
- Tool-call transcript (minimized): tool_action_id, target IDs, redacted params, status, idempotency_key
- Cost summary: tokens, runtime seconds, tool calls, budget/quota decision

## Audit log integrity
- Append-only per tenant/workspace stream
- Each event stores: prev_hash, hash, event_id, event_type, occurred_at
- Hash chain computed over canonical JSON serialization

## ApprovalArtifact
Immutable bundle created on approvals:
- change summary/diff pointer
- approver identity + step-up evidence
- policy bundle version + connector scopes
- eval summary pointers (stubbed in MVP; expanded v1)
- signature (or signed manifest) and immutable storage

## Replay/shadow replay
- For runs with write effects: record tool responses and decision path so you can shadow replay without re-executing writes.
