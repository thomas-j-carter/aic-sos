# Security Policy & Baseline Hygiene

**Status:** PHASE-0 Foundation ✓  
**Last Updated:** December 2025  
**Audience:** All developers, DevOps engineers, security reviewers

## Overview

This document describes the security baseline for the AI Workflow Governance Platform monorepo. It establishes fail-closed policies for secret scanning, dependency auditing, and Software Bill of Materials (SBOM) generation to prevent common supply-chain vulnerabilities.

**Core Principle:** Default to DENY — security controls are strict by default and relaxed only with explicit justification and approval.

## Table of Contents

1. [Secret Scanning (Gitleaks)](#secret-scanning-gitleaks)
2. [Dependency Scanning & Auditing](#dependency-scanning--auditing)
3. [Software Bill of Materials (SBOM)](#software-bill-of-materials-sbom)
4. [Handling Vulnerabilities](#handling-vulnerabilities)
5. [Security Controls in CI](#security-controls-in-ci)
6. [Developer Workflow](#developer-workflow)
7. [Runbook: Responding to Vulnerabilities](#runbook-responding-to-vulnerabilities)
8. [Compliance & Reporting](#compliance--reporting)
9. [FAQ](#faq)

---

## Secret Scanning (Gitleaks)

### Purpose
Detect accidentally committed secrets (API keys, credentials, tokens) before they reach main branch or are deployed.

### Implementation

**Tool:** `gitleaks` via GitHub Action  
**Configuration:** `.github/workflows/ci.yaml` → `security-gitleaks` job  
**Status:** ✓ **BLOCKING** — PRs with detected secrets cannot merge  
**Failure Mode:** FAIL (exit code 1) on any secret detected

### How It Works

1. **On every push to main or PR:**
   - Gitleaks scans the entire commit history for credential patterns
   - Uses built-in rules for:
     - Private keys (RSA, EC, PGP, SSH)
     - API tokens (GitHub, AWS, Slack, DataDog, etc.)
     - Database credentials
     - JWT tokens
     - Custom patterns

2. **Detection Logic:**
   - Entropy-based analysis (high randomness = likely secret)
   - Regex patterns (AWS_SECRET_ACCESS_KEY, etc.)
   - Historical repository analysis (finds previously committed secrets)

3. **Blocking:**
   - If secrets detected: ✗ FAIL CI
   - If no secrets: ✓ PASS CI
   - No override/continue-on-error

### What NOT to Commit

❌ **NEVER commit:**
- AWS Access Keys / Secret Keys
- Database passwords or connection strings
- API keys (GitHub, Slack, ServiceNow, etc.)
- Private SSH keys
- JWT tokens or refresh tokens
- Azure Storage Keys
- GCP Service Account JSON
- Twilio Auth tokens
- Cryptocurrency private keys

### If You Accidentally Commit a Secret

1. **Immediate Actions (< 5 minutes):**
   ```bash
   # DO NOT PUSH - stop immediately
   git reset HEAD~1  # Undo the commit
   # Add to .gitignore
   echo "sensitive-file.key" >> .gitignore
   git add .gitignore
   git commit -m "Add sensitive file to gitignore"
   ```

2. **If Already Pushed:**
   - Contact security team IMMEDIATELY
   - Rotate the exposed credential (AWS, GitHub, API, etc.)
   - File a security incident: [incident-form](./SECURITY-INCIDENT.md)
   - Do NOT attempt to hide with another commit (gitleaks will still find it)

### False Positives

Gitleaks occasionally flags non-secrets (example UUIDs, hashes). If you encounter a false positive:

```bash
# Verify it's a false positive
gitleaks detect --source . --verbose

# Add to .gitleaksignore if confirmed false positive
echo "example_uuid_pattern" >> .gitleaksignore
```

---

## Dependency Scanning & Auditing

### Purpose
Identify known vulnerabilities in third-party dependencies before they're deployed to production.

### Tools & Coverage

#### Go Services (control-plane, connector-gateway)
**Tool:** `nancy` (Sonatype Nexus OSS Index)  
**Command:** `go mod graph | nancy sleuth`  
**Status:** ✓ **BLOCKING** — Fails on any vulnerability  
**Severity Levels:** Critical, High, Medium reported

#### Rust Services (execution-plane, agent)
**Tool:** `cargo audit` (RustSec Advisory Database)  
**Command:** `cargo audit`  
**Status:** ✓ **BLOCKING** — Fails on any vulnerability  
**Sources:** RustSec, NVD, CVE databases

#### Node.js Services (web app)
**Tool:** `npm audit` (npm Security Audit)  
**Command:** `npm audit --audit-level=moderate`  
**Status:** ✓ **BLOCKING** — Fails on moderate+ vulnerabilities  
**Exclusions:** Low-severity (too noisy for web dependencies)

### How It Works

1. **On every PR to main:**
   - Nancy: Resolves Go module graph, checks against vulnerability database
   - Cargo audit: Scans Cargo.lock against RustSec database
   - NPM audit: Scans package-lock.json against npm database

2. **If Vulnerabilities Found:**
   - Lists CVE ID, CVSS score, affected package version, fix version
   - CI job fails → PR cannot merge without remediation
   - No continue-on-error (strict enforcement)

3. **Remediation Path:**
   ```bash
   # Go: Update dependency
   go get -u vulnerable-package@v1.2.3

   # Rust: Update Cargo.toml
   cargo update vulnerable-package

   # Node: Update package.json
   npm update vulnerable-package
   ```

### Handling Exceptions

**Critical:** Direct CVE fixes are required immediately  
**High:** Must fix within 7 days  
**Medium:** Must fix within 30 days  

For exceptions:
1. File a GitHub issue: `[SECURITY] Dependency Exception: <CVE>`
2. Document business justification
3. Plan remediation timeline
4. Get approval from security lead before merging (manual override)

---

## Software Bill of Materials (SBOM)

### Purpose
Generate a machine-readable inventory of all dependencies for:
- License compliance scanning
- Supply-chain attack detection
- Vulnerability correlation
- Procurement/vendor risk assessment

### Implementation

**Tool:** `cyclonedx-go`, `cyclonedx-npm`, `cargo-sbom`  
**Format:** CycloneDX 1.4 (JSON) — industry standard  
**Generated:** On every CI run  
**Artifacts:** Uploaded as GitHub Actions artifact (90-day retention)

### File Structure

```
sbom/
├── SBOM-MANIFEST.json      # Aggregated manifest with all services
├── go-sbom.json            # control-plane, connector-gateway dependencies
├── rust-sbom.json          # execution-plane, agent dependencies
├── node-sbom.json          # web app dependencies
├── go-deps.txt             # Raw Go dependency tree
├── rust-deps.txt           # Raw Rust dependency tree
└── node-deps.txt           # Raw npm dependency tree
```

### SBOM Structure (Example)

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "metadata": {
    "timestamp": "2025-12-18T15:30:00Z",
    "component": {
      "type": "application",
      "name": "control-plane",
      "version": "v0.1.0"
    },
    "properties": [
      {
        "name": "sbom:git-commit",
        "value": "abc123def456..."
      }
    ]
  },
  "components": [
    {
      "type": "library",
      "name": "gorm",
      "version": "1.25.0",
      "purl": "pkg:golang/gorm.io/gorm@v1.25.0"
    }
  ]
}
```

### How to View/Scan SBOM

**Local generation:**
```bash
make sbom              # Generate all SBOMs
./scripts/generate-sbom.sh --go      # Go only
./scripts/generate-sbom.sh --cleanup # Remove generated files
```

**Scan for vulnerabilities:**
```bash
# Using Grype (free, fast)
grype sbom:./sbom/SBOM-MANIFEST.json

# Using OWASP Dependency-Check
dependency-check --project MyApp --scan ./sbom

# Using Trivy
trivy sbom ./sbom/SBOM-MANIFEST.json
```

**Upload to supplier/customer:**
```bash
# Make SBOM available for audits
curl -X POST https://vendor-portal.example.com/upload \
  -F "file=@sbom/SBOM-MANIFEST.json"
```

### Lifecycle

- **Generated:** Every CI run (automatic)
- **Retention:** 90 days in GitHub Artifacts
- **Archival:** Manual export before artifact cleanup
- **Supply Chain:** Include in release notes and customer handoff

---

## Handling Vulnerabilities

### Vulnerability Severity Matrix

| Severity | Definition | Response Time | Action |
|----------|-----------|---|---|
| **Critical** | RCE, auth bypass, data exfiltration | **Immediate** | Patch or remove dependency immediately |
| **High** | DoS, privilege escalation | **24 hours** | Emergency patch or code workaround |
| **Medium** | Information disclosure, weak crypto | **7 days** | Scheduled fix in next sprint |
| **Low** | Non-exploitable edge case | **30 days** | Include in regular updates |

### Discovery Paths

**1. CI Detection** (automated)
   - Gitleaks, Nancy, Cargo Audit, NPM Audit fail on PR
   - Notification: Pull request status check
   - Remediation: Must fix before merge

**2. Security Scanning** (scheduled)
   - Dependency updates monitored (Dependabot, Renovate)
   - SBOM scanned against updated CVE databases
   - Notification: GitHub Issues + email

**3. External Reports**
   - Customer/vendor notification
   - Security researcher disclosure
   - Public CVE announcement
   - Notification: Email to security@company + Slack #security

### Remediation Process

```
Vulnerability Discovered
     ↓
[Severity Assessment]
     ↓
[File GitHub Issue] ← Tag: security, priority:critical
     ↓
[Patch/Update] ← Update dependency to fixed version
     ↓
[Verify Fix] ← CI passes (no vulns detected)
     ↓
[Deploy] ← Merge to main, release new version
     ↓
[Post-mortem] ← Document how it was missed, improve detection
```

### Example: Fixing a Critical CVE

```bash
# 1. See the error in CI
# ❌ CVE-2025-1234: RCE in gorm@v1.24.0

# 2. Create issue
gh issue create --title "[SECURITY] CVE-2025-1234: gorm RCE" \
  --label security,critical \
  --body "Update gorm to v1.25.0 or later"

# 3. Update dependency
cd services/control-plane
go get -u gorm.io/gorm@v1.25.0+

# 4. Verify
go mod verify
go test ./...

# 5. Commit
git commit -m "fix: Update gorm to v1.25.0 to address CVE-2025-1234"
git push

# 6. CI passes → Merge → Deploy
```

---

## Security Controls in CI

### Current Status

✓ = Blocking | ⊘ = Warning | - = Not implemented

| Control | Tool | Status | Runs On |
|---------|------|--------|---------|
| Secret Scanning | gitleaks | ✓ Blocking | Every push/PR |
| Go Dependencies | nancy | ✓ Blocking | Every push/PR |
| Rust Dependencies | cargo audit | ✓ Blocking | Every push/PR |
| Node Dependencies | npm audit | ✓ Blocking | Every push/PR |
| SBOM Generation | cyclonedx-* | ✓ Artifact | Every push/PR |
| Linting | golangci-lint, clippy, eslint | ✓ Blocking | Every push/PR |
| Unit Tests | go test, cargo test, npm test | ✓ Blocking | Every push/PR |
| Contract Validation | validate-contracts.sh | ✓ Blocking | Every push/PR |

### CI Jobs Dependency Graph

```
   ┌─ go-build ──────┐
   │                 ├─ go-test
   │                 └─ go-lint
   │
   ├─ rust-build ────┬─ rust-test
   │                 ├─ rust-fmt
   │                 └─ rust-clippy
   │
   ├─ ts-check ──────┬─ ts-test
   │
   ├─ contracts-validate
   │
   ├─ security-gitleaks
   ├─ security-dependencies
   └─ security-sbom
            ↓
        ci-status (all must succeed)
            ↓
       PR can merge ✓
```

---

## Developer Workflow

### Pre-Commit Check

Before pushing, run locally:

```bash
# Check for secrets
gitleaks detect --source .

# Check dependencies
cd services/control-plane && go mod tidy && go mod verify
cargo audit
npm audit
```

### During Development

1. **Update a dependency?**
   ```bash
   go get -u package@version
   # Wait for CI — vulnerability detected? Fix immediately
   ```

2. **Committed a secret by accident?**
   ```bash
   # STOP - don't push
   git reset HEAD~1
   echo "file.key" >> .gitignore
   git add .gitignore && git commit -m "gitignore"
   # Rotate the secret (e.g., regenerate AWS key)
   ```

3. **Check SBOM locally:**
   ```bash
   ./scripts/generate-sbom.sh
   grype sbom:./sbom/SBOM-MANIFEST.json
   ```

---

## Runbook: Responding to Vulnerabilities

### Scenario 1: Gitleaks Fails on PR (Secret Detected)

```bash
# 1. Don't panic - it didn't get to main
# 2. See what was detected
gitleaks detect --source . --verbose

# 3. Remove it
git reset HEAD~1
# Edit files to remove secret

# 4. Add to .gitignore
echo "*.key" >> .gitignore
echo "*.pem" >> .gitignore

# 5. Commit and push
git add -A && git commit -m "Remove secrets, update gitignore"

# 6. If secret was real (e.g., AWS key), rotate it immediately
# AWS: Delete access key, create new one
# GitHub: Invalidate PAT, create new one
# Slack: Revoke webhook, create new one
```

### Scenario 2: Nancy/Cargo Audit Finds CVE

```bash
# 1. Read the error message
# ❌ CVE-2025-1111 in package@v1.0.0
#    CVSS: 8.6 (High)
#    Fix: Update to v1.2.0+

# 2. Update the dependency
go get -u vulnerable-package@v1.2.0

# 3. Verify no new issues
go mod tidy
go mod verify
go test ./...

# 4. Commit and push
git commit -m "fix: Update package to v1.2.0 (CVE-2025-1111)"

# 5. CI should pass now
```

### Scenario 3: Exception Needed (Can't Update Yet)

```bash
# 1. Document justification
cat > docs/SECURITY-EXCEPTIONS.md << EOF
## CVE Exception: CVE-2025-1111

- Package: vulnerable-package v1.0.0
- CVE: CVE-2025-1111 (RCE)
- Severity: High
- Status: Awaiting upstream fix for breaking change
- Remediation: Update to v1.2.0 when available (Q1 2026)
- Approval: @security-lead

Justification: Upgrading v1.0.0 → v1.2.0 has breaking API changes.
Requires refactor of 3 services. Scheduled for Q1 2026.
EOF

# 2. Request manual review (contact security lead)
# They may whitelist the CVE temporarily

# 3. Plan fix
gh issue create --title "[SECURITY] Refactor for CVE-2025-1111 fix" \
  --label security,refactor \
  --milestone "Q1 2026"
```

### Scenario 4: SBOM Vulnerability Detected in Artifact

```bash
# 1. Download recent SBOM
gh run download <run-id> -n sbom

# 2. Scan with vulnerability database
grype sbom:./sbom/SBOM-MANIFEST.json

# 3. Cross-reference with known CVEs
# (grype will report matches from multiple sources)

# 4. Create security issue and follow Scenario 2
```

---

## Compliance & Reporting

### Release Requirements

**Before releasing to production:**

- [ ] No failed security checks in CI
- [ ] All vulnerabilities documented in `SECURITY-EXCEPTIONS.md`
- [ ] SBOM generated and signed
- [ ] Security review approval (for major releases)

### Audit Trail

All security events logged in:
- GitHub: Issue labels (#security), PR reviews
- CI Logs: GitHub Actions run logs (encrypted, 90-day retention)
- SBOM: Git commit sha, timestamp, operator recorded

### Reporting to Customers

**Provided on request:**
- SBOM (CycloneDX JSON)
- Security scan results
- Exception list with justifications
- Remediation timeline

---

## FAQ

**Q: What if I need to use a package with known CVEs?**  
A: File an exception with business justification (breaking changes, no alternative, etc.). Security lead reviews and may whitelist temporarily. Plan remediation timeline.

**Q: Can I disable gitleaks for a particular file?**  
A: No, but you can add false positives to `.gitleaksignore`. Never disable for actual secrets.

**Q: How often are SBOM artifacts cleaned up?**  
A: Every 90 days (configurable). Export/archive if needed for compliance.

**Q: What if a CVE is disclosed after a release?**  
A: Create security patch release immediately. Notify customers via security advisory. Update SBOM and redeploy.

**Q: Do I need to understand CycloneDX format?**  
A: Not typically — tools like Grype and Trivy parse it. But it's just JSON if you want to inspect.

**Q: What about Python dependencies (if added later)?**  
A: Add `pip-audit` tool to CI security-dependencies job. Same pattern as npm/go/rust.

---

## References

- [NIST Software Supply Chain Security](https://csrc.nist.gov/Projects/Supply-Chain-Risk-Management)
- [CycloneDX Specification](https://cyclonedx.org/)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [OSSIndex (Nancy)](https://ossindex.sonatype.org/)
- [RustSec Advisory Database](https://rustsec.org/)
- [NPM Security Best Practices](https://docs.npmjs.com/cli/v10/commands/npm-audit)

---

## Security Contact

For security issues or disclosures:
- Email: `security@company.example` (encrypted GPG preferred)
- Report format: `.github/SECURITY-INCIDENT.md`
- Response time: 24 hours for confirmed vulnerabilities

---

**Last Reviewed:** December 2025  
**Next Review:** June 2026 (or after major incident)  
**Approved By:** [Security Lead Name]
