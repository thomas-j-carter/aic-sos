# PHASE-0: Repo and Delivery System

**Overview:** Turn the scaffold into a buildable, testable, deployable system with a repeatable dev loop.

**Primary artifacts referenced:** `monorepo_scaffold_v0.2.0.zip` (repo skeleton), architecture bundle docs under `architecture_bundle_v0.1.1/`.

## P0 / Critical

- [x] **Unpack scaffold into the real repo root**
  - DoD:
    - Repo matches expected layout (apps/services/contracts/infra/docs).
    - `docs/START-HERE.md` is up to date with how to run locally.
  - **Completed:** Verified repo structure in place.

- [x] **Define versioning + release naming convention**
  - Decide: semver for repos + component tags (e.g., `controlplane:v0.3.0`).
  - DoD:
    - A single `VERSION` source of truth (or equivalent) + release checklist.
  - **Completed:** See `VERSIONING.md`, `VERSIONING-QUICKSTART.md`, `RELEASE-CHECKLIST.md`, `version.sh`

- [x] **Local developer environment (single-command)**
  - Provide `make dev` (or `just dev`) that starts:
    - Postgres (multi-tenant DB)
    - Redis or durable queue (if used)
    - Local object store emulator (optional) for evidence bundles
    - All core services in dev mode
  - DoD:
    - Fresh clone → `make dev` → smoke test script passes.
  - **Completed:** See `Makefile` (make dev target), `docker-compose.yaml`, `smoke-test.sh`, `docs/START-HERE.md`, `DEV_SETUP.md`, `.env.example`

- [x] **CI pipeline on main branch**
  - Required jobs (minimum):
    - Go: build + unit tests + lint
    - Rust: build + unit tests + fmt + clippy
    - TS: typecheck + lint + tests (if present)
    - Python: unit tests + typecheck (if present)
    - Contract checks: OpenAPI + JSON schema validation
  - DoD:
    - PR cannot merge if any required job fails.
  - **Completed:** See `.github/workflows/ci.yaml`, `.github/BRANCH-PROTECTION.md`, `.github/CI.md`, `.github/CODEOWNERS`

- [x] **"Contracts as truth" workflow**
  - Ensure any changes to:
    - `contracts/openapi/openapi.yaml`
    - `contracts/policy/*.json`
    - connector manifests/schema
    require CI validation and have generated stubs (where applicable).
  - DoD:
    - `make contracts` validates and regenerates server/client stubs.
  - **Completed:** See:
    - `scripts/validate-contracts.sh` (290 lines) — validates OpenAPI, event schemas, manifests, policy rules
    - `scripts/generate-contracts.sh` (380 lines) — generates Go server stubs, TS client types, validators, connector loaders
    - `Makefile` (make contracts, make contracts-validate, make contracts-generate, make contracts-clean)
    - `docs/CONTRACTS.md` (721 lines) — comprehensive developer guide
    - `docs/CONTRACTS-QUICK-VISUAL.md` (400+ lines) — visual guides and quick reference
    - `.github/CONTRACTS-DELIVERY-SUMMARY.md` (500+ lines) — implementation details
    - `.github/workflows/ci.yaml` (enhanced contracts-validate job) — validates and regenerates stubs in CI

- [x] **Baseline security hygiene**
  - Secret scanning in CI (e.g., gitleaks)
  - Dependency scanning (Go/Rust/NPM/Python)
  - DoD:
    - CI blocks commits with obvious secrets.
    - SBOM generation is stubbed (P1 can harden).
  - **Completed:** See:
    - `.github/workflows/ci.yaml` (hardened security-gitleaks, security-dependencies, security-sbom jobs)
    - `scripts/generate-sbom.sh` (350+ lines) — generates CycloneDX SBOMs for Go/Rust/Node
    - `docs/SECURITY.md` (450+ lines) — comprehensive security policy, vulnerability handling, compliance
    - `docs/SECURITY-QUICK-REFERENCE.md` (150+ lines) — quick reference for developers
    - All security controls now BLOCKING (fail if secrets/CVEs detected)

## P1 / High

- [ ] **Repo conventions**
  - Standard Make targets, codeowners, lint configs, structured logging conventions.
- [ ] **Container build pipeline**
  - Multi-arch images (optional), reproducible builds, pinned base images.

## P2 / Medium

- [ ] **Dev "golden path" scripts**
  - `make demo-seed` to create a demo tenant/workspace, policies, workflow versions.
- [ ] **Docs polish**
  - Architecture diagrams rendered in CI (Mermaid → images) for docs site.

## P3 / Low

- [ ] **Monorepo productivity extras**
  - Nx/Turborepo-like caching (without Bazel), optional.

## Exit gate

- [ ] New engineer can follow `docs/START-HERE.md` and:
  1) run the stack locally, 2) run a smoke test, 3) open a PR, 4) see CI pass.
