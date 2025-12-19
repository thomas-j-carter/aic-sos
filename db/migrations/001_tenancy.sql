-- Migration 001: Tenancy - Organizations and Workspaces
-- Purpose: Establish multi-tenant isolation foundation
-- Status: Idempotent (safe to rerun)
-- Created: 2024-12-19

BEGIN;

-- Tenants: Top-level organization container
CREATE TABLE IF NOT EXISTS tenants (
  tenant_id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  region TEXT NOT NULL CHECK (region IN ('us-east-1', 'eu-west-1')),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tenants_region_idx ON tenants(region);
CREATE INDEX IF NOT EXISTS tenants_created_at_idx ON tenants(created_at);

-- Workspaces: Isolated operation environments within a tenant
CREATE TABLE IF NOT EXISTS workspaces (
  workspace_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  region TEXT NOT NULL CHECK (region IN ('us-east-1', 'eu-west-1')),
  -- Data persistence mode: 'metadata_only' (default, privacy-first) or 'full' (store all content)
  data_persistence_mode TEXT NOT NULL DEFAULT 'metadata_only' CHECK (data_persistence_mode IN ('metadata_only', 'full')),
  -- Immutable after creation - prevents accidental cross-region moves
  region_locked BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, name)
);

CREATE INDEX IF NOT EXISTS workspaces_tenant_idx ON workspaces(tenant_id);
CREATE INDEX IF NOT EXISTS workspaces_region_idx ON workspaces(region);
CREATE INDEX IF NOT EXISTS workspaces_created_at_idx ON workspaces(created_at);

-- Environments: Development/Test/Production tiers (future)
CREATE TABLE IF NOT EXISTS environments (
  environment_id UUID PRIMARY KEY,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  tier TEXT NOT NULL CHECK (tier IN ('dev', 'test', 'prod')),
  description TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workspace_id, name)
);

CREATE INDEX IF NOT EXISTS environments_workspace_idx ON environments(workspace_id);
CREATE INDEX IF NOT EXISTS environments_tenant_idx ON environments(tenant_id);

-- Workspace Configuration
-- Stores tenant-specific settings, quotas, retention policies
CREATE TABLE IF NOT EXISTS workspace_config (
  config_id UUID PRIMARY KEY,
  workspace_id UUID NOT NULL UNIQUE REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- Data retention: how long to keep evidence/metadata (days)
  retention_days INT DEFAULT 90,
  -- Write caps: max API calls per minute per workspace (rate limiting)
  write_cap_per_minute INT DEFAULT 1000,
  -- Approval tiers: which roles can approve which risk levels (future)
  approval_tiers JSONB DEFAULT '{}'::jsonb,
  -- Custom settings (extensible)
  custom_settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS workspace_config_workspace_idx ON workspace_config(workspace_id);
CREATE INDEX IF NOT EXISTS workspace_config_tenant_idx ON workspace_config(tenant_id);

-- Audit table updater function
-- Automatically updates updated_at timestamp on record modification
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach timestamp updater to tenants table
DROP TRIGGER IF EXISTS tenants_update_timestamp ON tenants;
CREATE TRIGGER tenants_update_timestamp
  BEFORE UPDATE ON tenants
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

-- Attach timestamp updater to workspaces table
DROP TRIGGER IF EXISTS workspaces_update_timestamp ON workspaces;
CREATE TRIGGER workspaces_update_timestamp
  BEFORE UPDATE ON workspaces
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

-- Attach timestamp updater to environments table
DROP TRIGGER IF EXISTS environments_update_timestamp ON environments;
CREATE TRIGGER environments_update_timestamp
  BEFORE UPDATE ON environments
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

-- Attach timestamp updater to workspace_config table
DROP TRIGGER IF EXISTS workspace_config_update_timestamp ON workspace_config;
CREATE TRIGGER workspace_config_update_timestamp
  BEFORE UPDATE ON workspace_config
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

COMMIT;
