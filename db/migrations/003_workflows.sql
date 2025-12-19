-- Migration 003: Workflows - Definitions, Versions, and Policies
-- Purpose: Immutable versioned workflows and policy bindings
-- Status: Idempotent (safe to rerun)
-- Created: 2024-12-19

BEGIN;

-- Workflows: Template definitions (metadata)
CREATE TABLE IF NOT EXISTS workflows (
  workflow_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  -- Owner/creator principal
  created_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  -- Latest version reference (denormalized, for quick lookups)
  latest_version_id UUID,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workspace_id, name)
);

CREATE INDEX IF NOT EXISTS workflows_tenant_idx ON workflows(tenant_id);
CREATE INDEX IF NOT EXISTS workflows_workspace_idx ON workflows(workspace_id);
CREATE INDEX IF NOT EXISTS workflows_created_by_idx ON workflows(created_by);

-- Workflow Versions: Immutable, pinned versions (never updated, only created)
-- Each workflow can have multiple versions
CREATE TABLE IF NOT EXISTS workflow_versions (
  workflow_version_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workflow_id UUID NOT NULL REFERENCES workflows(workflow_id) ON DELETE CASCADE,
  -- Semantic version (e.g., '1.0.0', '2.1.3')
  version TEXT NOT NULL,
  -- YAML definition of the workflow (immutable)
  definition_yaml TEXT NOT NULL,
  -- Digest of definition for quick comparison (SHA256)
  definition_digest BYTEA NOT NULL,
  -- Model pins: which LLM models to use (pinned at version time)
  model_pin JSONB NOT NULL,
  -- Risk tier: 'low', 'medium', 'high' (determines approval routing)
  risk_tier TEXT NOT NULL DEFAULT 'low' CHECK (risk_tier IN ('low', 'medium', 'high')),
  -- Published: whether this version is ready for execution
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  -- Who published this version
  published_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workflow_id, version)
);

CREATE INDEX IF NOT EXISTS workflow_versions_tenant_idx ON workflow_versions(tenant_id);
CREATE INDEX IF NOT EXISTS workflow_versions_workflow_idx ON workflow_versions(workflow_id);
CREATE INDEX IF NOT EXISTS workflow_versions_is_published_idx ON workflow_versions(is_published);

-- Policies: Policy definitions (Rego, OPA-based)
CREATE TABLE IF NOT EXISTS policies (
  policy_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  -- Policy content (Rego)
  policy_rego TEXT NOT NULL,
  -- Digest of policy (SHA256)
  policy_digest BYTEA NOT NULL,
  -- Description of what this policy enforces
  description TEXT,
  -- Who created this policy
  created_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, name, version)
);

CREATE INDEX IF NOT EXISTS policies_tenant_idx ON policies(tenant_id);
CREATE INDEX IF NOT EXISTS policies_created_by_idx ON policies(created_by);

-- Policy Bindings: Which policies apply to which workflows/steps
CREATE TABLE IF NOT EXISTS policy_bindings (
  policy_binding_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  policy_id UUID NOT NULL REFERENCES policies(policy_id) ON DELETE CASCADE,
  -- Can bind to a workflow (all versions) or specific workflow version
  workflow_id UUID REFERENCES workflows(workflow_id) ON DELETE CASCADE,
  workflow_version_id UUID REFERENCES workflow_versions(workflow_version_id) ON DELETE CASCADE,
  -- Priority: lower number = higher priority (evaluated in order)
  priority INT DEFAULT 100,
  -- Is this binding active?
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS policy_bindings_tenant_idx ON policy_bindings(tenant_id);
CREATE INDEX IF NOT EXISTS policy_bindings_workspace_idx ON policy_bindings(workspace_id);
CREATE INDEX IF NOT EXISTS policy_bindings_policy_idx ON policy_bindings(policy_id);
CREATE INDEX IF NOT EXISTS policy_bindings_workflow_idx ON policy_bindings(workflow_id);

-- Enum types for run/step status
DO $$ BEGIN
  CREATE TYPE run_status AS ENUM (
    'queued', 'running', 'waiting_approval', 'succeeded', 'failed_retryable', 'failed_terminal', 'canceled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE step_status AS ENUM (
    'ready', 'running', 'waiting_approval', 'succeeded', 'failed_retryable', 'failed_terminal', 'canceled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE approval_status AS ENUM ('requested', 'approved', 'rejected', 'expired', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Attach timestamp updater to workflows table
DROP TRIGGER IF EXISTS workflows_update_timestamp ON workflows;
CREATE TRIGGER workflows_update_timestamp
  BEFORE UPDATE ON workflows
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

-- Attach timestamp updater to policy_bindings table
DROP TRIGGER IF EXISTS policy_bindings_update_timestamp ON policy_bindings;
CREATE TRIGGER policy_bindings_update_timestamp
  BEFORE UPDATE ON policy_bindings
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

COMMIT;
