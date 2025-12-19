-- Migration 002: Identity - Users, Roles, Permissions, API Keys
-- Purpose: Multi-tenant identity system with RBAC
-- Status: Idempotent (safe to rerun)
-- Created: 2024-12-19

BEGIN;

-- Principals: Users and service identities
-- Supports both human users (email) and service accounts
CREATE TABLE IF NOT EXISTS principals (
  principal_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('human', 'service')),
  -- For humans: email used for OIDC login
  email TEXT,
  -- For services: unique name (e.g., 'workflow-executor', 'connector-bot')
  service_name TEXT,
  display_name TEXT,
  -- OIDC subject claim (if human user) - unique per IdP
  oidc_sub TEXT,
  -- Track when principal was provisioned and last active
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, email),
  UNIQUE (tenant_id, service_name),
  UNIQUE (tenant_id, oidc_sub)
);

CREATE INDEX IF NOT EXISTS principals_tenant_idx ON principals(tenant_id);
CREATE INDEX IF NOT EXISTS principals_type_idx ON principals(type);
CREATE INDEX IF NOT EXISTS principals_email_idx ON principals(email);
CREATE INDEX IF NOT EXISTS principals_service_name_idx ON principals(service_name);

-- Roles: RBAC roles for workspaces
-- Standard roles: WorkspaceAdmin, Operator, Approver, Auditor, IntegrationAdmin
CREATE TABLE IF NOT EXISTS roles (
  role_id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (name IN (
    'workspace_admin', 'operator', 'approver', 'auditor', 'integration_admin'
  )),
  -- Custom description
  description TEXT,
  -- Immutable: standard roles cannot be modified (future: custom roles)
  is_builtin BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workspace_id, name)
);

CREATE INDEX IF NOT EXISTS roles_workspace_idx ON roles(workspace_id);
CREATE INDEX IF NOT EXISTS roles_tenant_idx ON roles(tenant_id);

-- Permissions: Granular permissions (e.g., 'policy:create', 'run:delete')
-- Assigned to roles, not directly to users
CREATE TABLE IF NOT EXISTS permissions (
  permission_id UUID PRIMARY KEY,
  -- Global (not tenant-specific) - defined once, reused across all tenants
  resource TEXT NOT NULL,
  action TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (resource, action)
);

-- Common permissions: insert as needed during app startup or migration
-- Examples: 'policy:create', 'run:delete', 'connector:install', 'audit:view'
-- Not creating rows here as they're typically seeded by app logic

-- Role Bindings: Map principal → role → workspace
CREATE TABLE IF NOT EXISTS role_bindings (
  role_binding_id UUID PRIMARY KEY,
  principal_id UUID NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- When was this assignment made (audit)
  created_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (principal_id, workspace_id, role_id)
);

CREATE INDEX IF NOT EXISTS role_bindings_principal_idx ON role_bindings(principal_id);
CREATE INDEX IF NOT EXISTS role_bindings_role_idx ON role_bindings(role_id);
CREATE INDEX IF NOT EXISTS role_bindings_workspace_idx ON role_bindings(workspace_id);
CREATE INDEX IF NOT EXISTS role_bindings_tenant_idx ON role_bindings(tenant_id);

-- API Keys: Service-to-service authentication
-- Keys are hashed at rest (never stored in plaintext)
CREATE TABLE IF NOT EXISTS api_keys (
  api_key_id UUID PRIMARY KEY,
  principal_id UUID NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
  -- SHA256 hash of the actual key (salted)
  key_hash TEXT NOT NULL UNIQUE,
  -- Key name for identification (e.g., 'Deployment Bot', 'Integration Test')
  name TEXT NOT NULL,
  -- Last 4 chars of actual key (for user reference, not security)
  key_preview TEXT NOT NULL,
  -- Track rotation for key lifecycle management
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  rotated_at TIMESTAMPTZ,
  -- Expiration (optional, can be null for no expiry)
  expires_at TIMESTAMPTZ,
  -- For audit: who created this key
  created_by UUID REFERENCES principals(principal_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS api_keys_principal_idx ON api_keys(principal_id);
CREATE INDEX IF NOT EXISTS api_keys_tenant_idx ON api_keys(tenant_id);
CREATE INDEX IF NOT EXISTS api_keys_workspace_idx ON api_keys(workspace_id);
CREATE INDEX IF NOT EXISTS api_keys_key_hash_idx ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS api_keys_is_active_idx ON api_keys(is_active);

-- Sessions: Track OIDC/JWT sessions (optional, for logout tracking)
CREATE TABLE IF NOT EXISTS sessions (
  session_id UUID PRIMARY KEY,
  principal_id UUID NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  -- JWT subject claim
  jwt_sub TEXT NOT NULL,
  -- JWT issued at (iat)
  issued_at TIMESTAMPTZ NOT NULL,
  -- JWT expires at (exp)
  expires_at TIMESTAMPTZ NOT NULL,
  -- Client IP for audit
  client_ip TEXT,
  -- User agent for device tracking
  user_agent TEXT,
  -- Revocation: can be manually invalidated
  is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS sessions_principal_idx ON sessions(principal_id);
CREATE INDEX IF NOT EXISTS sessions_tenant_idx ON sessions(tenant_id);
CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS sessions_is_revoked_idx ON sessions(is_revoked);

-- Attach timestamp updater to principals table
DROP TRIGGER IF EXISTS principals_update_timestamp ON principals;
CREATE TRIGGER principals_update_timestamp
  BEFORE UPDATE ON principals
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

-- Attach timestamp updater to api_keys table
DROP TRIGGER IF EXISTS api_keys_update_timestamp ON api_keys;
CREATE TRIGGER api_keys_update_timestamp
  BEFORE UPDATE ON api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

COMMIT;
