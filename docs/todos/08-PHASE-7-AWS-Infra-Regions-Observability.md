# PHASE 7 — AWS Infrastructure, Regions, and Observability

**Goal:** Deploy a secure multi-tenant SaaS MVP on AWS with **US + EU** region pinning, operational telemetry, and a sane path to production hardening.

Primary references in the architecture bundle:
- `specs/infra/aws-topology.md`
- `specs/infra/regions-and-residency.md`
- `specs/observability/otel.md`

## P0 / Critical

- [ ] **Define AWS deployment target for MVP**
  - Choose and implement (recommended MVP path):
    - ECS Fargate (simpler) or EKS (if required)
    - RDS Postgres (multi-AZ)
    - S3 (evidence bundles)
    - SQS (run/step queue) + DLQ
    - ElastiCache Redis (optional; if needed for locks/caches)
    - ALB + WAF for public endpoints
  - DoD:
    - One Terraform apply brings up a working environment.

- [ ] **Multi-region: US + EU**
  - Separate stacks per region:
    - isolated data plane and storage
    - region-specific DNS entry (or global routing with region pin at app layer)
  - DoD:
    - Tenant pinned to EU cannot create resources in US stack.

- [ ] **Secrets + encryption**
  - Use KMS for:
    - DB encryption
    - Secrets Manager entries (provider keys, connector tokens)
    - Signing policy bundles / audit heads (if chosen)
  - DoD:
    - IAM policies are least-privilege for services.

- [ ] **Observability baseline**
  - Logs: structured, tenant-safe, correlation ids
  - Metrics: run counts, queue depth, error rates, connector failure rates
  - Tracing: at least request-to-run correlation for debugging
  - DoD:
    - On-call can answer: “what broke?” in < 5 minutes using dashboards/logs.

- [ ] **Backups and basic DR**
  - RDS automated backups + restore tested
  - S3 versioning (as appropriate) + lifecycle rules
  - DoD:
    - Documented restore procedure works in staging.

## P1 / High

- [ ] **Staging + production separation**
  - Separate AWS accounts and CI deployment roles.
- [ ] **SLOs + alerting**
  - Pager alerts for sustained run failures, queue backlog, webhook errors.

## P2 / Medium

- [ ] **PrivateLink / customer networking options**
  - Often needed in enterprise; can be v1.

## P3 / Low

- [ ] **Cross-region disaster recovery**
  - Not aligned with “no cross-region replication by default” for residency; plan later.

## Exit gate

- [ ] You can deploy to US and EU stacks, onboard a tenant pinned to either region, run the flagship workflow, retrieve evidence bundles, and observe runs via dashboards/logs without cross-tenant leakage.
