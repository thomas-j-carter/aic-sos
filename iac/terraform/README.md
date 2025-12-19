# Terraform (AWS cell template)

This directory is a **starter skeleton** for provisioning a regional “cell” (US or EU) that runs the platform services.

Design goals (MVP):
- AWS-first
- US + EU region pinning (separate cells)
- multi-tenant runtime with strict isolation (tenant_id + policy + RLS)
- outbound-only customer agent support (no inbound firewall changes for customers)
- fail-closed policy and audit integrity (hash-chained audit in Postgres)

> This is intentionally minimal: it shows the structure, boundaries, and key resources.
> Fill in the TODOs as you harden networking, auth, and HA.

## Layout

- `modules/cell/` — provision a single region cell
- `examples/us/` — example instantiation for a US region
- `examples/eu/` — example instantiation for an EU region

## What a “cell” typically contains

- VPC + subnets (public for ALB, private for services/DB)
- ECS/Fargate services:
  - API gateway/service
  - Orchestrator (Go daemon)
  - Connector gateway (webhooks + outbound calls)
  - Approval/HITL service (Slack)
- RDS Postgres (with RLS enabled at schema level)
- SQS queues for run/step dispatch and delayed retries
- KMS keys + IAM roles
- CloudWatch logs/alarms

## Outbound-only customer agent

The customer agent should connect out to the platform over TLS (e.g. HTTPS/WebSocket) and/or poll a queue endpoint.
The cell provisions the public endpoints and queues needed for that pattern.
