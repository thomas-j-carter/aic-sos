# Security Quick Reference

**Status:** PHASE-0 Foundation ✓

## 1-Minute Overview

| Control | Blocks Merge? | How to Check | How to Fix |
|---------|---|---|---|
| **Secrets** (gitleaks) | ✓ YES | `gitleaks detect` | Remove secret, rotate credential |
| **Go CVEs** (nancy) | ✓ YES | `go mod graph \| nancy sleuth` | `go get -u package@version` |
| **Rust CVEs** (cargo audit) | ✓ YES | `cargo audit` | `cargo update package` |
| **Node CVEs** (npm audit) | ✓ YES | `npm audit --audit-level=moderate` | `npm update package` |
| **SBOM** (cyclonedx) | ⊘ NO | `./scripts/generate-sbom.sh` | Artifact generated auto |

## Common Workflows

### Before Committing

```bash
# Check for secrets
gitleaks detect --source .

# Check dependencies (from repo root)
cd services/control-plane && go mod graph | nancy sleuth
cd services/execution-plane && cargo audit
cd services/agent && cargo audit
cd apps/web && npm audit --audit-level=moderate
```

### If Secret Detected

```bash
# Immediately stop and undo
git reset HEAD~1

# Remove the secret, add to .gitignore
echo "*.key" >> .gitignore

# Commit again
git add -A && git commit -m "Remove secret, update gitignore"

# ROTATE THE CREDENTIAL (AWS, GitHub, Slack, etc.)
```

### If Vulnerability Found

```bash
# Read error message - note version to update
# Example: CVE-2025-1234 in gorm@v1.24.0 → Update to v1.25.0+

# Update dependency
go get -u gorm.io/gorm@v1.25.0

# Verify
go test ./...
git commit -m "fix: Update gorm to v1.25.0 (CVE-2025-1234)"
git push
```

### Generate SBOM Locally

```bash
# All
./scripts/generate-sbom.sh

# Go only
./scripts/generate-sbom.sh --go

# Scan with Grype
grype sbom:./sbom/SBOM-MANIFEST.json

# Clean up
./scripts/generate-sbom.sh --cleanup
```

## CI Security Jobs

| Job | Status | Output |
|-----|--------|--------|
| `security-gitleaks` | ✓ Blocking | ✗ FAIL if secrets detected |
| `security-dependencies` | ✓ Blocking | ✗ FAIL if CVEs found (nancy, cargo, npm) |
| `security-sbom` | ⊘ Warning | 📦 Uploads SBOM artifact (90-day retention) |

## Rules

- ✓ **ALWAYS** use `go get`, `cargo update`, `npm update` to fix CVEs
- ❌ **NEVER** commit secrets (database passwords, API keys, etc.)
- ❌ **NEVER** push without running local security checks
- ✓ **ALWAYS** rotate credentials if accidentally committed
- ⚠️ **BLOCKING** — Can't merge PR if security checks fail

## What Blocks Merge

1. ❌ Gitleaks detects credential
   - Fix: Remove secret, rotate credential

2. ❌ Nancy finds Go CVE
   - Fix: `go get -u package@version`

3. ❌ Cargo Audit finds Rust CVE
   - Fix: `cargo update package`

4. ❌ NPM Audit finds Node CVE (moderate+)
   - Fix: `npm update package`

## Need an Exception?

For High-severity CVEs that need 7+ days to fix:

1. Create GitHub issue: `[SECURITY] Exception: CVE-XXXX`
2. Document justification (breaking changes, no alternative, etc.)
3. Propose timeline
4. Get security lead approval (will whitelist temporarily)

## Further Reading

- **Full Policy:** See `docs/SECURITY.md`
- **CI Configuration:** See `.github/workflows/ci.yaml`
- **SBOM Generation:** See `scripts/generate-sbom.sh`
- **Reporting:** See `.github/SECURITY-INCIDENT.md` (coming soon)

## Tools at a Glance

```bash
# Manual vulnerability scan (no CI needed)
gitleaks detect --source .
go mod graph | nancy sleuth
cargo audit
npm audit

# Generate SBOM
./scripts/generate-sbom.sh

# View what's installed
go list -m all
cargo tree
npm list
```

## Severity → Response Time

| Severity | Time | Action |
|----------|------|--------|
| 🔴 Critical | NOW | Patch immediately, emergency release |
| 🟠 High | 24h | Emergency patch in next sprint |
| 🟡 Medium | 7d | Include in next scheduled update |
| 🟢 Low | 30d | Include in regular dependency update |

---

**Questions?** See `docs/SECURITY.md` or contact security lead.
