# Branch Protection Rules

This document describes the branch protection rules required for sustainable CI/CD on the main branch.

**⚠️ IMPORTANT:** These rules must be configured via GitHub web UI or GitHub API — they cannot be version-controlled in the repository. Only a repository administrator can enforce these rules.

---

## Overview

The `main` and `release/**` branches are protected by automated CI checks that block merges unless all required checks pass. This "fail-closed" policy ensures that only validated code reaches production.

---

## Protected Branches

### `main` (Default Branch)

**Purpose:** Production-ready code. All changes must pass CI validation before merge.

**Protection Rules:**
- Require status checks to pass before merging
- Dismiss stale pull request approvals when new commits are pushed
- Include administrators in restrictions

### `release/**` (Release Branches)

**Purpose:** Hot-fix branches for critical production issues.

**Protection Rules:** Same as `main`

---

## Required Status Checks

The following GitHub Actions checks **MUST** pass before a PR can be merged:

### Go Services

- `go-build` — Compilation check for control-plane and connector-gateway
- `go-test` — Unit tests and coverage for Go services
- `go-lint` — Code formatting and linting (gofmt, golangci-lint)

### Rust Services

- `rust-build` — Compilation check for execution-plane and agent (release mode)
- `rust-test` — Unit tests for Rust services
- `rust-fmt` — Code formatting compliance (cargo fmt)
- `rust-clippy` — Linting (clippy with warnings-as-errors)

### TypeScript/Node

- `ts-check` — TypeScript type checking (non-blocking for Phase 0)
- `ts-test` — Unit tests for web app (non-blocking for Phase 0)

### Contract Validation

- `contracts-validate` — OpenAPI spec and JSON schema validation

### Security Scanning

- `security-gitleaks` — Secret scanning (detects hardcoded credentials)
- `security-dependencies` — Dependency vulnerability audits

### Status Aggregation

- `ci-status` — Meta-check that verifies all critical jobs passed

---

## Enabling Branch Protection

### via GitHub Web UI

1. **Go to Repository Settings**
   - Navigate to `Settings` → `Branches`

2. **Add Branch Protection Rule**
   - Click "Add rule"
   - Pattern: `main` (or `release/**`)

3. **Configure Protection Settings**

   ```
   ✅ Require status checks to pass before merging
      - Search and select all required checks listed above
   
   ✅ Require branches to be up to date before merging
      - Ensures PR is built against latest main
   
   ✅ Dismiss stale pull request approvals when new commits are pushed
      - Re-requires review after code changes
   
   ✅ Include administrators
      - Blocks even admin merges if checks fail (fail-closed)
   ```

4. **Save Rule**
   - Click "Create" or "Save changes"

### via GitHub REST API

```bash
#!/bin/bash
OWNER="your-org"
REPO="your-repo"
GITHUB_TOKEN="your-token"

# Get the list of required check names from ci.yaml
CHECKS='"go-build", "go-test", "go-lint", "rust-build", "rust-test", "rust-fmt", "rust-clippy", "contracts-validate", "security-gitleaks", "security-dependencies"'

# Create branch protection rule
curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$OWNER/$REPO/branches/main/protection \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": ['"$CHECKS"']
    },
    "enforce_admins": true,
    "dismiss_stale_reviews": true,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true
    },
    "restrictions": null
  }'
```

---

## Handling CI Failures

### PR Author (Developer)

If CI fails on your PR:

1. **Review the failed check** — Click on the failing job in GitHub
2. **View the logs** — GitHub Actions shows detailed output
3. **Fix locally** — Follow the troubleshooting guide in [CI.md](./CI.md)
4. **Push fix** — CI automatically re-runs on new commits
5. **Verify all checks pass** — Green checkmark required before merge

### Repository Maintainers (Emergency Only)

If a critical issue blocks all PRs:

1. **Temporarily disable protection** (Settings → Branches)
2. **Merge the emergency fix**
3. **Re-enable protection immediately**
4. **Document the incident** (add entry to INCIDENTS.md)

---

## CI Troubleshooting

### Common Failures

**Go Build Failed**
- Check `go mod tidy` output — dependency mismatch?
- Verify Go version: 1.21+
- See [CI.md](./CI.md#go-troubleshooting)

**Rust Build Failed**
- Check `cargo update` output — version conflict?
- Verify Rust version: stable or newer
- See [CI.md](./CI.md#rust-troubleshooting)

**Secret Scanning (gitleaks) Failed**
- A secret was committed to the repo
- **Do not push the fix and hope it passes next time** — the secret is already in git history
- See [Remediation Guide](#secret-remediation) below

**Dependency Audit Failed**
- A vulnerability was detected in a transitive dependency
- Update the dependency version in Cargo.toml or package.json
- Run locally to verify the fix (see [CI.md](./CI.md))

### Secret Remediation

If gitleaks detects a secret:

1. **Do not merge the PR** — the secret is now in git history
2. **Immediately rotate the secret** — revoke tokens, reset passwords, etc.
3. **Remove the secret from all commits:**
   ```bash
   # Using git-filter-repo (recommended)
   git filter-repo --replace-text deletions.txt --force
   
   # OR manually:
   git revert <commit>
   git push -u origin <branch>
   ```
4. **Force-push to main** (after admin approval)
   ```bash
   git push --force origin main
   ```
5. **Notify security team** — add entry to risk-register.md

---

## Status Badge

Add this badge to your README.md to display CI status:

```markdown
[![CI](https://github.com/YOUR-ORG/YOUR-REPO/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/YOUR-ORG/YOUR-REPO/actions/workflows/ci.yaml)
```

---

## Updating Branch Protection Rules

### When to Update

- A new required check is added to `ci.yaml`
- A check needs to be made optional (non-blocking)
- The protection policy is tightened (e.g., require reviews)

### How to Update

1. **Update ci.yaml** — add/remove/modify the GitHub Actions workflow
2. **Update BRANCH-PROTECTION.md** — document the change
3. **Update GitHub** — add/remove the check from the branch protection rule (Settings UI or API)
4. **Test** — create a test PR to verify the new check runs

---

## Phase-0 vs Phase-1 Policies

### Phase 0 (Current)

- **Primary Goal:** Prevent obvious regressions (build failures, test failures, secrets)
- **Required Checks:** Go/Rust/Contracts/Secrets (strict)
- **Optional Checks:** TypeScript, dependency audits (non-blocking)
- **Human Reviews:** Not yet required (PR author responsibility)
- **Deployment:** Manual (Release Checklist)

### Phase 1 (Planned)

- **Code Review:** ≥2 approvals required (CODEOWNERS)
- **Test Coverage:** Minimum 70% required
- **Integration Tests:** Contract tests + cross-service validation
- **Security:** Additional SAST (SonarQube), SBOM generation
- **Deployment:** Automated on merged PRs (GitOps)

---

## Links

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [CI.md](./CI.md) — Workflow jobs and troubleshooting
- [CODEOWNERS](./CODEOWNERS) — Code review assignments
- [VERSIONING.md](../VERSIONING.md) — Version and tagging conventions
- [RELEASE-CHECKLIST.md](../RELEASE-CHECKLIST.md) — Pre-release validation

---

## Maintenance

Review branch protection rules quarterly:

- [ ] Check that all required status checks still exist in ci.yaml
- [ ] Review any branch protection overrides (admin bypasses)
- [ ] Update documentation if policies change
- [ ] Test by creating a test PR with intentional failures
