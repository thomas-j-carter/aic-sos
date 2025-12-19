-- Migration 006: Audit and Metering - Event Logging and Usage Tracking
-- Purpose: Append-only audit logs and usage metering for compliance
-- Status: Idempotent (safe to rerun)
-- Created: 2024-12-19

BEGIN;

-- Audit Events: Immutable, append-only audit log
-- Hash-chained for tamper detection
CREATE TABLE IF NOT EXISTS audit_events (
  audit_event_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Actor: who performed the action
  actor_id UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  -- Action: what happened (e.g., 'workflow.created', 'run.started', 'key.rotated')
  action TEXT NOT NULL,
  -- Resource: what was affected (e.g., 'workflow:abc123', 'run:def456')
  resource_type TEXT NOT NULL,
  resource_id UUID,
  -- Change details: what changed
  change_details JSONB DEFAULT '{}'::jsonb,
  -- Status: 'success' or 'failure'
  status TEXT NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'failure')),
  -- Error message (if failure)
  error_message TEXT,
  -- Source: where did this action come from (e.g., 'api', 'ui', 'scheduled')
  source TEXT DEFAULT 'api',
  -- Client info
  client_ip TEXT,
  user_agent TEXT,
  -- Hash chain: pointer to previous event for tamper detection
  previous_event_id UUID REFERENCES audit_events(audit_event_id) ON DELETE SET NULL,
  event_hash BYTEA,
  -- Retention: when should this be archived/deleted (null = never)
  retention_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS audit_events_tenant_idx ON audit_events(tenant_id);
CREATE INDEX IF NOT EXISTS audit_events_workspace_idx ON audit_events(workspace_id);
CREATE INDEX IF NOT EXISTS audit_events_actor_idx ON audit_events(actor_id);
CREATE INDEX IF NOT EXISTS audit_events_action_idx ON audit_events(action);
CREATE INDEX IF NOT EXISTS audit_events_resource_idx ON audit_events(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS audit_events_created_at_idx ON audit_events(created_at);

-- Metering Events: Track usage for billing and quota enforcement
CREATE TABLE IF NOT EXISTS metering_events (
  metering_event_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Metric type: 'llm_tokens', 'connector_calls', 'api_calls', 'storage_bytes'
  metric_type TEXT NOT NULL,
  -- Metric name: e.g., 'openai_gpt4_input_tokens', 'slack_post_message_calls'
  metric_name TEXT NOT NULL,
  -- Quantity: how many (tokens, calls, bytes)
  quantity DECIMAL(18, 2) NOT NULL,
  -- Unit: 'tokens', 'calls', 'bytes', 'minutes'
  unit TEXT NOT NULL,
  -- Cost: calculated cost (in cents or smallest currency unit)
  cost_in_cents DECIMAL(10, 4) DEFAULT 0,
  -- Reference: what caused this metering event
  run_id UUID REFERENCES runs(run_id) ON DELETE SET NULL,
  tool_call_id UUID REFERENCES tool_calls(tool_call_id) ON DELETE SET NULL,
  -- Metadata for debugging
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS metering_events_tenant_idx ON metering_events(tenant_id);
CREATE INDEX IF NOT EXISTS metering_events_workspace_idx ON metering_events(workspace_id);
CREATE INDEX IF NOT EXISTS metering_events_metric_type_idx ON metering_events(metric_type);
CREATE INDEX IF NOT EXISTS metering_events_created_at_idx ON metering_events(created_at);

-- Usage Summary: Aggregated usage per workspace (for fast lookup)
-- Updated periodically (hourly or daily)
CREATE TABLE IF NOT EXISTS usage_summary (
  usage_summary_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Period: 'hourly', 'daily', 'monthly'
  period TEXT NOT NULL CHECK (period IN ('hourly', 'daily', 'monthly')),
  -- Period start/end
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  -- LLM usage
  llm_input_tokens BIGINT DEFAULT 0,
  llm_output_tokens BIGINT DEFAULT 0,
  -- API calls
  api_calls_count INT DEFAULT 0,
  -- Storage
  storage_bytes BIGINT DEFAULT 0,
  -- Cost
  total_cost_in_cents DECIMAL(10, 4) DEFAULT 0,
  -- Last updated
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workspace_id, period, period_start)
);

CREATE INDEX IF NOT EXISTS usage_summary_tenant_idx ON usage_summary(tenant_id);
CREATE INDEX IF NOT EXISTS usage_summary_workspace_idx ON usage_summary(workspace_id);
CREATE INDEX IF NOT EXISTS usage_summary_period_idx ON usage_summary(period_start);

-- Audit Log Settings: Per-tenant audit configuration
CREATE TABLE IF NOT EXISTS audit_config (
  audit_config_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL UNIQUE REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- Retention period: how long to keep audit logs (days)
  retention_days INT DEFAULT 365,
  -- Log level: 'minimal', 'standard', 'verbose'
  log_level TEXT DEFAULT 'standard' CHECK (log_level IN ('minimal', 'standard', 'verbose')),
  -- Sensitive field masking: should we mask sensitive values?
  mask_sensitive_fields BOOLEAN DEFAULT TRUE,
  -- Export configuration: where to export audit logs
  export_enabled BOOLEAN DEFAULT FALSE,
  export_destination TEXT,
  -- Last exported timestamp
  last_export_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS audit_config_tenant_idx ON audit_config(tenant_id);

-- Attach timestamp updater
DROP TRIGGER IF EXISTS audit_config_update_timestamp ON audit_config;
CREATE TRIGGER audit_config_update_timestamp
  BEFORE UPDATE ON audit_config
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS usage_summary_update_timestamp ON usage_summary;
CREATE TRIGGER usage_summary_update_timestamp
  BEFORE UPDATE ON usage_summary
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

COMMIT;
