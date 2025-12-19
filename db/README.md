# DB (MVP)

- `schema.sql` is a **schema sketch** aligned with the architecture RFC.
- The authoritative rationale and RLS notes live in `data/db-schema.md`.

## How we use Postgres in MVP

- One Postgres cluster per **cell/region** (US and EU separately).
- Tenant isolation enforced via:
  1) `tenant_id` columns everywhere, and
  2) Postgres **Row-Level Security (RLS)** with fail-closed policies.

## Hash-chained audit

Audit entries are append-only and hash-chained per `(tenant_id, workspace_id)`. External anchoring is deferred to post-MVP.
