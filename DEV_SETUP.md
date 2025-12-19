# Local Development Setup Guide

**Phase 0 Critical Deliverable:** Single-command local developer environment

**Status:** Complete | **Date:** 2025-12-18 | **Version:** 0.1.0

---

## Overview

The development environment provides:

✓ **Infrastructure containers** (Postgres, Redis, MinIO)  
✓ **Single-command startup** (`make dev`)  
✓ **Health checks & smoke tests** (`smoke-test.sh`)  
✓ **Service orchestration** (docker-compose with healthchecks)  
✓ **Comprehensive documentation** (START-HERE.md, this guide)  

**Definition of Done:**
- [x] Fresh clone → `make dev` → all services up
- [x] `./smoke-test.sh` passes
- [x] New engineer can start coding in < 5 min

---

## Files Delivered

### Core Files

1. **`Makefile`** (updated)
   - `make dev` — Full environment setup
   - `make dev-up`, `make dev-down`, `make dev-status`
   - `make smoke-test` — Verify health

2. **`docker-compose.yaml`** (enhanced)
   - PostgreSQL 16 (with healthcheck, volume persistence)
   - Redis 7 (with healthcheck)
   - MinIO (S3-compatible storage, console UI)
   - Named volumes & shared network

3. **`smoke-test.sh`** (executable script)
   - 9 comprehensive health checks
   - Infrastructure validation (Docker, Postgres, Redis, MinIO)
   - Build verification (make build)
   - Repository checks (git, VERSION file)
   - Color-coded output, verbose mode available

4. **`.env.example`** (configuration template)
   - Database credentials (default: postgres/postgres)
   - Redis URL (default: localhost:6379)
   - MinIO credentials (default: minio/minio123)
   - S3 endpoint configuration
   - Optional: LLM keys, Slack tokens, ServiceNow config

5. **`docs/START-HERE.md`** (comprehensive guide)
   - Quick start (TL;DR)
   - Detailed setup instructions
   - Prerequisites & installation
   - Troubleshooting FAQ
   - Next steps for feature development

### Updated Files

- **`Makefile`** — Added 12 dev-related targets
- **`docs/START-HERE.md`** — Replaced with comprehensive guide
- **`docker-compose.yaml`** — Enhanced with healthchecks, volumes, networks

---

## Quick Start

```bash
# 1. Single command to start everything
make dev

# 2. Verify it works
./smoke-test.sh

# 3. Start coding
# See docs/START-HERE.md for next steps
```

---

## Architecture

### Container Network

All containers run on a shared `platform` bridge network:

```
┌─────────────────────────────────────┐
│    Docker Network (platform)         │
├─────────────────────────────────────┤
│  ┌──────────────┐                   │
│  │ PostgreSQL   │ 5432              │
│  │ (postgres_data vol)              │
│  └──────────────┘                   │
│  ┌──────────────┐                   │
│  │ Redis        │ 6379              │
│  └──────────────┘                   │
│  ┌──────────────┐                   │
│  │ MinIO        │ 9000 (API)        │
│  │ (minio_data vol) 9001 (Console)  │
│  └──────────────┘                   │
└─────────────────────────────────────┘
```

### Service Health Checks

Each container has a healthcheck:

| Service | Check | Interval | Timeout | Retries |
|---------|-------|----------|---------|---------|
| PostgreSQL | `pg_isready` | 10s | 5s | 5 |
| Redis | `redis-cli ping` | 10s | 5s | 5 |
| MinIO | HTTP `/minio/health/live` | 10s | 5s | 5 |

Containers auto-restart on failure.

---

## Command Reference

### Quick Commands

```bash
# Start everything and verify
make dev

# Check service health
make dev-status

# View logs
make dev-logs
make dev-logs SERVICE=postgres

# Stop all services
make dev-down

# Complete reset (remove volumes)
make dev-reset

# Run smoke tests
make smoke-test

# Show help
make help
```

### Advanced Commands

```bash
# Start containers only (skip build + smoke test)
make dev-up

# Build services after code changes
make build

# Check version
make version

# Bump version
make version-bump-minor

# Create release tag
make version-tag
```

---

## Service Details

### PostgreSQL

**Purpose:** Multi-tenant relational database with Row-Level Security

```bash
# Connect:
psql -h localhost -U postgres -d app

# Or via docker:
docker-compose exec postgres psql -U postgres

# Default credentials:
# User: postgres
# Password: postgres
# Database: app
# Port: 5432

# Init script:
# db/schema.sql is auto-loaded on container creation
```

**Features:**
- Alpine Linux base (lightweight)
- Named volume `postgres_data` (persists between restarts)
- Healthcheck via `pg_isready`
- Multi-tenant schema with RLS (Row-Level Security)

### Redis

**Purpose:** Cache & queue layer for Run/Step execution

```bash
# Connect:
redis-cli -h localhost -p 6379

# Or via docker:
docker-compose exec redis redis-cli

# Useful commands:
redis-cli KEYS "*"        # List all keys
redis-cli FLUSHDB         # Clear database
redis-cli MONITOR         # Watch live commands
```

**Features:**
- Alpine Linux base (lightweight)
- In-memory data structure store
- Used for: session cache, rate limits, queue (MVP)
- Healthcheck via `redis-cli ping`

### MinIO

**Purpose:** S3-compatible object storage (for evidence bundles, backups)

```bash
# S3 API:
aws --endpoint-url http://localhost:9000 s3 ls

# Web Console:
# http://localhost:9001
# User: minio
# Password: minio123

# Create bucket (evidence-bundles):
docker-compose exec minio mc alias set local http://localhost:9000 minio minio123
docker-compose exec minio mc mb local/evidence-bundles
```

**Features:**
- Named volume `minio_data` (persists data)
- S3-compatible API on port 9000
- Web console on port 9001
- Healthcheck via HTTP health endpoint

---

## Troubleshooting

### "Docker daemon not running"

**Error:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

**Fix:**
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker

# Windows
# Open Docker Desktop app
```

### "Port already in use"

**Error:**
```
Error response from daemon: driver failed programming external connectivity on endpoint platform-postgres: Bind for 0.0.0.0:5432 failed
```

**Fix:**
```bash
# Option 1: Find and stop conflicting process
lsof -i :5432
kill -9 <PID>

# Option 2: Remove docker containers and reset
make dev-reset
make dev
```

### "Build fails: go: command not found"

**Error:**
```
/bin/sh: go: command not found
```

**Fix:**
```bash
# Install Go 1.21+
go version
# If not found:
# macOS: brew install go@1.21
# Linux: https://golang.org/dl/
# Windows: https://golang.org/dl/
```

### "Build fails: error: linker 'cc' not found"

**Error:**
```
# /usr/local/go/src/runtime/cgo
collect2: fatal error: ld returned 1 exit status
```

**Fix:**
```bash
# Install C compiler (required for CGO packages)
# macOS
xcode-select --install

# Linux (Ubuntu)
sudo apt-get update
sudo apt-get install build-essential

# Linux (CentOS)
sudo yum groupinstall "Development Tools"
```

### "Smoke test fails: PostgreSQL not ready"

**Error:**
```
[2] PostgreSQL (port 5432)... ✗
  Reason: PostgreSQL not responding on localhost:5432
```

**Fix:**
```bash
# Services need time to become healthy
make dev-reset
make dev-up
sleep 15  # Wait for services to initialize
./smoke-test.sh
```

### "Services keep restarting"

**Error:**
```
docker-compose ps
# STATUS: Restarting (1) 2s ago
```

**Fix:**
```bash
# Check logs:
docker-compose logs postgres  # (replace with service name)

# Common reasons:
# 1. Port already in use: make dev-reset && make dev
# 2. Corrupted volume: docker volume rm <volume_name> && make dev
# 3. Insufficient resources: Check Docker memory allocation

# Reset everything:
make dev-reset
make dev
```

### "make command not found"

**Error:**
```
make: command not found
```

**Fix:**
```bash
# Install make
# macOS
brew install make

# Linux
sudo apt-get install make

# Windows (via WSL or MinGW):
# Use WSL: same as Linux
# Or MinGW: https://www.mingw-w64.org/
```

---

## Environment Configuration

### Default Configuration

Out-of-the-box, the dev environment uses sensible defaults:

```yaml
# docker-compose.yaml
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
POSTGRES_DB: app
MINIO_ROOT_USER: minio
MINIO_ROOT_PASSWORD: minio123
```

### Custom Configuration

**Option 1: Environment Variables (temporary)**

```bash
# Export before running make dev
export POSTGRES_PASSWORD=mypassword
export LOG_LEVEL=debug
make dev
```

**Option 2: .env File (persistent)**

```bash
# Copy template
cp .env.example .env

# Edit
nano .env

# Use it
make dev  # Reads .env automatically
```

**Useful .env overrides:**

```env
# Logging
LOG_LEVEL=debug

# LLM Keys (for testing)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# Slack (for HITL approval testing)
SLACK_BOT_TOKEN=xoxb-...
SLACK_SIGNING_SECRET=...

# ServiceNow (for connector testing)
SERVICENOW_INSTANCE_URL=https://company.service-now.com
SERVICENOW_API_KEY=...

# GitHub (for connector testing)
GITHUB_TOKEN=ghp_...

# MinIO / S3
S3_BUCKET=evidence-bundles
S3_REGION=us-east-1
```

---

## Volume Persistence

Containers use named volumes to persist data across restarts:

```bash
# View volumes
docker volume ls

# Inspect a volume
docker volume inspect <volume_name>

# Remove a volume (careful!)
docker volume rm platform_postgres_data

# Reset all volumes
make dev-reset  # Removes all volumes
```

**Volumes:**
- `postgres_data` — PostgreSQL data
- `minio_data` — MinIO object storage

---

## Container Logs

### Real-time Logs

```bash
# All containers
make dev-logs

# Specific container
make dev-logs SERVICE=postgres
make dev-logs SERVICE=redis
make dev-logs SERVICE=minio

# Follow logs (tail mode)
docker-compose logs -f [service]

# Last 100 lines
docker-compose logs -n 100 [service]
```

### Inspect Container

```bash
# Get container ID
docker-compose ps

# Inspect container
docker inspect <container_id>

# Execute command in container
docker-compose exec postgres psql -U postgres

# Shell into container
docker-compose exec postgres /bin/sh
```

---

## Smoke Test Details

The `smoke-test.sh` script runs 9 checks:

**Infrastructure (4 checks)**
1. Docker Compose services running (count >= 3)
2. PostgreSQL responds to `pg_isready`
3. Redis responds to `redis-cli ping`
4. MinIO responds to health endpoint

**Build & Repository (3 checks)**
5. Git repository exists
6. VERSION file is valid (SemVer format)
7. Services compile successfully (`make build`)

**Documentation (1 check)**
8. START-HERE.md exists

**Extras (1 check)**
9. Ports available (5432, 6379, 9000, 9001)

### Running Smoke Tests

```bash
# Basic run
./smoke-test.sh

# Verbose output (debugging)
./smoke-test.sh --verbose

# Exit codes
# 0 = all passed
# 1 = one or more failed
```

### Example Output

```
========================================
Smoke Tests - Local Development Environment
========================================


========================================
Infrastructure Health
========================================

[1] Docker Compose services running... ✓
[2] PostgreSQL (port 5432)... ✓
[3] Redis (port 6379)... ✓
[4] MinIO (port 9000)... ✓
[5] Required ports available... ✓

========================================
Build & Repository
========================================

[6] Git repository... ✓
[7] VERSION file... ✓
[8] Services compile (make build)... ✓

========================================
Documentation
========================================

[9] Documentation (START-HERE.md)... ✓

========================================
Tests run: 9 | Passed: 9 | Failed: 0
========================================
✓ All smoke tests passed!
```

---

## Next Steps

After `make dev` succeeds:

1. **Read architecture:** `docs/RFC-0001-architecture.md`
2. **Understand service boundaries:** `service-boundaries.md`
3. **Pick a feature:** `roadmap/mvp-v1-v2.md`
4. **Start coding:** Use `.github/copilot-instructions.md` for patterns
5. **Version management:** `VERSIONING-QUICKSTART.md`
6. **Release prep:** `RELEASE-CHECKLIST.md`

---

## FAQ

**Q: Can I run services outside Docker for hot-reload development?**  
A: Not in Phase 0. Phase 1 will add local service runners. For now, edit code and `make build` to recompile.

**Q: How do I access the database from my code?**  
A: Use connection string: `postgresql://postgres:postgres@localhost:5432/app`  
Or see `data/db-schema.md` for RLS + multi-tenancy details.

**Q: Can I use a different database (MySQL, SQLite)?**  
A: No in MVP. Architecture requires Postgres RLS for multi-tenant isolation. Phase 1+ can evaluate alternatives.

**Q: How do I seed demo data?**  
A: Phase 1 feature (`make demo-seed`). For now, manually insert test records via `psql` if needed.

**Q: Can I run multiple docker-compose stacks?**  
A: Not recommended (port conflicts). Use `make dev-reset` to cleanly switch projects.

**Q: What if I accidentally delete the volumes?**  
A: No problem! `make dev` will recreate them. You lose any test data, but that's normal for dev.

---

## Maintenance

### Updating Containers

```bash
# Pull latest images
docker-compose pull

# Restart with new images
make dev-reset
make dev
```

### Cleaning Up

```bash
# Stop containers without removing
make dev-down

# Remove containers and volumes
make dev-reset

# Prune all Docker resources (careful!)
docker system prune -a --volumes
```

### Monitoring

```bash
# Real-time stats
docker stats

# Check resource usage
docker system df
```

---

## References

- **Docker Compose:** https://docs.docker.com/compose/
- **PostgreSQL:** https://www.postgresql.org/docs/16/
- **Redis:** https://redis.io/docs/
- **MinIO:** https://min.io/docs/minio/linux/
- **Local Development Workflow:** `docs/START-HERE.md`
- **Version Management:** `VERSIONING-QUICKSTART.md`

---

**Last Updated:** 2025-12-18  
**Status:** Phase 0 Complete  
**Next Phase:** CI/CD Pipeline (GitHub Actions for Go, Rust, TS)
