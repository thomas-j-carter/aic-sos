# Start Here

**Welcome!** This guide gets you from a fresh clone to a running local development environment in ~5 minutes.

---

## Quick Start (TL;DR)

```bash
# 1. Start infrastructure (Postgres, Redis, MinIO) and build services
make dev

# 2. Verify everything works
./smoke-test.sh

# 3. Read the architecture
cat docs/RFC-0001-architecture.md
```

Done! Your development environment is ready. Next step: implement the ServiceNow→Slack→ServiceNow vertical slice.

---

## Detailed Setup

### Prerequisites

- **Git** (you have it, since you cloned this repo)
- **Docker & Docker Compose** (required for Postgres, Redis, MinIO)
- **Go 1.21+** (for control-plane, connector-gateway services)
- **Rust 1.70+** (for execution-plane, agent services)
- **Node.js 18+** (for web app, optional for MVP)

**Install via:**
- macOS: `brew install docker docker-compose go rust node`
- Linux (Ubuntu): `sudo apt install docker.io docker-compose golang-1.21 rustc nodejs`
- Windows: Use WSL2 + above commands, or Docker Desktop

### Step 1: Start Development Infrastructure

```bash
make dev-up
# Starts: PostgreSQL, Redis, MinIO
# Output: Shows container status
```

**Verify services are running:**
```bash
make dev-status
# Output:
#   PostgreSQL: ✓ OK
#   Redis:      ✓ OK
#   MinIO:      ✓ OK
```

**Service endpoints:**
- **PostgreSQL:** `localhost:5432` (user: postgres, password: postgres, database: app)
- **Redis:** `localhost:6379`
- **MinIO S3 API:** `http://localhost:9000` (user: minio, password: minio123)
- **MinIO Console:** `http://localhost:9001`

### Step 2: Build All Services

```bash
make build
# Compiles:
#   - services/control-plane (Go)
#   - services/connector-gateway (Go)
#   - services/execution-plane (Rust)
#   - services/agent (Rust)
```

**Troubleshooting:**
- If Go fails: `go mod tidy && go mod download`
- If Rust fails: `rustup update && cargo update`
- If TS fails: `npm install` (in apps/web/)

### Step 3: Run Smoke Tests

```bash
./smoke-test.sh
# Checks:
#   - Docker containers are running
#   - PostgreSQL responds to queries
#   - Redis responds to pings
#   - MinIO health endpoint works
#   - Services compile
#   - VERSION file is valid
#   - Documentation exists
```

**All tests should pass.** If any fail, check the error message and troubleshoot (see FAQ below).

### Step 4 (Optional): View Logs

```bash
# All services:
make dev-logs

# Specific service:
make dev-logs SERVICE=postgres
make dev-logs SERVICE=redis
make dev-logs SERVICE=minio
```

---

## One-Command Setup

Instead of steps 1–3, just run:

```bash
make dev
```

This orchestrates all of the above:
1. Starts docker-compose services
2. Builds all services
3. Runs smoke tests
4. Prints status and next steps

---

## Key Commands

| Command | Purpose |
|---------|---------|
| `make dev` | Start full dev environment (containers + build + smoke test) |
| `make dev-up` | Start containers only |
| `make dev-down` | Stop containers |
| `make dev-status` | Check service health |
| `make dev-reset` | Stop containers and delete volumes (fresh start) |
| `make build` | Rebuild all services (after code changes) |
| `make smoke-test` | Verify everything works |
| `make version` | Show current version (0.1.0) |

---

## Architecture Overview

**Read these next:**

1. **`docs/RFC-0001-architecture.md`** — Core architecture, design decisions, MVP scope
2. **`service-boundaries.md`** — What each service owns
3. **`.github/copilot-instructions.md`** — For AI agents (and humans who like structured guidance)
4. **`VERSIONING-QUICKSTART.md`** — Version management and releases

**Key concepts:**
- **Multi-tenant SaaS:** All data isolated by tenant_id + workspace_id
- **Policy-as-Code:** OPA/Rego for governance + approval gates
- **Evidence-first:** Every run generates immutable audit logs (hash-chained)
- **Fail-closed:** If policy unavailable, deny action (security-by-default)

---

## Next Steps

### For Feature Development

1. **Pick a feature** from the roadmap (`roadmap/mvp-v1-v2.md`)
2. **Create a branch:** `git checkout -b feature/my-feature`
3. **Implement:** Use `docs/RFC-0001-architecture.md` as your north star
4. **Test locally:** `make build && ./smoke-test.sh`
5. **Open a PR:** CI will validate (Phase 0 in progress)

### For Workflow Implementation

**MVP flagship: ServiceNow incident triage**

Implement end-to-end:
1. ServiceNow webhook ingestion
2. Incident fetch (read via connector)
3. LLM summarization + classification (BYO keys)
4. HITL approval (Slack)
5. Write-back (assignment, notes, category)
6. Evidence bundle + cost-per-ticket reporting

See `diagrams/sequences/` for flow diagrams (Mermaid format).

### For Infrastructure Setup

1. Check `iac/terraform/README.md` for cell provisioning (AWS, multi-region)
2. See `nfr/` directory for SLOs, security, reliability patterns
3. Review `data/db-schema.md` for RLS + multi-tenancy structure

---

## Environment Configuration

**Optional:** Copy `.env.example` to `.env` for custom settings:

```bash
cp .env.example .env
# Edit .env with your credentials (optional for MVP)
```

Common overrides:
- `LOG_LEVEL=debug` — Enable verbose logging
- `OPENAI_API_KEY=sk-...` — BYO LLM keys for testing
- `SLACK_BOT_TOKEN=xoxb-...` — For testing Slack approvals

---

## Troubleshooting

### "Docker daemon not running"
```bash
# Start Docker (macOS)
open -a Docker

# Start Docker (Linux)
sudo systemctl start docker

# Start Docker (Windows)
# Open Docker Desktop
```

### "Port already in use (5432, 6379, 9000)"
```bash
# Find process using port
lsof -i :5432
# Kill it, or use dev-reset to remove old containers
make dev-reset
```

### "Build fails: command not found: go"
```bash
# Install Go 1.21+
go version  # Check version
# If not found: https://golang.org/dl/
```

### "Build fails: error: linker 'cc' not found"
```bash
# Install C compiler (required for some Go packages)
# macOS: xcode-select --install
# Linux: sudo apt install build-essential
```

### "Smoke test fails: PostgreSQL not ready"
```bash
# Give services more time to start
make dev-reset && make dev-up && sleep 10 && ./smoke-test.sh
```

### "MinIO health check fails"
```bash
# MinIO requires curl; install if missing
# macOS: brew install curl
# Linux: sudo apt install curl
```

---

## FAQ

**Q: Do I need to run services locally, or can I just use docker-compose?**  
A: For MVP, docker-compose is enough. Local service running comes in Phase 1 (dev-mode hot reloading).

**Q: Can I use a different database?**  
A: Not in MVP. Architecture is Postgres-specific (RLS, JSONB, hash-chaining). Phase 1+ can evaluate alternatives.

**Q: Where do I put my code?**  
A: See `monorepo-layout.md`:
- Go services: `services/{control-plane,connector-gateway,execution-plane}/...`
- Rust services: `services/{agent,execution-plane}/...`
- Frontend: `apps/web/...`
- Contracts: `contracts/openapi/`, `contracts/policy/`, `contracts/connectors/`, `contracts/events/`

**Q: How do I run tests?**  
A: Tests are stubbed in Phase 0. Phase 1 adds:
```bash
make test          # Run all tests
make test-unit     # Unit tests only
make test-integration  # Integration tests
make lint          # Lint all code
```

**Q: How do I deploy this?**  
A: See `iac/terraform/README.md` for AWS cell provisioning (US + EU regions, RDS, ECS, SQS, etc.).

**Q: Can I run services outside docker for faster iteration?**  
A: Yes (Phase 1 feature). For now, edit code in services/ and `make build` to recompile. Restart containers after code changes (not yet automated).

---

## Getting Help

1. **Architecture questions:** Read `docs/RFC-0001-architecture.md`
2. **Design decisions:** Check `docs/RFC-000*.md` (in docs/todos/)
3. **Roadmap:** See `roadmap/mvp-v1-v2.md`
4. **Troubleshooting:** See FAQ above or check GitHub issues
5. **AI agent guidance:** See `.github/copilot-instructions.md`

---

**Status:** Phase 0 (MVP foundation)  
**Last Updated:** 2025-12-18  
**Next:** Implement CI pipeline and local service hot-reload (Phase 0 critical path)
