
# AWS cell template (Terraform outline)

## Per-region
- VPC + subnets (multi-AZ)
- EKS cluster (or ECS) for services/workers
- RDS Postgres (multi-AZ)
- S3 buckets (artifacts, evidence bundles, export)
- SQS queues + DLQs
- ElastiCache Redis (optional for rate limits/caching)
- KMS keys (per tenant envelopes; per cell root)
- Secrets Manager
- ALB/Ingress + WAF
- OTel collector pipeline
- IAM roles for service identities

## Cell-based isolation
- tenants assigned to a cell; each cell has:
  - separate DB schema/keyspace partitioning
  - separate queues
  - separate encryption roots
  - per-cell quotas and cost alarms
