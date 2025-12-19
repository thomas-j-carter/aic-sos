# Versioning & Release Strategy

**Status:** Phase 0 (MVP foundation)  
**Updated:** 2025-12-18  
**Version:** See `VERSION` file (single source of truth)

---

## Overview

This monorepo uses **semantic versioning (SemVer)** for the entire platform, plus **component tags** for Docker images and service artifacts. All versioning is centralized in a single `VERSION` file to ensure consistency across:

- Go services (control-plane, connector-gateway)
- Rust services (execution-plane, agent)
- Frontend app (TS/React)
- Terraform modules
- Docker image tags
- Helm chart versions (when IaC is containerized)

---

## Semantic Versioning (SemVer)

**Format:** `MAJOR.MINOR.PATCH` (e.g., `0.1.0`, `1.2.3`)

### Rules

- **MAJOR** (e.g., `1.0.0` → `2.0.0`):
  - Breaking API changes (REST endpoint removal/redesign, policy schema incompatibility)
  - Database schema migrations that require downtime or irreversible changes
  - Policy bundle format changes
  - Workflow YAML schema changes (incompatible with old versions)

- **MINOR** (e.g., `0.1.0` → `0.2.0`):
  - New features (new ToolAction, new policy rule, new workflow capabilities)
  - Backward-compatible API additions
  - Database migrations (additive columns, new tables)
  - New optional fields in existing schemas

- **PATCH** (e.g., `0.1.0` → `0.1.1`):
  - Bug fixes
  - Performance improvements (no API change)
  - Documentation updates
  - Internal refactoring with no user-facing impact

### MVP Phase Guidelines

- **v0.x.y** = MVP development (may have breaking changes between minor versions)
- **v1.0.0** = First stable release (backward-compatibility commitment begins)

---

## Single Source of Truth: VERSION File

**Location:** `VERSION` (repository root)

**Content:** A single line with the current version:
```
0.1.0
```

**Never hardcode versions** in:
- `Cargo.toml` (will use `version.sh` to sync)
- `go.mod` comments
- `package.json` (will use `version.sh` to sync)
- Docker image tags in Makefile/CI

**All services read from `VERSION`** during build/release.

---

## Component Tags (Docker/Artifact Tags)

Each service gets a **component-specific tag** derived from the root version:

```
controlplane:v0.1.0
execution-plane:v0.1.0
connector-gateway:v0.1.0
agent:v0.1.0
web:v0.1.0
```

**Usage in Makefile/CI:**
```makefile
VERSION := $(shell cat VERSION | tr -d '\n' | tr -d ' ')

docker-build-control-plane:
	docker build -t controlplane:v$(VERSION) ./services/control-plane

docker-build-agent:
	docker build -t agent:v$(VERSION) ./services/agent
```

**Usage in Terraform/Helm:**
```hcl
# main.tf
variable "platform_version" {
  default = "0.1.0"  # Or read from VERSION file dynamically
}

resource "kubernetes_deployment" "control_plane" {
  spec {
    template {
      spec {
        container {
          image = "controlplane:v${var.platform_version}"
        }
      }
    }
  }
}
```

**Usage in docker-compose (local dev):**
```yaml
services:
  control-plane:
    image: controlplane:v${VERSION:-0.1.0}
    # ...
```

---

## Git Tags & Releases

### Tagging Convention

**Format:** `v{VERSION}` (e.g., `v0.1.0`, `v1.2.3`)

**When to tag:**
- After all changes for a release are merged to `main`
- CI passes (all tests, linters, security checks)
- Release checklist is complete
- Release notes are published

**Creating a tag:**
```bash
# Using the helper script
./version.sh tag

# Or manually
git tag -a v0.1.0 -m "Release version 0.1.0"
git push origin v0.1.0
```

### Release Notes Naming

**File:** `docs/releases/v{VERSION}.md` (e.g., `docs/releases/v0.1.0.md`)

**Template:**
```markdown
# Release v0.1.0

**Release Date:** YYYY-MM-DD  
**Git Tag:** v0.1.0

## What's New

### Features
- Feature 1
- Feature 2

### Bug Fixes
- Bug fix 1
- Bug fix 2

### Breaking Changes (if MAJOR bump)
- Breaking change 1

### Upgrade Instructions
1. Step 1
2. Step 2

## Contributors
- @person1
- @person2
```

---

## Version Management Workflow

### Viewing Current Version

```bash
# Show current version
./version.sh show

# Output:
# Current version: 0.1.0
```

### Bumping Version (Before Release)

```bash
# Bump patch version (0.1.0 → 0.1.1)
./version.sh bump patch

# Bump minor version (0.1.0 → 0.2.0)
./version.sh bump minor

# Bump major version (0.1.0 → 1.0.0)
./version.sh bump major
```

### Setting Version Explicitly

```bash
# Set to specific version
./version.sh set 0.2.0
```

### Listing Component Tags

```bash
# Show Docker-style tags for all services
./version.sh tags

# Output:
# Component tags for version 0.1.0:
#   controlplane:v0.1.0
#   execution-plane:v0.1.0
#   connector-gateway:v0.1.0
#   agent:v0.1.0
```

### Creating Git Tag

```bash
# Create annotated git tag
./version.sh tag

# Output:
# ✓ Created git tag: v0.1.0
# To push: git push origin v0.1.0
```

---

## Makefile Integration

Add these targets to `Makefile`:

```makefile
.PHONY: version version-show version-bump version-patch version-minor version-major version-tag

VERSION := $(shell cat VERSION | tr -d '\n' | tr -d ' ')

version:
	@./version.sh show

version-show:
	@./version.sh show

version-bump-patch:
	./version.sh bump patch

version-bump-minor:
	./version.sh bump minor

version-bump-major:
	./version.sh bump major

version-tag:
	./version.sh tag

version-tags:
	@./version.sh tags
```

**Usage:**
```bash
make version
make version-bump-minor
make version-tag
make version-tags
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      bump_type:
        description: 'Version bump (major, minor, patch)'
        required: true
        default: 'patch'
        type: choice
        options:
          - major
          - minor
          - patch

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Read current version
        id: current
        run: echo "VERSION=$(cat VERSION)" >> $GITHUB_OUTPUT

      - name: Bump version
        run: |
          chmod +x ./version.sh
          ./version.sh bump ${{ github.event.inputs.bump_type }}

      - name: Get new version
        id: new
        run: echo "VERSION=$(cat VERSION)" >> $GITHUB_OUTPUT

      - name: Create commit
        run: |
          git config user.name "Release Bot"
          git config user.email "release@example.com"
          git add VERSION
          git commit -m "Bump version to ${{ steps.new.outputs.VERSION }}"

      - name: Create tag
        run: |
          chmod +x ./version.sh
          ./version.sh tag

      - name: Push changes and tag
        run: |
          git push origin main
          git push origin v${{ steps.new.outputs.VERSION }}

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.new.outputs.VERSION }}
          body_path: docs/releases/v${{ steps.new.outputs.VERSION }}.md
          draft: false
          prerelease: ${{ startsWith(steps.new.outputs.VERSION, '0.') }}
```

---

## Database Schema Versioning

Schema versions are tracked separately from app version to allow independent migrations.

**File:** `db/SCHEMA_VERSION`

**Format:** Integer (e.g., `3` = schema v3)

**Tracking:**
```sql
CREATE TABLE schema_version (
  version INT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_version (version) VALUES (3);
```

**Migration naming:**
```
db/migrations/
  001_init_schema.sql
  002_add_audit_logging.sql
  003_add_policy_bundle_ttl.sql
  ...
```

---

## Pre-Release Checklist (Definition of Done)

Before bumping version and creating a release tag:

- [ ] **Code**
  - [ ] All feature branches merged to `main`
  - [ ] No uncommitted changes
  - [ ] Commit history is clean (squash or rebase as needed)

- [ ] **Testing**
  - [ ] `make test` passes (all Go, Rust, TS unit tests)
  - [ ] Integration tests pass (if available)
  - [ ] Manual smoke test on local stack passes

- [ ] **Building**
  - [ ] `make build` succeeds for all services
  - [ ] `docker compose build` succeeds for all images
  - [ ] No build warnings (treat as errors)

- [ ] **Linting & Quality**
  - [ ] `make lint` passes (Go, Rust, TS)
  - [ ] `go fmt`, `cargo fmt`, `prettier` applied
  - [ ] No security warnings (gitleaks, cargo audit, npm audit)

- [ ] **Documentation**
  - [ ] `docs/START-HERE.md` is up to date
  - [ ] `docs/releases/v{VERSION}.md` is written
  - [ ] Architecture docs reflect changes (if applicable)
  - [ ] CHANGELOG.md is updated

- [ ] **Version Preparation**
  - [ ] `VERSION` file updated (using `./version.sh bump`)
  - [ ] Cargo.toml/package.json versions synced (if needed)
  - [ ] Component tags listed: `./version.sh tags`

- [ ] **Git & Tagging**
  - [ ] Commit with message: "Release v{VERSION}"
  - [ ] Git tag created: `./version.sh tag`
  - [ ] Tag pushed: `git push origin v{VERSION}`

- [ ] **Release Communication**
  - [ ] Release notes published (GitHub releases, docs site)
  - [ ] Announce to team/stakeholders
  - [ ] Update roadmap/status docs

---

## Example: Complete Release Workflow

```bash
# 1. Check current version
./version.sh show
# Output: Current version: 0.1.0

# 2. Run all tests locally
make test
make lint

# 3. Bump version
./version.sh bump minor
# Output: Bumping minor: 0.1.0 → 0.2.0

# 4. Write release notes
cat > docs/releases/v0.2.0.md << 'EOF'
# Release v0.2.0

**Release Date:** 2025-12-18

## Features
- Added GitHub connector (read + PR comments)
- Policy simulation API now returns decision reason_json
- Improved DLQ replay UI with idempotency key tracking

## Bug Fixes
- Fixed Slack approval timeout handling
- Fixed audit log hash chain validation on large runs

## Upgrade Instructions
1. Deploy control-plane:v0.2.0
2. Deploy execution-plane:v0.2.0
3. Run migrations: `make migrate` (no schema changes in v0.2.0)
4. Restart agents with new version
EOF

# 5. Commit version bump and release notes
git add VERSION docs/releases/v0.2.0.md
git commit -m "Release v0.2.0"

# 6. Create tag
./version.sh tag
# Output: ✓ Created git tag: v0.2.0

# 7. Push to remote
git push origin main
git push origin v0.2.0

# 8. Show component tags
./version.sh tags
# Output:
#   controlplane:v0.2.0
#   execution-plane:v0.2.0
#   connector-gateway:v0.2.0
#   agent:v0.2.0
```

---

## Updating Service Versions (Optional Sync)

For services that embed their own version strings (Cargo.toml, package.json), you can optionally sync them with the root VERSION:

### Cargo.toml

```toml
[package]
name = "execution-plane"
version = "0.1.0"  # Manually sync or use build script to inject VERSION
```

**Build script approach** (`build.rs`):
```rust
fn main() {
    let version = std::fs::read_to_string("../VERSION")
        .unwrap_or_else(|_| "0.0.0".to_string())
        .trim()
        .to_string();
    println!("cargo:rustc-env=CARGO_PKG_VERSION={}", version);
}
```

### package.json

```json
{
  "name": "web",
  "version": "0.1.0"
}
```

**Sync script** (`.github/workflows/sync-versions.yml`):
```yaml
- name: Sync package versions
  run: |
    VERSION=$(cat VERSION)
    jq --arg v "$VERSION" '.version = $v' apps/web/package.json > apps/web/package.json.tmp
    mv apps/web/package.json.tmp apps/web/package.json
    cargo set-version --workspace "$VERSION"
```

---

## FAQs

### Q: What if we need to release a security patch for v0.1.x while v0.2.0 is in development?

**A:** Use branch-based releases:
```bash
# From main (v0.2.0-dev)
git checkout -b release/0.1.x v0.1.0  # Create branch at v0.1.0 tag
./version.sh bump patch                # 0.1.0 → 0.1.1
./version.sh tag                        # Tag v0.1.1
git push origin release/0.1.x v0.1.1
```

### Q: How do we handle pre-release versions?

**A:** Extend SemVer with `-alpha`, `-beta`, `-rc`:
```
0.2.0-alpha.1
0.2.0-beta.1
0.2.0-rc.1
0.2.0  (release)
```

Modify `version.sh` to support pre-release tags if needed (Phase 1 enhancement).

### Q: Should services have independent version numbers?

**A:** **No (MVP).** Keeping a single VERSION simplifies deployments and documentation. If services diverge significantly in v1+, consider independent versioning (advanced).

### Q: How do we pin dependencies across services?

**A:** Use version pinning in:
- `go.mod` (Go dependency versions)
- `Cargo.lock` (Rust dependencies, already committed)
- `package-lock.json` (Node dependencies, already committed)

The root `VERSION` is for the *platform/release*, not dependencies.

---

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)

---

**Maintainer:** Release team  
**Last Updated:** 2025-12-18
