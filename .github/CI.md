# CI/CD Pipeline Guide

This document explains the continuous integration (CI) pipeline that validates all code changes on the `main` and `release/**` branches.

**Quick Links:**
- [Workflow Definition](../workflows/ci.yaml)
- [Branch Protection Rules](./BRANCH-PROTECTION.md)
- [Code Ownership](./CODEOWNERS)

---

## Overview

The CI pipeline is a **fail-closed** system: **PRs cannot merge unless all required checks pass**. This prevents regressions and ensures code quality.

**Pipeline Triggers:**
- Push to `main` or `release/**` branch
- Pull request against `main` or `release/**` branch
- Manual trigger via GitHub Actions UI

**Execution Time:** ~5-10 minutes (parallelized across languages)

---

## Job Categories

### 1. Go Services

**Services:** control-plane, connector-gateway

**Jobs:**

#### `go-build`
- **What:** Compiles all Go services
- **Fails if:** Syntax errors, missing imports, version incompatibilities
- **Success criteria:** `go build ./...` exits with code 0
- **Runtime:** ~1 minute

#### `go-test`
- **What:** Runs unit tests and reports coverage
- **Fails if:** Test assertions fail, race condition detected, database connectivity issues
- **Services:** PostgreSQL 16, Redis 7 (spun up in job)
- **Environment:**
  - `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/test_app`
  - `REDIS_URL=redis://localhost:6379`
- **Success criteria:** `go test -v -race ./...` passes (0 test failures)
- **Coverage:** Uploaded to codecov.io (informational, not blocking)
- **Runtime:** ~2-3 minutes

#### `go-lint`
- **What:** Checks code formatting and applies linting rules
- **Tools:**
  - `gofmt` — code formatting compliance
  - `golangci-lint` — composite linter (vet, errcheck, ineffassign, etc.)
  - `go mod tidy` — dependency consistency
- **Fails if:**
  - Code not formatted with `gofmt -s`
  - golangci-lint reports issues
  - go.mod/go.sum is out of sync
- **Fix locally:** `go fmt ./...` + `go mod tidy`
- **Runtime:** ~1-2 minutes

### 2. Rust Services

**Services:** execution-plane, agent

**Jobs:**

#### `rust-build`
- **What:** Compiles all Rust services in release mode
- **Fails if:** Syntax errors, missing crates, incompatible versions, compilation errors
- **Flags:** `--release` (optimized binary)
- **Success criteria:** `cargo build --release` exits with code 0
- **Runtime:** ~3-5 minutes (includes crate downloads on first run)
- **Caching:** Cargo registry, index, and build artifacts cached between runs

#### `rust-test`
- **What:** Runs unit tests
- **Fails if:** Test assertions fail, panic detected, timeout
- **Success criteria:** `cargo test --verbose` passes (0 test failures)
- **Runtime:** ~2-3 minutes

#### `rust-fmt`
- **What:** Checks code formatting
- **Tool:** `cargo fmt --all -- --check`
- **Fails if:** Code not formatted correctly
- **Fix locally:** `cargo fmt --all`
- **Runtime:** ~30 seconds

#### `rust-clippy`
- **What:** Runs advanced linter with warnings treated as errors
- **Tool:** `cargo clippy --all-targets --all-features -- -D warnings`
- **Fails if:** Clippy reports any warnings (lint issues)
- **Warns about:** Dead code, inefficient patterns, performance issues, style violations
- **Fix locally:** Run clippy locally, fix each warning
- **Runtime:** ~2-3 minutes

### 3. TypeScript/Node

**Service:** apps/web (React frontend)

**Jobs:**

#### `ts-check`
- **What:** TypeScript type checking and ESLint
- **Tools:**
  - `npm run typecheck` — tsconfig.json validation
  - `npm run lint` — ESLint rules
- **Fails if:**
  - Type mismatches detected
  - ESLint rules violated
- **Status:** Non-blocking in Phase 0 (`continue-on-error: true`)
- **Becomes blocking:** Phase 1+ (to enforce type safety)
- **Runtime:** ~1 minute

#### `ts-test`
- **What:** Runs Jest unit tests
- **Tool:** `npm test`
- **Fails if:** Test assertions fail
- **Status:** Non-blocking in Phase 0
- **Coverage:** Generated but not enforced (Phase 1: require ≥70%)
- **Runtime:** ~2 minutes

### 4. Contract Validation

**Job:** `contracts-validate`

**What:** Validates API contracts, event schemas, and policy definitions

**Checks:**

1. **OpenAPI Specification** (`contracts/openapi/openapi.yaml`)
   - Tool: `swagger-cli validate`
   - Fails if: Invalid YAML, missing required fields, broken references
   - Success criteria: Valid OpenAPI 3.0+ spec

2. **Event Schemas** (`contracts/events/*.schema.json`)
   - Tool: `ajv validate` (JSON Schema validator)
   - Validates:
     - `approval.required.v1.schema.json`
     - `connector.scope_changed.v1.schema.json`
     - `incident.created.v1.schema.json`
     - `policy.denied.v1.schema.json`
     - `run.completed.v1.schema.json`
   - Fails if: JSON not valid, schema not self-contained, type mismatches
   - Success criteria: All schemas pass ajv validation

3. **Policy Rules** (`contracts/policy/policy.rego`)
   - Tool: File existence check (semantic validation in Phase 1)
   - Current: Just verifies file exists
   - Future: OPA Rego linter + unit tests

**Runtime:** ~30 seconds

### 5. Security Scanning

**Jobs:**

#### `security-gitleaks`
- **What:** Scans commit history for hardcoded secrets
- **Detects:** API keys, passwords, tokens, private keys, SSH keys, AWS credentials
- **Tool:** gitleaks (GitHub Action)
- **Fails if:** Secret pattern detected in any commit
- **Severity:** BLOCKING — prevents merge immediately
- **Remediation:** See [BRANCH-PROTECTION.md#secret-remediation](./BRANCH-PROTECTION.md#secret-remediation)
- **Runtime:** ~30 seconds

#### `security-dependencies`
- **What:** Scans transitive dependencies for known vulnerabilities
- **Tools:**
  - Go: `nancy` (analyzes go.mod against OSS Index)
  - Rust: `cargo audit` (checks against advisory database)
  - Node: `npm audit` (checks package-lock.json against npm registry)
- **Fails if:** Critical vulnerability detected
- **Fails if:** Moderate vulnerability detected (Phase 1+)
- **Status:** Non-blocking in Phase 0 (`continue-on-error: true`)
- **Remediation:** Update dependency, verify patch resolves issue locally
- **Runtime:** ~2-3 minutes

### 6. Status Aggregation

**Job:** `ci-status` (Meta-check)

**What:** Verifies all critical CI jobs passed

**Logic:**
- ✅ **BLOCKING:** go-build, go-test, go-lint, rust-build, rust-test, rust-fmt, rust-clippy, contracts-validate, security-gitleaks
- ⚠️ **WARNING:** ts-check, ts-test, security-dependencies (non-blocking for Phase 0)

**Result:** Displayed as single pass/fail badge on PR

---

## Troubleshooting

### Go Troubleshooting

#### Compilation Error: `undefined: SomeType`

**Cause:** Missing Go module or import

**Fix:**
```bash
cd services/control-plane
go get <package-path>
go mod tidy
git add go.mod go.sum
git commit -m "chore: update dependencies"
git push
```

**Example:**
```bash
go get github.com/some-org/some-package@latest
```

#### Test Failure: `sql: connection refused`

**Cause:** PostgreSQL not running

**Fix (local development):**
```bash
make dev-up  # Start postgres + redis via docker-compose
# OR manually:
docker-compose up -d postgres redis
make test
```

**Fix (CI):** Tests use GitHub Actions service container (auto-started). If failing:
1. Check `go-test` logs for database connection string
2. Verify PostgreSQL credentials in ci.yaml match test expectations

#### Lint Error: `gofmt -s ...`

**Cause:** Code not formatted

**Fix:**
```bash
cd services/control-plane
gofmt -s -w .
go mod tidy
git add -A
git commit -m "chore: format Go code"
git push
```

#### Module Tidy Error

**Cause:** go.mod or go.sum out of sync

**Fix:**
```bash
cd services/control-plane
go mod tidy
# If error persists, check for indirect dependencies:
go mod graph
# Remove unused:
go mod download
go mod verify
git add go.mod go.sum
git commit -m "chore: tidy Go dependencies"
git push
```

### Rust Troubleshooting

#### Build Error: `expected type X, found type Y`

**Cause:** Type mismatch in code

**Fix:**
1. Read the compiler error message carefully
2. Check the source file and line number
3. Verify function signature matches expected type
4. Example fix:
   ```rust
   // Before (wrong)
   let count: i32 = my_vec.len();
   
   // After (correct)
   let count: usize = my_vec.len();
   ```

#### Build Error: `unresolved import`

**Cause:** Missing or incorrectly spelled crate dependency

**Fix:**
```bash
cd services/execution-plane
# Check Cargo.toml for the dependency
grep "missing-crate" Cargo.toml
# If missing, add it:
cargo add missing-crate
# Then:
cargo build
```

#### Test Failure: `panicked at 'assertion failed'`

**Cause:** Test assertion failed

**Fix:**
1. Run test locally to see detailed error:
   ```bash
   cargo test -- --nocapture  # Show println! output
   ```
2. Debug the test or code
3. Verify fix locally before pushing

#### Clippy Error: `warning: unused variable`

**Cause:** Clippy detected code quality issue

**Fix Examples:**
```rust
// Before (warning: unused)
let x = expensive_computation();

// After (keep unused binding with _)
let _x = expensive_computation();

// OR remove if truly unneeded
// (no assignment)
```

Other common clippy fixes:
- Use `if let` instead of `match`
- Use `.contains()` instead of manual iteration
- Remove clones if reference works
- Use more specific error types

**Fix all:**
```bash
cargo clippy --fix --allow-staged
cargo fmt
```

#### Fmt Error: `code not formatted`

**Cause:** Code not formatted with cargo fmt

**Fix:**
```bash
cargo fmt --all
git add -A
git commit -m "chore: format Rust code"
git push
```

### TypeScript Troubleshooting

#### Type Error: `Property 'x' does not exist`

**Status:** Non-blocking in Phase 0

**Fix (optional):**
```bash
cd apps/web
npm install  # Update packages
npm run typecheck
# Fix reported type errors
git add -A
git commit -m "chore: fix TypeScript types"
git push
```

#### Test Failure

**Status:** Non-blocking in Phase 0

**Fix (optional):**
```bash
cd apps/web
npm test -- --watch
# Fix failing tests
npm test  # Verify all pass
git add -A
git commit -m "test: fix failing tests"
git push
```

### Contract Validation Troubleshooting

#### OpenAPI Validation Error

**Cause:** Invalid YAML syntax or schema

**Fix:**
```bash
# Validate locally
swagger-cli validate contracts/openapi/openapi.yaml

# Common issues:
# - YAML indentation (use 2 spaces, not tabs)
# - Missing required properties (title, version, paths)
# - Invalid $ref (must point to existing schema)
# - Cyclic references
```

#### JSON Schema Validation Error

**Cause:** Invalid JSON or schema syntax

**Fix:**
```bash
# Validate locally
ajv validate -s contracts/events/approval.required.v1.schema.json

# Common issues:
# - Invalid JSON syntax (use jq to validate)
# - Missing required fields (type, properties)
# - Invalid property names
# - Unsupported JSON Schema keywords
```

**Validate JSON structure:**
```bash
jq . contracts/events/approval.required.v1.schema.json
# If invalid, jq will show error
```

### Security Troubleshooting

#### Gitleaks: Secret Detected

**Status:** BLOCKING — must fix immediately

**Danger:** Secret is now in git history and visible to all repo readers

**Remediation (CRITICAL):**

1. **Immediately revoke the exposed secret**
   - If API key: Disable the key in your provider's console
   - If password: Change the password
   - If token: Invalidate/rotate the token

2. **Remove secret from git history**
   ```bash
   # Use git-filter-repo (GitHub recommended)
   pip install git-filter-repo
   
   # Create file listing strings to remove
   echo "my-secret-api-key" > deletions.txt
   
   # Remove from all commits
   git filter-repo --replace-text deletions.txt --force
   
   # Force push (requires admin override on protected branch)
   git push --force origin main
   ```

3. **Notify security team**
   - Add entry to `risk/risk-register.md`
   - Document: time of exposure, type of secret, remediation steps taken
   - Assess impact: was secret used to access production resources?

4. **Prevent future incidents**
   - Add file to `.gitignore` or `.gitleaksignore`
   - Use environment variables for secrets (never commit)
   - Set up pre-commit hook: `git hook install` (when available)

#### Cargo Audit: Vulnerability Found

**Status:** Non-blocking in Phase 0

**Example Error:**
```
vulnerable crate: openssl-sys
version: 0.9.60
advisory: RUSTSEC-2021-0119
```

**Fix:**
1. Check current version in Cargo.toml
2. Update to patched version:
   ```bash
   cargo update openssl-sys@0.9 --aggressive
   ```
3. Rebuild and test locally:
   ```bash
   cargo build
   cargo test
   ```
4. If incompatible, evaluate alternatives or report to maintainers

#### NPM Audit: Vulnerability Found

**Status:** Non-blocking in Phase 0

**Fix:**
```bash
cd apps/web
npm install  # Auto-fixes compatible vulnerabilities
npm audit fix --force  # Forces major version upgrades (risky)
# OR manually update in package.json
npm install some-package@latest
npm test  # Verify no regressions
```

---

## Local CI Reproduction

### Run All Checks Locally

```bash
# Build all services
make build

# Run tests
make test

# Run linters
make lint

# Run smoke tests (validates environment)
make smoke-test

# Run a specific language's CI
make go-test go-lint
make rust-test rust-clippy
```

*Note: Not all checks can run locally (e.g., gitleaks needs git history), but most can.*

### Run Specific Job

#### Go
```bash
# Build
cd services/control-plane
go build ./...

# Test
go test -v -race ./...

# Lint
gofmt -s -l .  # Lists unformatted files
golangci-lint run
```

#### Rust
```bash
# Build
cd services/execution-plane
cargo build --release

# Test
cargo test --verbose

# Format
cargo fmt --all -- --check

# Clippy
cargo clippy --all-targets --all-features -- -D warnings
```

#### TypeScript
```bash
cd apps/web
npm install
npm run typecheck
npm run lint
npm test
```

#### Contracts
```bash
swagger-cli validate contracts/openapi/openapi.yaml
ajv validate -s contracts/events/*.schema.json
```

---

## Adding New CI Jobs

### When to Add a Job

- New language or service added to monorepo
- New validation tool required (e.g., security scanner)
- New contract type (e.g., GraphQL schema validation)

### Steps to Add a Job

1. **Update `.github/workflows/ci.yaml`**
   - Add new `job_name:` section
   - Define triggers (on push, on pull_request)
   - Define steps (checkout, setup tools, run checks)
   - Add job to `ci-status` needs (if critical)

2. **Update `BRANCH-PROTECTION.md`**
   - Document the new check
   - List it under "Required Status Checks"
   - Add troubleshooting section if complex

3. **Test locally**
   - Run the job's commands locally
   - Verify success criteria
   - Test a failure scenario

4. **Create test PR**
   - Push changes to a feature branch
   - Verify CI runs the new job
   - Merge when successful

### Example: Add Python Service CI

```yaml
# In ci.yaml
python-test:
  name: 'Python: Tests'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v4
      with:
        python-version: '3.11'
        cache: 'pip'
    - run: pip install -r services/my-service/requirements.txt
    - run: pytest services/my-service/tests/
```

Then update `ci-status` job to include `python-test` in `needs:`.

---

## Monitoring CI Health

### Viewing CI Results

**Per PR:**
- Go to GitHub PR → "Checks" tab
- Click job name to see detailed logs

**Per branch:**
- Go to GitHub → "Actions" tab
- Filter by branch to see all runs

**In Terminal:**
```bash
# List recent workflow runs
gh run list --branch main --limit 10

# View specific run
gh run view <run-id>

# Check specific job
gh run view <run-id> --log
```

### Setting Up Alerts

**Email Alerts (GitHub Settings):**
- Settings → Notifications → Workflow runs
- Get notified when workflow fails

**Slack Integration:**
- GitHub App: https://github.com/apps/slack
- Configure channels for CI notifications

---

## Performance Optimization

### Current Pipeline Runtime

- `go-build`: ~1 min
- `go-test`: ~2-3 min
- `go-lint`: ~1-2 min
- `rust-build`: ~3-5 min
- `rust-test`: ~2-3 min
- `rust-fmt`: ~30 sec
- `rust-clippy`: ~2-3 min
- `ts-check`: ~1 min
- `ts-test`: ~2 min
- `contracts-validate`: ~30 sec
- `security-gitleaks`: ~30 sec
- `security-dependencies`: ~2-3 min

**Total (parallelized):** ~5-10 minutes

### How to Speed Up

1. **Cache Dependencies**
   - Go: Uses `actions/cache` for go mod (already configured)
   - Rust: Caches cargo registry + build artifacts (already configured)
   - Node: Uses npm cache (already configured)

2. **Split Heavy Jobs**
   - If a job takes >5 min, consider splitting into multiple jobs
   - Example: `rust-clippy` and `rust-fmt` could be combined with `rust-test`

3. **Use Matrix Builds**
   - Test against multiple Go/Rust/Node versions with `matrix`
   - Example: Test against Go 1.20, 1.21, 1.22

4. **Skip Unnecessary Jobs**
   - Add `paths:` filter to skip jobs when certain files unchanged
   - Example: Skip TypeScript job if only `services/` changed

---

## Links & References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions - Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Status Badge Markdown](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/adding-a-workflow-status-badge)
- [golangci-lint Configuration](https://golangci-lint.run/usage/configuration/)
- [Clippy Lint List](https://rust-lang.github.io/rust-clippy/)
- [JSON Schema Specification](https://json-schema.org/)
- [OpenAPI 3.0 Specification](https://spec.openapis.org/oas/v3.0.3)

---

## FAQ

### Q: Can I temporarily disable CI?

**A:** Not recommended. However, in emergencies:

1. Go to Settings → Branches → Branch Protection Rules
2. Temporarily uncheck "Require status checks to pass"
3. Merge the emergency fix
4. **Re-enable immediately** and document in INCIDENTS.md

### Q: How do I test a CI job locally?

**A:** Most jobs can be reproduced locally by running the same commands. See [Local CI Reproduction](#local-ci-reproduction) above.

### Q: What if CI passes but code has a bug?

**A:** CI catches syntax errors and obvious failures, but not all bugs. Code review (Phase 1+) adds human validation. For now:
- Write comprehensive tests
- Test locally with `make test`
- Ask for peer review in PR description

### Q: Can I force-merge a PR if CI fails?

**A:** Only repository admins can force-merge (if enabled in branch protection). This should be extremely rare and must be:
1. Approved by another maintainer
2. Documented in INCIDENTS.md
3. Followed by a fix PR that makes CI pass again

### Q: How do I skip CI for a commit?

**A:** Use `[skip ci]` in commit message:
```bash
git commit -m "docs: update README [skip ci]"
```

**Warning:** Only use for documentation-only changes. Never skip CI for code changes.

---

## Escalation Contact

- 🚨 **CI is broken:** Open issue in #incidents channel, notify @maintainer
- 💡 **Feature request:** Add to [CI.md](./CI.md) as enhancement
- 🔐 **Security issue:** Report to @security-team privately

---

**Last Updated:** 2024-12
**Owner:** @maintainer
**Next Review:** 2025-Q1
