-- Migration 004: Runtime - Executions, Steps, and Approvals
-- Purpose: Track workflow runs, step executions, and approval gates
-- Status: Idempotent (safe to rerun)
-- Created: 2024-12-19

BEGIN;

-- Runs: Workflow execution instances
CREATE TABLE IF NOT EXISTS runs (
  run_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  workflow_version_id UUID NOT NULL REFERENCES workflow_versions(workflow_version_id) ON DELETE RESTRICT,
  -- What triggered this run (e.g., 'manual', 'scheduled', 'incident', 'webhook')
  trigger_type TEXT NOT NULL,
  trigger_ref TEXT,
  -- Who triggered it
  triggered_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  -- Current status
  status run_status NOT NULL DEFAULT 'queued',
  -- When did execution start/finish
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  -- Input: user-provided context/variables
  input_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Output: results/evidence from execution
  output_metadata JSONB DEFAULT '{}'::jsonb,
  -- Error info (if failed)
  error_message TEXT,
  -- Idempotency key: prevents duplicate runs
  idempotency_key TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS runs_tenant_idx ON runs(tenant_id);
CREATE INDEX IF NOT EXISTS runs_workspace_idx ON runs(workspace_id);
CREATE INDEX IF NOT EXISTS runs_workflow_version_idx ON runs(workflow_version_id);
CREATE INDEX IF NOT EXISTS runs_status_idx ON runs(status);
CREATE INDEX IF NOT EXISTS runs_created_at_idx ON runs(created_at);
CREATE INDEX IF NOT EXISTS runs_idempotency_key_idx ON runs(idempotency_key);

-- Steps: Individual step executions within a run
CREATE TABLE IF NOT EXISTS steps (
  step_id UUID PRIMARY KEY,
  run_id UUID NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Step name from workflow definition
  step_name TEXT NOT NULL,
  -- Step type (e.g., 'llm_call', 'connector_action', 'approval_gate', 'branch')
  step_type TEXT NOT NULL,
  -- Sequence in workflow
  sequence INT NOT NULL,
  -- Current status
  status step_status NOT NULL DEFAULT 'ready',
  -- Execution times
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  -- Input/output for this step
  input_metadata JSONB DEFAULT '{}'::jsonb,
  output_metadata JSONB DEFAULT '{}'::jsonb,
  -- Error info (if failed)
  error_message TEXT,
  -- Retry attempt count
  retry_count INT DEFAULT 0,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS steps_run_idx ON steps(run_id);
CREATE INDEX IF NOT EXISTS steps_tenant_idx ON steps(tenant_id);
CREATE INDEX IF NOT EXISTS steps_status_idx ON steps(status);
CREATE INDEX IF NOT EXISTS steps_created_at_idx ON steps(created_at);

-- Approval Requests: HITL gates requiring human approval
CREATE TABLE IF NOT EXISTS approval_requests (
  approval_request_id UUID PRIMARY KEY,
  run_id UUID NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
  step_id UUID NOT NULL REFERENCES steps(step_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Risk tier from workflow (determines who can approve)
  risk_tier TEXT NOT NULL CHECK (risk_tier IN ('low', 'medium', 'high')),
  -- What needs approval (summary)
  approval_subject TEXT NOT NULL,
  approval_context JSONB NOT NULL,
  -- Current status
  status approval_status NOT NULL DEFAULT 'requested',
  -- Who needs to approve
  required_approvers INT DEFAULT 1,
  -- Approval deadline
  expires_at TIMESTAMPTZ,
  -- Notification: was approver notified?
  notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS approval_requests_run_idx ON approval_requests(run_id);
CREATE INDEX IF NOT EXISTS approval_requests_step_idx ON approval_requests(step_id);
CREATE INDEX IF NOT EXISTS approval_requests_tenant_idx ON approval_requests(tenant_id);
CREATE INDEX IF NOT EXISTS approval_requests_status_idx ON approval_requests(status);
CREATE INDEX IF NOT EXISTS approval_requests_expires_at_idx ON approval_requests(expires_at);

-- Approval Decisions: Actual approval/rejection decisions
CREATE TABLE IF NOT EXISTS approval_decisions (
  approval_decision_id UUID PRIMARY KEY,
  approval_request_id UUID NOT NULL REFERENCES approval_requests(approval_request_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- Who made this decision
  decided_by UUID NOT NULL REFERENCES principals(principal_id) ON DELETE RESTRICT,
  -- Decision: approved, rejected, etc.
  decision TEXT NOT NULL CHECK (decision IN ('approved', 'rejected')),
  -- Optional reason/comment
  reason TEXT,
  decided_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS approval_decisions_approval_request_idx ON approval_decisions(approval_request_id);
CREATE INDEX IF NOT EXISTS approval_decisions_tenant_idx ON approval_decisions(tenant_id);
CREATE INDEX IF NOT EXISTS approval_decisions_decided_by_idx ON approval_decisions(decided_by);

-- Tool Calls: LLM API calls and connector invocations
CREATE TABLE IF NOT EXISTS tool_calls (
  tool_call_id UUID PRIMARY KEY,
  run_id UUID NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
  step_id UUID NOT NULL REFERENCES steps(step_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- Tool type: 'llm', 'connector', etc.
  tool_type TEXT NOT NULL,
  -- Tool name (e.g., 'openai/gpt-4', 'slack/post_message')
  tool_name TEXT NOT NULL,
  -- Input to the tool
  input_data JSONB NOT NULL,
  -- Output from tool
  output_data JSONB DEFAULT '{}'::jsonb,
  -- Error (if failed)
  error_message TEXT,
  -- Timing
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  -- Cost/usage data (for metering)
  usage_metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tool_calls_run_idx ON tool_calls(run_id);
CREATE INDEX IF NOT EXISTS tool_calls_step_idx ON tool_calls(step_id);
CREATE INDEX IF NOT EXISTS tool_calls_tenant_idx ON tool_calls(tenant_id);
CREATE INDEX IF NOT EXISTS tool_calls_created_at_idx ON tool_calls(created_at);

-- Attach timestamp updaters
DROP TRIGGER IF EXISTS runs_update_timestamp ON runs;
CREATE TRIGGER runs_update_timestamp
  BEFORE UPDATE ON runs
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS steps_update_timestamp ON steps;
CREATE TRIGGER steps_update_timestamp
  BEFORE UPDATE ON steps
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS approval_requests_update_timestamp ON approval_requests;
CREATE TRIGGER approval_requests_update_timestamp
  BEFORE UPDATE ON approval_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

COMMIT;
