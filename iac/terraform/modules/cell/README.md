# module: cell

Provisions a single AWS regional “cell”.

## Inputs (high level)
- `region`, `cell_name`
- network: `vpc_cidr`, `public_subnet_cidrs`, `private_subnet_cidrs`
- images: `api_image`, `orchestrator_image`, `connector_gateway_image`, `approval_image`
- sizing: `desired_count_*`
- db: `db_instance_class`, `db_allocated_storage_gb`

## Outputs
- `alb_dns_name`
- `db_endpoint`
- `queue_urls`

## TODOs for production hardening
- multi-AZ RDS, read replicas (if/when allowed per region policy)
- WAF + rate limiting for webhook endpoints
- private connectivity options (PrivateLink) for enterprise tenants
- secrets management for BYO keys (KMS + tenant-scoped envelope encryption)
