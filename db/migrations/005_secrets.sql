-- Migration 005: Secrets - Provider Keys, Connector Credentials
-- Purpose: Encrypted storage of BYO LLM keys and connector credentials
-- Status: Idempotent (safe to rerun)
-- Created: 2024-12-19

BEGIN;

-- Provider Keys: BYO LLM API keys (OpenAI, Azure, Anthropic, etc.)
-- Stored encrypted at rest
CREATE TABLE IF NOT EXISTS provider_keys (
  provider_key_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Provider type: 'openai', 'azure_openai', 'anthropic', 'cohere', etc.
  provider_type TEXT NOT NULL,
  -- Key name for reference (e.g., 'Production OpenAI', 'Dev Anthropic')
  name TEXT NOT NULL,
  -- Encrypted key value (never stored in plaintext)
  encrypted_key TEXT NOT NULL,
  -- KMS key ID used for encryption (for key rotation)
  kms_key_id TEXT,
  -- Whether this is the active key for this provider type
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  -- Last used time (for cleanup)
  last_used_at TIMESTAMPTZ,
  -- Validation status: 'pending', 'valid', 'invalid'
  validation_status TEXT DEFAULT 'pending' CHECK (validation_status IN ('pending', 'valid', 'invalid')),
  validation_error TEXT,
  validation_timestamp TIMESTAMPTZ,
  -- Who added this key
  created_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rotated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS provider_keys_tenant_idx ON provider_keys(tenant_id);
CREATE INDEX IF NOT EXISTS provider_keys_workspace_idx ON provider_keys(workspace_id);
CREATE INDEX IF NOT EXISTS provider_keys_provider_type_idx ON provider_keys(provider_type);
CREATE INDEX IF NOT EXISTS provider_keys_is_active_idx ON provider_keys(is_active);

-- Connector Installations: Per-workspace connector instances
CREATE TABLE IF NOT EXISTS connector_installations (
  connector_installation_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- Connector type (e.g., 'slack', 'servicenow', 'github')
  connector_type TEXT NOT NULL,
  -- Connector version
  connector_version TEXT NOT NULL,
  -- Display name
  display_name TEXT,
  -- Configuration/credentials stored as encrypted JSON
  encrypted_config TEXT NOT NULL,
  kms_key_id TEXT,
  -- Is this installation active/enabled?
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  -- Validation
  validation_status TEXT DEFAULT 'pending' CHECK (validation_status IN ('pending', 'valid', 'invalid')),
  validation_error TEXT,
  validation_timestamp TIMESTAMPTZ,
  -- Who installed this
  installed_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS connector_installations_tenant_idx ON connector_installations(tenant_id);
CREATE INDEX IF NOT EXISTS connector_installations_workspace_idx ON connector_installations(workspace_id);
CREATE INDEX IF NOT EXISTS connector_installations_connector_type_idx ON connector_installations(connector_type);
CREATE INDEX IF NOT EXISTS connector_installations_is_enabled_idx ON connector_installations(is_enabled);

-- Secret Rotation Log: Track secret rotations for audit
CREATE TABLE IF NOT EXISTS secret_rotation_log (
  rotation_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- Type of secret being rotated
  secret_type TEXT NOT NULL CHECK (secret_type IN ('provider_key', 'connector_credential', 'api_key')),
  -- ID of the secret being rotated
  secret_id UUID NOT NULL,
  -- Old KMS key ID (before rotation)
  old_kms_key_id TEXT,
  -- New KMS key ID (after rotation)
  new_kms_key_id TEXT,
  -- Who performed the rotation
  rotated_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  rotation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS secret_rotation_log_tenant_idx ON secret_rotation_log(tenant_id);
CREATE INDEX IF NOT EXISTS secret_rotation_log_secret_id_idx ON secret_rotation_log(secret_id);

-- Key Validation Results: Store results of key validation checks
-- (helps avoid re-validating keys too frequently)
CREATE TABLE IF NOT EXISTS key_validation_results (
  validation_result_id UUID PRIMARY KEY,
  provider_key_id UUID NOT NULL REFERENCES provider_keys(provider_key_id) ON DELETE CASCADE,
  -- Validation test: 'syntax', 'call_test', 'quota_check'
  validation_test TEXT NOT NULL,
  -- Result: 'pass', 'fail', 'error'
  result TEXT NOT NULL,
  result_details JSONB,
  validated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS key_validation_results_provider_key_idx ON key_validation_results(provider_key_id);

-- Attach timestamp updater
DROP TRIGGER IF EXISTS connector_installations_update_timestamp ON connector_installations;
CREATE TRIGGER connector_installations_update_timestamp
  BEFORE UPDATE ON connector_installations
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

COMMIT;
