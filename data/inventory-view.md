
# Tenant-facing Data Inventory view (MVP spec)

A tenant-scoped page that answers: **what data do you store, where, for how long, and why**.

## Required sections
1. **Data categories stored**
   - governance evidence (audit logs, approval artifacts)
   - runtime operational telemetry (traces/logs; minimized)
   - connector configuration metadata (CredentialRef only)
   - workflow definitions (YAML)
   - metering data

2. **For each category show**
   - residency region (US/EU pinned)
   - storage location class (Postgres / S3)
   - retention (default + tenant override)
   - access roles allowed (RBAC)
   - export surfaces (webhook/S3 pull)
   - deletion workflow and timestamps

3. **Content persistence**
   - explicitly OFF by default in MVP
   - show toggles as disabled with explanation (ships v1/v2)

## Non-goals
- Not a full data catalog / MDM.
