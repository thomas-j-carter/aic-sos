# Contract Map

## Core API Schemas

- evaluate_policy.request.schema.json -> core_api/evaluate_policy.request.schema.json
- evaluate_policy.response.schema.json -> core_api/evaluate_policy.response.schema.json
- issue_approval_token.request.schema.json -> core_api/issue_approval_token.request.schema.json
- issue_approval_token.response.schema.json -> core_api/issue_approval_token.response.schema.json
- execute_run.request.schema.json -> core_api/execute_run.request.schema.json
- execute_run.response.schema.json -> core_api/execute_run.response.schema.json

## Event Schemas

- run.created -> events/run.created.schema.json
- run.policy.requested -> events/run.policy.requested.schema.json
- run.policy.decided -> events/run.policy.decided.schema.json
- run.paused.awaiting_approval -> events/run.paused.awaiting_approval.schema.json
- run.approved -> events/run.approved.schema.json
- run.started -> events/run.started.schema.json
- run.completed -> events/run.completed.schema.json
- run.failed -> events/run.failed.schema.json
- run.blocked -> events/run.blocked.schema.json
