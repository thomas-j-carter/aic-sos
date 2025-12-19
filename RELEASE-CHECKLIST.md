# Release Checklist

**Template for Phase 0 MVP Release Process**

Use this checklist before creating a release tag. Copy and fill out for each release.

---

## Release Information

- **Version:** `v_______` (e.g., v0.1.0)
- **Release Date:** `_______` (YYYY-MM-DD)
- **Release Owner:** `_______`
- **Slack Channel:** `#releases`

---

## Pre-Release Tasks (1–2 days before)

### Code Freeze
- [ ] All feature branches merged to `main`
- [ ] No WIP commits on `main`
- [ ] Commit log is clean and descriptive
- [ ] No uncommitted changes (`git status` is clean)

### Testing
- [ ] Unit tests pass: `make test` (all languages)
- [ ] Integration tests pass (if available)
- [ ] Manual smoke test on local stack:
  ```bash
  docker compose down
  docker compose up -d
  make build
  # Run quick manual test (create workflow, trigger run, check evidence)
  ```
- [ ] No flaky tests observed in CI

### Code Quality
- [ ] Linting passes: `make lint` (Go, Rust, TypeScript)
- [ ] All auto-format applied:
  - Go: `go fmt ./...`
  - Rust: `cargo fmt --all`
  - TS: `prettier --write` (if configured)
- [ ] No compiler warnings treated as errors
- [ ] No security warnings:
  - `gitleaks detect` (check for secrets)
  - `cargo audit` (Rust dependencies)
  - `npm audit` (Node dependencies)
  - `go list -json -m all | nancy sleuth` (Go dependencies, if available)

### Documentation
- [ ] `docs/START-HERE.md` reflects current workflow
- [ ] Architecture docs up to date (if changes made):
  - `docs/RFC-0001-architecture.md` (if scope changed)
  - `service-boundaries.md` (if service boundaries shifted)
  - `data/db-schema.md` (if schema changed)
- [ ] `.github/copilot-instructions.md` updated (if patterns changed)
- [ ] README.md accurately describes current state

---

## Version & Tag Preparation (Release Day)

### Update Version

```bash
# Check current version
./version.sh show

# Bump version (choose one)
./version.sh bump patch    # Bug fixes only
./version.sh bump minor    # New features
./version.sh bump major    # Breaking changes
```

- [ ] Version bumped and `VERSION` file updated
- [ ] Verify new version: `./version.sh show`

### Update Service Versions (if applicable)

- [ ] Sync `services/*/Cargo.toml` versions (if using sync script)
- [ ] Sync `apps/*/package.json` versions (if using sync script)
- [ ] Verify all sync'd correctly: `grep version services/*/Cargo.toml`

### Create Release Notes

Create file: `docs/releases/v{VERSION}.md`

```markdown
# Release v{VERSION}

**Release Date:** YYYY-MM-DD  
**Git Tag:** v{VERSION}  
**Compatibility:** [MVP phase / v0.x / v1.0+]

## Summary
[2–3 sentence summary of release focus]

## Features
- Feature 1: Description
- Feature 2: Description
- ...

## Bug Fixes
- Bug 1: Fixed ISSUE #123
- Bug 2: Fixed ISSUE #456
- ...

## Breaking Changes (if MAJOR version)
- **Change 1:** Old behavior → New behavior
  - Migration: How to update existing deployments

## Database Schema Changes
- Migration: `db/migrations/NNN_description.sql`
- Backward compatible: Yes/No
- Requires downtime: Yes/No (if downtime needed, document window)

## Deployment Instructions

### Prerequisites
- [ ] All services built and tested
- [ ] Database migrations reviewed (`make migrate --dry-run` if available)

### Steps
1. Pull latest main: `git pull origin main`
2. Verify version: `make version`
3. Build images: `docker build -t controlplane:v{VERSION} ./services/control-plane` (etc.)
4. Push to registry (if applicable): `docker push controlplane:v{VERSION}`
5. Update deployment manifests (Terraform/Helm/etc.)
6. Deploy to staging for final verification
7. Deploy to production

### Rollback Plan
- If critical issue detected post-release:
  1. Identify issue
  2. Create hotfix branch from `v{PREVIOUS-VERSION}` tag
  3. Merge to `main`
  4. Release as `v{VERSION}-hotfix.1`

## Contributors
- @person1: Feature X
- @person2: Bug fix Y
- ...

## Known Issues / Future Work
- Known issue 1 (open ticket: ISSUE #XXX)
- Planned for next release: Feature Z
```

- [ ] Release notes written and proof-read
- [ ] Check for typos, formatting, clarity

### Prepare Commits

```bash
# Stage changes
git add VERSION docs/releases/v{VERSION}.md [service versions if synced]

# Create release commit
git commit -m "Release v{VERSION}

- Summary of major changes
- Feature highlights
- Bug fixes

See docs/releases/v{VERSION}.md for full details."

# Verify commit looks good
git log -1 --stat
```

- [ ] Release commit created
- [ ] Commit message is descriptive and follows conventions
- [ ] `git log -1` shows expected files changed

---

## Tag & Push (Final Step)

### Create Git Tag

```bash
./version.sh tag
# Output should be:
# ✓ Created git tag: v{VERSION}
# To push: git push origin v{VERSION}
```

- [ ] Git tag created successfully
- [ ] Tag command output shows correct tag name

### Verify Tag

```bash
git show v{VERSION}
git tag -l v{VERSION}
```

- [ ] Tag points to correct commit
- [ ] Tag annotation message is clear

### Push to Remote

```bash
# Push main branch
git push origin main

# Push release tag
git push origin v{VERSION}
```

- [ ] Main branch pushed to origin
- [ ] Release tag pushed to origin
- [ ] CI/CD pipeline triggered on tag push (verify in GitHub Actions/GitLab CI)

---

## Post-Release Tasks

### Verify Release Build

- [ ] CI/CD pipeline completed successfully for release tag
- [ ] Docker images built and pushed to registry (if applicable)
- [ ] Release artifacts generated (if applicable)

### Create GitHub Release (if using GitHub)

**Option A: Manual**
1. Go to: `https://github.com/your-org/your-repo/releases`
2. Click "Draft a new release"
3. Tag: `v{VERSION}`
4. Title: `Release v{VERSION}`
5. Description: Copy from `docs/releases/v{VERSION}.md`
6. Mark as pre-release if `0.x.y` (MVP phase)
7. Click "Publish release"

**Option B: Automated (GitHub Actions)**
- CI automatically creates release when tag is pushed (if workflow configured)
- Verify release page: `https://github.com/your-org/your-repo/releases/tag/v{VERSION}`

- [ ] GitHub release page created/published
- [ ] Release notes are visible and formatted correctly
- [ ] Release is marked as pre-release (if applicable)

### Communicate Release

- [ ] Announce in Slack channel `#releases`:
  ```
  🚀 **Release v{VERSION}** is now live!
  
  📝 Release notes: [link to docs/releases/v{VERSION}.md or GitHub release]
  📦 Container images:
    - controlplane:v{VERSION}
    - execution-plane:v{VERSION}
    - connector-gateway:v{VERSION}
    - agent:v{VERSION}
  
  ✅ All CI checks passed
  
  @channel: Please update your deployments.
  ```
- [ ] Document release in team wiki/knowledge base
- [ ] Update roadmap/status docs if Phase changed

### Monitor Initial Deployment

- [ ] Alert team to watch logs for issues
- [ ] Monitor error rates in staging/canary (if applicable)
- [ ] Have rollback plan ready (previous version tag accessible)
- [ ] Check for reported issues within 1 hour post-release

---

## Post-Release Cleanup (optional, Phase 1+)

- [ ] Cherry-pick critical fixes to `release/v{MAJOR}.{MINOR}.x` branch (if using branches)
- [ ] Update `docs/releases/` index with new version
- [ ] Close completed tickets/milestones in issue tracker
- [ ] Schedule retrospective if any issues occurred

---

## Emergency Rollback

If a critical issue is discovered immediately after release:

```bash
# 1. Identify previous stable version
git tag -l | sort -V | tail -2

# 2. Checkout previous tag
git checkout v{PREVIOUS-VERSION}

# 3. Redeploy previous version
# [follow deployment steps from previous release notes]

# 4. Document incident
# [create incident report]

# 5. Create hotfix branch for root cause
git checkout -b fix/critical-issue-name main
# [implement fix]
# [test]
# [commit, push, create PR]

# 6. Once merged, create new patch release
./version.sh bump patch
# [follow release checklist again]
```

- [ ] Rollback decision made (after discussion with team)
- [ ] Previous version deployed
- [ ] Incident documented
- [ ] Root cause ticket created
- [ ] Team notified of rollback

---

## Sign-Off

**Release Owner:** _____________________ (name)  
**Date:** _____________________ (YYYY-MM-DD)  
**Approval:** _____________________ (Tech Lead or Release Manager)

---

## Template Copy (for next release)

```
## Release Information

- **Version:** `v_______`
- **Release Date:** `_______`
- **Release Owner:** `_______`
- **Slack Channel:** `#releases`

[ Copy full checklist above, starting from "Pre-Release Tasks" ]
```

---

**Last Updated:** 2025-12-18
