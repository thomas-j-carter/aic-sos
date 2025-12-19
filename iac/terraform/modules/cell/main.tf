provider "aws" {
  region = var.region
}

# --- Networking (skeleton) ---
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.cell_name}-vpc" }
}

# TODO: create public/private subnets, IGW/NAT, route tables.
# In MVP, keep services in private subnets; ALB in public subnets.

# --- Queues ---
resource "aws_sqs_queue" "run_queue" {
  name                      = "${var.cell_name}-run-queue"
  visibility_timeout_seconds = 60
}

resource "aws_sqs_queue" "step_queue" {
  name                      = "${var.cell_name}-step-queue"
  visibility_timeout_seconds = 60
}

resource "aws_sqs_queue" "retry_queue" {
  name                      = "${var.cell_name}-retry-queue"
  visibility_timeout_seconds = 60
}

# --- KMS (for envelope encryption / BYO keys metadata) ---
resource "aws_kms_key" "cell" {
  description             = "KMS key for ${var.cell_name} cell"
  deletion_window_in_days = 30
}

# --- RDS Postgres (skeleton) ---
resource "aws_db_subnet_group" "this" {
  name       = "${var.cell_name}-db-subnets"
  subnet_ids = [] # TODO: private subnet ids
}

resource "aws_security_group" "db" {
  name        = "${var.cell_name}-db-sg"
  description = "DB access for ${var.cell_name}"
  vpc_id      = aws_vpc.this.id

  # TODO: allow from service SGs only
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.cell_name}-pg"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage_gb
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  username = "app"          # TODO: move to Secrets Manager
  password = "change-me"    # TODO: move to Secrets Manager
  skip_final_snapshot = true

  # TODO: multi_az, backups, performance insights
}

# --- Compute (ECS/Fargate skeleton) ---
# TODO: define ECS cluster, task definitions, services (api/orchestrator/connector/approval),
# IAM task roles, ALB + listeners (webhook ingress + UI/API ingress), CloudWatch logs.

