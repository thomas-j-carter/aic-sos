# CI Pipeline Quick Reference

## ⚡ At a Glance

| Component | Tool | Status | Time |
|-----------|------|--------|------|
| **Go** | gofmt + golangci-lint + go mod | 🔴 BLOCKING | 4-6 min |
| **Rust** | cargo fmt + clippy | 🔴 BLOCKING | 7-11 min |
| **TS** | tsc + eslint + jest | 🟡 NON-BLOCKING | 3-4 min |
| **Contracts** | swagger-cli + ajv | 🔴 BLOCKING | 30 sec |
| **Security** | gitleaks + cargo/npm audit | 🔴 gitleaks, 🟡 audit | 2-3 min |

**Total Runtime:** ~5-10 minutes (parallelized)

---

## 🚀 For PR Authors

### Before Pushing

```bash
# Build all services
make build

# Run all tests
make test

# Run all linters
make lint

# Verify environment
make smoke-test
```

### When CI Fails

1. Click the failed job in GitHub (PR → Checks tab)
2. Read the error message
3. Search `.github/CI.md` for your language + error type
4. Fix locally using provided commands
5. Push fix (CI auto-reruns)

### Common Fixes

```bash
# Go formatting
cd services/control-plane && go fmt ./... && go mod tidy

# Rust formatting
cargo fmt --all

# Rust linting
cargo clippy --fix --allow-staged

# TypeScript check (non-blocking)
cd apps/web && npm run typecheck

# Secret exposed
# See: .github/BRANCH-PROTECTION.md#secret-remediation
```

---

## 👨‍💼 For Repository Admins

### Enable CI Enforcement (One-time Setup)

1. Go to GitHub repository → Settings → Branches
2. Click "Add rule"
3. Enter pattern: `main`
4. Check: ✅ "Require status checks to pass before merging"
5. Select required checks:
   - `go-build`, `go-test`, `go-lint`
   - `rust-build`, `rust-test`, `rust-fmt`, `rust-clippy`
   - `contracts-validate`
   - `security-gitleaks`
6. Check: ✅ "Require branches to be up to date before merging"
7. Check: ✅ "Dismiss stale pull request approvals when new commits are pushed"
8. Check: ✅ "Include administrators" (fail-closed)
9. Save

### Monitor CI Health

```bash
# List recent runs
gh run list --branch main --limit 20

# View specific run
gh run view <run-id> --log

# Check job status
gh run view <run-id>
```

### Emergency: Temporarily Disable CI

**Only in critical situations:**

1. Settings → Branches → Edit rule
2. Uncheck "Require status checks to pass"
3. Save
4. Merge emergency fix
5. **Re-enable immediately** (repeat steps 1-3, re-check the option)
6. Document in INCIDENTS.md

---

## 📋 Job Descriptions

### `go-build` + `go-test` + `go-lint`
- **Services:** control-plane, connector-gateway
- **Tools:** Go 1.21+, gofmt, golangci-lint, go mod
- **Deps:** PostgreSQL 16, Redis 7 (auto-started in test job)
- **Fail if:** Compilation error, test failure, code not formatted, go.mod out of sync
- **Fix:** `.github/CI.md#go-troubleshooting`

### `rust-build` + `rust-test` + `rust-fmt` + `rust-clippy`
- **Services:** execution-plane, agent
- **Tools:** Rust stable, cargo, clippy
- **Fail if:** Build error, test failure, code not formatted, clippy warnings
- **Fix:** `.github/CI.md#rust-troubleshooting`

### `ts-check` + `ts-test`
- **Service:** apps/web
- **Tools:** TypeScript, ESLint, Jest
- **Status:** ⚠️ Non-blocking in Phase 0 (can still merge if TS fails)
- **Fails if:** Type mismatch, lint error, test failure
- **Fix:** `.github/CI.md#typescript-troubleshooting`

### `contracts-validate`
- **Files:** contracts/openapi/openapi.yaml, contracts/events/*.schema.json
- **Tools:** swagger-cli, ajv
- **Fails if:** Invalid YAML, invalid JSON schema, broken references
- **Fix:** `.github/CI.md#contract-validation-troubleshooting`

### `security-gitleaks`
- **What:** Scans all commits for hardcoded secrets (API keys, tokens, passwords)
- **Status:** 🔴 **BLOCKING** — must fix immediately
- **Fails if:** Secret pattern detected in commit history
- **Fix:** `.github/BRANCH-PROTECTION.md#secret-remediation` (uses git-filter-repo)

### `security-dependencies`
- **What:** Audits transitive dependencies for known vulnerabilities
- **Tools:** Go nancy, Rust cargo-audit, Node npm audit
- **Status:** 🟡 Non-blocking in Phase 0
- **Fails if:** Critical vulnerability in dependency
- **Fix:** Update dependency, verify locally: `cargo update`, `npm install`, `go get`

---

## 🐛 Troubleshooting by Error

### "undefined: SomeType" (Go)
**Cause:** Missing import or package not in go.mod  
**Fix:** `go get <package-path>` + `go mod tidy`

### "expected type X, found type Y" (Rust)
**Cause:** Type mismatch in function call  
**Fix:** Check function signature, verify types match

### "Property 'x' does not exist" (TypeScript)
**Cause:** Property not defined on type  
**Status:** Non-blocking Phase 0, just warning  
**Fix:** Update type definition or use optional chaining (?)

### "sql: connection refused" (Go tests)
**Cause:** PostgreSQL not running  
**Fix:** `make dev-up` to start docker-compose services

### "Secret detected" (gitleaks)
**Severity:** 🔴 CRITICAL — block all work  
**Fix:** See `.github/BRANCH-PROTECTION.md#secret-remediation`  
**Steps:** Rotate secret → git-filter-repo → force-push

### "warning: unused variable" (Rust clippy)
**Cause:** Dead code detected  
**Fix:** Remove unused binding or use `let _x =` to suppress

---

## 📊 Performance Expectations

**Job Runtimes (average):**
- Go: 4-6 minutes (build, test, lint parallelized)
- Rust: 7-11 minutes (build with --release mode is slow)
- TypeScript: 3-4 minutes
- Contracts: 30 seconds
- Security: 2-3 minutes

**Total:** ~5-10 minutes (not cumulative; most run in parallel)

**To Speed Up:**
- Use caching (cargo, npm, go mod already cached)
- Don't add new test suites without splitting jobs
- Split heavy jobs if any exceed 5 minutes

---

## 📝 When CI Passes ✅

Your code is safe to merge because:
- ✅ Compiles without errors (go build, cargo build)
- ✅ All unit tests pass (go test, cargo test, jest)
- ✅ Code formatted correctly (gofmt, cargo fmt)
- ✅ No obvious code quality issues (golangci-lint, clippy)
- ✅ API contracts are valid (OpenAPI, JSON schemas)
- ✅ No hardcoded secrets (gitleaks)

---

## 📚 Documentation Links

| Document | Purpose |
|----------|---------|
| [`.github/CI.md`](./.CI.md) | Detailed job descriptions + troubleshooting (500+ lines) |
| [`.github/BRANCH-PROTECTION.md`](./.BRANCH-PROTECTION.md) | GitHub setup guide for admins |
| [`.github/CODEOWNERS`](./.CODEOWNERS) | Code ownership + review assignments |
| [`.github/workflows/ci.yaml`](./.workflows/ci.yaml) | Workflow definition (source of truth) |
| [`../VERSIONING.md`](../VERSIONING.md) | Version strategy and release process |

---

## 🆘 Escalation Contacts

| Issue | Contact |
|-------|---------|
| 💡 Suggest new CI job | Open issue with details |
| 🚨 CI pipeline broken (all jobs failing) | Check `.github/CI.md#monitoring-ci-health` |
| 🔐 Secret exposed in repo | See `.github/BRANCH-PROTECTION.md#secret-remediation` **ASAP** |
| 🐛 Weird test failure | Reproduce locally per `.github/CI.md#local-ci-reproduction` |

---

## ✨ Pro Tips

1. **Reproduce CI locally before pushing:** `make build && make test && make lint`
2. **Watch CI results:** GitHub Actions tab or `gh run list --branch main --watch`
3. **Speed up feedback:** Push to feature branch first (no CI on draft), then create PR when ready
4. **Debugging:** Use `gh run logs <run-id>` to download full logs for offline analysis
5. **Skip CI (emergency only):** Commit message `[skip ci]` but **never** for code-only changes

---

**Last Updated:** 2024 | **Owner:** Architecture Team | **Next Review:** 2025-Q1
