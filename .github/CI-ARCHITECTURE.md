# PHASE-0 CI Pipeline: Visual Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GitHub Actions CI Pipeline                         │
│                     Automated Validation on main Branch                      │
└─────────────────────────────────────────────────────────────────────────────┘

TRIGGERS:
  ├─ Push to main
  ├─ Push to release/**
  └─ Pull Request against main/release/**

                              ▼ ▼ ▼ ▼ ▼

┌──────────────────────────────────────────────────────────────────────────────┐
│                           JOB EXECUTION (Parallelized)                       │
│                                                                              │
│  ┌─────────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐ │
│  │   GO SERVICES (4-6 min) │  │ RUST SERVICES (7-11) │  │  TS/NODE (3-4)  │ │
│  ├─────────────────────────┤  ├──────────────────────┤  ├─────────────────┤ │
│  │ ✅ go-build            │  │ ✅ rust-build       │  │ ⚠️  ts-check    │ │
│  │ ✅ go-test (w/ Pg+Rd)  │  │ ✅ rust-test        │  │ ⚠️  ts-test     │ │
│  │ ✅ go-lint             │  │ ✅ rust-fmt         │  │ (non-blocking)  │ │
│  │ (gofmt + golangci)     │  │ ✅ rust-clippy      │  │                 │ │
│  └─────────────────────────┘  └──────────────────────┘  └─────────────────┘ │
│                                                                              │
│  ┌────────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐ │
│  │CONTRACTS (30 sec)      │  │  SECURITY (2-3 min)  │  │    META (1 min) │ │
│  ├────────────────────────┤  ├──────────────────────┤  ├─────────────────┤ │
│  │ ✅ contracts-validate  │  │ ✅ gitleaks (block)  │  │ ✅ ci-status    │ │
│  │ - OpenAPI YAML         │  │ ✅ dependencies      │  │ (aggregator)    │ │
│  │ - Event JSON schemas   │  │   (non-blocking)     │  │                 │ │
│  │ - Policy Rego          │  │ - cargo audit        │  │ DECISION:       │ │
│  │                        │  │ - npm audit          │  │ ✅ PASS = MERGE │ │
│  │                        │  │ - nancy (Go)         │  │ ❌ FAIL = BLOCK │ │
│  └────────────────────────┘  └──────────────────────┘  └─────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

                              ▼ ▼ ▼ ▼ ▼

                    ┌────────────────────────────┐
                    │   All Jobs Complete?       │
                    ├────────────────────────────┤
                    │  YES → ci-status: SUCCESS  │
                    │        ✅ Merge Allowed    │
                    │                            │
                    │  NO → ci-status: FAILURE   │
                    │       ❌ Merge Blocked     │
                    └────────────────────────────┘


REQUIRED CHECKS (Block Merge if Failed):
═══════════════════════════════════════════

  Go Services (control-plane, connector-gateway)
  ├─ go-build          (Compilation check)
  ├─ go-test           (Unit tests + PostgreSQL + Redis)
  └─ go-lint           (Code formatting + golangci-lint + go mod)

  Rust Services (execution-plane, agent)
  ├─ rust-build        (Release mode compilation)
  ├─ rust-test         (Cargo test suite)
  ├─ rust-fmt          (Code formatting check)
  └─ rust-clippy       (Linting with warnings-as-errors)

  Contracts
  └─ contracts-validate (OpenAPI + JSON schema validation)

  Security (Critical)
  └─ security-gitleaks  (Hardcoded secrets detection)

  Meta-Check
  └─ ci-status          (Aggregates all required checks)


OPTIONAL CHECKS (Warning Only, Non-Blocking):
═════════════════════════════════════════════════

  TypeScript/Node (apps/web)
  ├─ ts-check          (TypeScript type checking + ESLint)
  └─ ts-test           (Jest unit tests)

  Security (Non-Critical)
  └─ security-dependencies (cargo audit + npm audit + nancy)


TIMELINE:
═════════

  Push Code    → GitHub detects change
       ▼
  Workflow triggered → All 12 jobs start in parallel
       ▼
  ~5-10 minutes    → Jobs complete (most parallelized)
       ▼
  ci-status runs   → Final aggregation check
       ▼
  Success? ✅      → Green checkmark on PR
            └─ PR can merge if reviews approved
       ▼
  Failure? ❌      → Red X on PR
            └─ PR cannot merge, must fix


BRANCH PROTECTION ENFORCEMENT:
═══════════════════════════════

  Repository Admin Setup (One-time):
  ┌────────────────────────────────────────────────┐
  │ Settings → Branches → Add Rule                 │
  │ ├─ Pattern: main                               │
  │ ├─ ✅ Require status checks to pass            │
  │ ├─ ✅ Required checks:                          │
  │ │   go-build, go-test, go-lint                 │
  │ │   rust-build, rust-test, rust-fmt, -clippy   │
  │ │   contracts-validate, security-gitleaks      │
  │ ├─ ✅ Require branches up to date              │
  │ ├─ ✅ Dismiss stale reviews on push            │
  │ └─ ✅ Include administrators                    │
  └────────────────────────────────────────────────┘
          ▼
  Result: Fail-closed enforcement
          └─ No code merges to main without passing CI
          └─ Even admins can't bypass (include admins = true)


FAIL SCENARIOS:
════════════════

  Scenario 1: Code Syntax Error
  ┌─────────────────────────────────────────────────┐
  │ Author: push code with missing import          │
  │ go-build: ❌ FAILS (undefined symbol)           │
  │ Result: ci-status blocks merge                  │
  │ Fix: go get <package>, git push                 │
  │ Re-run: CI auto-triggers on new commit          │
  └─────────────────────────────────────────────────┘

  Scenario 2: Test Failure
  ┌─────────────────────────────────────────────────┐
  │ Author: push code with test assertion failure   │
  │ go-test / rust-test: ❌ FAILS                   │
  │ Result: ci-status blocks merge                  │
  │ Fix: Debug locally, fix code, git push          │
  └─────────────────────────────────────────────────┘

  Scenario 3: Secret Committed (CRITICAL)
  ┌─────────────────────────────────────────────────┐
  │ Author: accidentally commits GITHUB_TOKEN       │
  │ gitleaks: ❌ FAILS (secret pattern detected)    │
  │ Result: BLOCKS merge immediately                │
  │ Status: 🔴 CRITICAL - secret now in history    │
  │ Fix: 1. Revoke secret in GitHub                 │
  │      2. Use git-filter-repo to remove from hist │
  │      3. Force-push main (admin override)        │
  │      4. Document in risk-register.md            │
  └─────────────────────────────────────────────────┘

  Scenario 4: Dependency Vulnerability (Non-blocking)
  ┌─────────────────────────────────────────────────┐
  │ Security-dependencies finds CVE in transitive   │
  │ dependency (e.g., lodash 4.17.20 → 4.17.21)     │
  │ security-dependencies: ⚠️ warns                  │
  │ Result: Can still merge (non-blocking Phase 0)  │
  │ Action: Update dependency in next PR            │
  │ Phase 1: Will become blocking                   │
  └─────────────────────────────────────────────────┘


KEY FILES:
══════════

  Workflow Definition
  └─ .github/workflows/ci.yaml            (500+ lines, source of truth)

  Configuration Guides
  ├─ .github/BRANCH-PROTECTION.md         (GitHub admin setup + API script)
  ├─ .github/CODEOWNERS                   (Code ownership + review routing)
  └─ .github/CODEOWNERS                   (To be updated with team names)

  Documentation
  ├─ .github/CI.md                        (700+ line deep-dive guide)
  ├─ .github/CI-QUICK-REFERENCE.md        (One-page lookup)
  └─ .github/CI-DELIVERY-SUMMARY.md       (This implementation details)

  Developer Commands
  └─ Makefile targets:
     ├─ make build                        (compile all services)
     ├─ make test                         (run all unit tests)
     ├─ make lint                         (run all linters)
     └─ make smoke-test                   (validate environment)


PHASE-0 COMPLETION:
═══════════════════

  ✅ Unpack scaffold into real repo root
  ✅ Define versioning + release naming convention
  ✅ Local developer environment (make dev)
  ✅ CI pipeline on main branch                    ← THIS DELIVERY
  ⏳ "Contracts as truth" workflow
  ⏳ Baseline security hygiene

  EXIT GATE SUCCESS CRITERIA:
  ├─ New engineer can run: make dev
  ├─ Smoke test passes: ./smoke-test.sh
  ├─ Push code to feature branch
  ├─ CI validates automatically
  ├─ All required checks pass ✅
  └─ PR can merge to main


NEXT STEPS:
═══════════

  For Repository Admins:
  1. Go to repo Settings → Branches
  2. Create rule for main branch
  3. Add all required status checks
  4. Save and test with sample PR

  For Developers:
  1. Create feature branch
  2. Make code changes
  3. Push to GitHub
  4. Watch CI jobs run (Checks tab)
  5. Fix any failures per .github/CI.md
  6. Merge when all checks pass ✅

  For Future Phases:
  - Phase 1: Add code review requirement (CODEOWNERS)
  - Phase 1: Add test coverage threshold (70%+)
  - Phase 1: Add integration tests
  - Phase 2: Add SAST (SonarQube, tfsec, kubesec)
  - Phase 3: Automated deployment (GitOps on merge)
```

---

## Runtime Breakdown

```
Jobs that run in PARALLEL (not cumulative):

┌──────────────────────────────────────────────────────────┐
│ Time →                                                   │
│ 0   1    2    3    4    5    6    7    8    9    10      │
├──────────────────────────────────────────────────────────┤
│ [go-build ────][go-test ──────────][go-lint ──]         │ (4-6 min)
│ [rust-build ─────────][rust-test ────][rust-fmt ─]      │ (7-9 min)
│ [rust-clippy ──────────────]                             │ (7-9 min)
│ [ts-check ───────][ts-test ────────]                     │ (3-4 min)
│ [contracts ─]                                            │ (30 sec)
│ [gitleaks ─]                                             │ (30 sec)
│ [security-deps ──────────]                               │ (2-3 min)
│ [ci-status ──────────────────────────────────────]       │ (1 min)
└──────────────────────────────────────────────────────────┘
  0   1    2    3    4    5    6    7    8    9    10 minutes

CRITICAL PATH (longest job):
  rust-build + rust-clippy = ~7-9 minutes
  Then: ci-status aggregation = ~1 minute
  TOTAL: ~8-10 minutes (actual user wait time)

Non-critical path (can take longer without impact):
  - TypeScript checks (non-blocking Phase 0)
  - Dependency audits (non-blocking Phase 0)
```

---

## Success Indicators ✅

When CI passes on your PR, you'll see:

```
✅ go-build      Success      completed in 1m
✅ go-test       Success      completed in 2m 45s (+ codecov upload)
✅ go-lint       Success      completed in 1m 30s
✅ rust-build    Success      completed in 4m 20s
✅ rust-test     Success      completed in 2m 30s
✅ rust-fmt      Success      completed in 20s
✅ rust-clippy   Success      completed in 2m 50s
⚠️  ts-check     Success      completed in 1m (non-blocking)
⚠️  ts-test      Success      completed in 2m (non-blocking)
✅ contracts-validate Success  completed in 15s
✅ security-gitleaks Success   completed in 25s
⚠️  security-deps Success      completed in 2m (non-blocking)
✅ ci-status     Success      All required checks passed

→ Merge button becomes available (if reviews approved)
```

---

## Troubleshooting Decision Tree

```
                         ❌ CI Failed
                              │
                  ┌───────────┴───────────┐
                  │                       │
              [Which Job?]          [Multiple Jobs?]
              │                          │
         ┌────┴─────┬─────────┬─────┐   │ → Likely environment issue
         │           │         │     │   │
       Go           Rust       TS  Contracts/Sec  Fix infrastructure:
         │           │         │     │     └─ make dev-up
         │           │         │     │     └─ docker ps
         │           │         │     │     └─ Check .env
         │           │         │     │
    .github/CI.md#go-.github/CI.-CI.md#  .github/CI.md#
    troubleshoot  md#rust      typescript  contract

       Read error message carefully:
       Search for exact error string in docs
       Follow provided fix commands
       Reproduce locally with make build/test/lint
       Push fix and CI auto-re-runs
```

---

**Key Principle:** Fail-closed CI enforcement prevents bad code from reaching production while fast feedback loop (5-10 min) keeps developers productive.
