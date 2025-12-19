# Database Migrations

This directory contains all database schema migrations for AIC-SOS. Migrations are organized by PHASE and numbered sequentially.

## Overview

**Current Phase:** PHASE-1 (Control Plane)  
**Total Migrations:** 6  
**Database:** PostgreSQL 16+  
**Status:** All migrations are idempotent (safe to rerun)

## Migrations

### 001 - Tenancy (`001_tenancy.sql`)
**Tables:** 4  
**Purpose:** Multi-tenant data isolation foundation  
**Schema:**
- `tenants` — Organization containers (US/EU pinned)
- `workspaces` — Isolated operation environments within tenant
- `environments` — dev/test/prod tiers (optional, future)
- `workspace_config` — Settings, quotas, retention policies

**Key Features:**
- Region immutability (prevents accidental cross-region moves)
- Data persistence mode (metadata-only default for privacy)
- Automatic timestamp tracking (created_at, updated_at)
- Cascading deletes (tenant delete removes all related data)

**Dependencies:** None (runs first)

---

### 002 - Identity (`002_identity.sql`)
**Tables:** 5  
**Purpose:** Multi-tenant identity system with RBAC  
**Schema:**
- `principals` — Users and service identities
- `roles` — RBAC roles (WorkspaceAdmin, Operator, Approver, Auditor, IntegrationAdmin)
- `permissions` — Granular permissions (policy:create, run:delete, etc.)
- `role_bindings` — Map principal → role → workspace
- `api_keys` — Service-to-service authentication (hashed at rest)
- `sessions` — Track JWT/OIDC sessions (for logout, revocation)

**Key Features:**
- Support for both human users (email/OIDC) and service accounts
- OIDC subject claim tracking (oidc_sub for multi-IdP scenarios)
- API key hashing (keys never stored in plaintext)
- Session tracking with revocation support
- Role-based permissions (not attribute-based for MVP)

**Dependencies:** 001_tenancy.sql

---

### 003 - Workflows (`003_workflows.sql`)
**Tables:** 4  
**Purpose:** Immutable versioned workflows and policy bindings  
**Schema:**
- `workflows` — Workflow template definitions
- `workflow_versions` — Immutable, pinned versions (never updated)
- `policies` — Policy definitions (Rego, OPA-based)
- `policy_bindings` — Which policies apply to workflows

**Key Features:**
- Immutable versioning (version_id is unique, cannot be modified)
- Semantic versioning support (1.0.0, 2.1.3, etc.)
- Model pinning (LLM versions locked at publish time)
- Risk tiers (low/medium/high for approval routing)
- Policy binding with priority ordering
- Definition digests for quick comparison

**Dependencies:** 002_identity.sql

---

### 004 - Runtime (`004_runtime.sql`)
**Tables:** 5  
**Purpose:** Track workflow runs, step executions, and approval gates  
**Schema:**
- `runs` — Workflow execution instances
- `steps` — Individual step executions within a run
- `approval_requests` — HITL approval gates
- `approval_decisions` — Approval/rejection decisions
- `tool_calls` — LLM API calls and connector invocations

**Key Features:**
- Run status tracking (queued → running → succeeded/failed)
- Step sequencing and retry counting
- Approval gates with expiration and notification
- Tool call logging for debugging and cost tracking
- Idempotency key support (prevents duplicate runs)
- Timing and error tracking for observability

**Dependencies:** 003_workflows.sql

---

### 005 - Secrets (`005_secrets.sql`)
**Tables:** 4  
**Purpose:** Encrypted storage of BYO LLM keys and connector credentials  
**Schema:**
- `provider_keys` — BYO LLM API keys (OpenAI, Azure, Anthropic)
- `connector_installations` — Per-workspace connector instances
- `secret_rotation_log` — Track secret rotations for audit
- `key_validation_results` — Store validation check results

**Key Features:**
- Encrypted key storage (KMS envelope encryption ready)
- Provider type support (openai, azure_openai, anthropic, cohere, etc.)
- Key validation status tracking (pending/valid/invalid)
- Connector credential storage (encrypted)
- Key rotation logging for audit trail
- Validation result caching (avoid re-validating too frequently)

**Dependencies:** 004_runtime.sql

---

### 006 - Audit & Metering (`006_audit_metering.sql`)
**Tables:** 4  
**Purpose:** Append-only audit logs and usage metering for compliance  
**Schema:**
- `audit_events` — Immutable, append-only audit log with hash chaining
- `metering_events` — Usage tracking (tokens, calls, bytes)
- `usage_summary` — Aggregated usage (hourly/daily/monthly)
- `audit_config` — Per-tenant audit settings and retention

**Key Features:**
- Hash-chained audit events (for tamper detection)
- Action tracking (workflow.created, run.started, key.rotated)
- Resource tracking (what was affected)
- Source tracking (api, ui, scheduled)
- Retention control per event
- Detailed metering (LLM tokens, connector calls, API calls, storage)
- Cost calculation and budget tracking
- Configurable retention periods and export

**Dependencies:** 005_secrets.sql

---

## Migration Numbering

Migrations follow the pattern: `NNN_description.sql`

- `001` - `099`: PHASE-0 (repository foundation)
- `100` - `199`: PHASE-1 (control plane)
- `200` - `299`: PHASE-2 (execution plane)
- `300+`: Future phases

## Running Migrations

### Local Development

```bash
# Start dev environment with migrations
make dev

# Check migration status
psql -h localhost -U postgres -d aic_sos_dev -c "\dt"

# Run specific migration
psql -h localhost -U postgres -d aic_sos_dev < db/migrations/001_tenancy.sql

# Clear and reload all migrations
make dev-reset && make dev
```

### Production Deployment

```bash
# Validate migrations before applying
./scripts/validate-migrations.sh

# Apply migrations (should be done during deployment)
./scripts/run-migrations.sh prod

# Verify migration status
psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "\dt"
```

## Migration Design Principles

### 1. Idempotent
All migrations use `IF NOT EXISTS` and `DROP IF EXISTS`, making them safe to rerun without errors.

### 2. Transactional
Each migration wrapped in `BEGIN; ... COMMIT;` to ensure all-or-nothing semantics.

### 3. Backwards Compatible
Migrations add new tables/columns, never remove (until major version).

### 4. Documented
Each migration has:
- Clear purpose statement
- Date created
- List of tables/changes
- Comments on design decisions

### 5. Sequenced by Dependency
Later migrations reference earlier migrations via foreign keys, ensuring proper order.

## Key Design Decisions

### Multi-Tenancy
- All tables have `tenant_id` foreign key (except global tables like `permissions`)
- `workspace_id` for workspace-scoped tables
- Isolate queries by `tenant_id` in app logic (MVP) or PostgreSQL RLS (future)

### Immutability
- `workflow_versions` are immutable (publish once, never update)
- `audit_events` are append-only (cannot update or delete)
- `policies` are versioned (new version = new row)

### Encryption at Rest
- `provider_keys.encrypted_key` stored encrypted
- `connector_installations.encrypted_config` stored encrypted
- Decrypt only when needed (performance)
- KMS key ID tracked for key rotation

### Audit Trail
- `audit_events` hash-chained (previous_event_id) for tamper detection
- All CREATE/UPDATE/DELETE actions logged
- Actor (who), action (what), resource (where) tracked
- Source (api/ui/scheduled) tracked

### Performance
- Indexes on common filters (tenant_id, workspace_id, status, created_at)
- Separate summary tables for aggregates (usage_summary)
- Pagination-friendly sorting (created_at DESC, limit N)

## Future Enhancements

### PHASE-2+
- [ ] Partitioning by tenant_id for horizontal scaling
- [ ] Read replicas for audit queries (separate data warehouse)
- [ ] PostgreSQL RLS policies for multi-tenancy (defense in depth)
- [ ] Columnar storage for metering_events (efficient analytics)

### PHASE-3+
- [ ] Event streaming (Kafka/Pulsar) from audit_events
- [ ] Incremental backups for disaster recovery
- [ ] Database sharding by region

## Troubleshooting

### Migration Fails
1. Check PostgreSQL version: `psql --version` (need 15+)
2. Check logs: `make dev-logs` (search for migration errors)
3. Verify connectivity: `psql -h localhost -U postgres`
4. Run specific migration: `psql < db/migrations/001_tenancy.sql`

### Constraint Violations
1. Check foreign key references: `SELECT * FROM information_schema.referential_constraints`
2. Verify cascade rules: `DELETE FROM tenants` should cascade to workspaces

### Performance Issues
1. Analyze index usage: `SELECT * FROM pg_stat_user_indexes`
2. Check query plans: `EXPLAIN ANALYZE SELECT * FROM runs WHERE status='running'`

## References

- PostgreSQL 16 Documentation: https://www.postgresql.org/docs/16/
- UUID Best Practices: https://wiki.postgresql.org/wiki/UUID
- Foreign Keys: https://www.postgresql.org/docs/16/ddl-constraints.html
- Row-Level Security: https://www.postgresql.org/docs/16/ddl-rowsecurity.html

---

**Last Updated:** December 19, 2024  
**Status:** ✅ All 6 PHASE-1 migrations ready
