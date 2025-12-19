# PHASE 6 — Metering, Evidence, and Reporting

**Goal:** Provide enterprise-grade accountability: per-run evidence bundles, audit links, and cost-per-ticket reporting aligned with “capacity units” pricing.

Primary references in the architecture bundle:
- `specs/governance/audit-spine.md`
- `specs/billing/metering.md` (if present) or roadmap notes

## P0 / Critical

- [ ] **LLM usage capture (tokens + latency)**
  - Capture per step:
    - prompt tokens, completion tokens, total tokens
    - provider/model name, region, request id
    - latency + retries
  - DoD:
    - Persisted in metering events (metadata-only safe).

- [ ] **Connector usage capture**
  - Track:
    - reads vs writes
    - webhook ingests
    - rate limit responses + retries
  - DoD:
    - Per-run rollups available for reporting.

- [ ] **Cost model (MVP-accurate enough)**
  - For each provider/model:
    - configurable pricing table per tenant or global
    - compute estimated USD cost per run
  - DoD:
    - “Cost per ticket” report matches token usage and pricing inputs.

- [ ] **Evidence bundle generation + storage**
  - Store bundles in-region (S3) with:
    - retention settings (per tenant)
    - access controls (only authorized roles)
    - link from run details + audit chain pointer
  - DoD:
    - Export/download works for an auditor role without exposing secrets.

- [ ] **Reporting surfaces**
  - Minimum reports:
    - cost per ticket (incident) over time
    - runs by status
    - writes attempted vs allowed vs denied
  - DoD:
    - CSV export available.

## P1 / High

- [ ] **Capacity unit counters**
  - Define:
    - runs/min, concurrency, write caps, retention/indexing tiers
  - DoD:
    - Admin can see current utilization vs purchased limits.

## P2 / Medium

- [ ] **Chargeback tags**
  - Map incidents to cost centers (ServiceNow field or policy mapping).

## P3 / Low

- [ ] **Invoice generation**
  - Likely handled outside product initially.

## Exit gate

- [ ] Every run produces: metering events, a cost estimate, and a retrievable evidence bundle linked into the audit chain, all within the tenant’s pinned region.
