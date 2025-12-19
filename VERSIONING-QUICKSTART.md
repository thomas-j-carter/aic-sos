# Versioning Quick Start

**See also:** `VERSIONING.md` (comprehensive reference) and `RELEASE-CHECKLIST.md` (full DoD)

---

## Files Created

1. **`VERSION`** — Single source of truth for platform version (currently: 0.1.0)
2. **`version.sh`** — Version management helper script
3. **`VERSIONING.md`** — Complete versioning and release strategy
4. **`RELEASE-CHECKLIST.md`** — Definition of Done for releases
5. **`Makefile`** — Updated with version targets (make version, make version-bump-*, make version-tag)

---

## Quick Commands

```bash
# Show current version
./version.sh show
# or: make version

# Bump patch (0.1.0 → 0.1.1 for bug fixes)
./version.sh bump patch

# Bump minor (0.1.0 → 0.2.0 for new features)
./version.sh bump minor

# Bump major (0.1.0 → 1.0.0 for breaking changes)
./version.sh bump major

# Show Docker component tags
./version.sh tags
# or: make version-tags

# Create git tag (after version is bumped + committed)
./version.sh tag
# or: make version-tag
```

---

## Typical Release Workflow

### Step 1: Decide Version Bump Type

- **Patch** (0.1.0 → 0.1.1): Bug fixes only
- **Minor** (0.1.0 → 0.2.0): New features, backward-compatible
- **Major** (0.1.0 → 1.0.0): Breaking changes

### Step 2: Bump Version

```bash
./version.sh bump minor
# Output: Bumping minor: 0.1.0 → 0.2.0
```

### Step 3: Create Release Notes

Create file: `docs/releases/v0.2.0.md` with:
- Features
- Bug fixes
- Breaking changes (if any)
- Deployment instructions

### Step 4: Commit & Tag

```bash
git add VERSION docs/releases/v0.2.0.md
git commit -m "Release v0.2.0"

./version.sh tag
# Output: ✓ Created git tag: v0.2.0
```

### Step 5: Push & Announce

```bash
git push origin main
git push origin v0.2.0
```

---

## Component Docker Tags

When you bump the version, all services get the same tag:

```
controlplane:v0.2.0
execution-plane:v0.2.0
connector-gateway:v0.2.0
agent:v0.2.0
web:v0.2.0
```

Use in Makefile/Dockerfile:

```makefile
VERSION := $(shell cat VERSION | tr -d '\n' | tr -d ' ')

docker-build-control-plane:
	docker build -t controlplane:v$(VERSION) ./services/control-plane
```

---

## Semantic Versioning Rules

| Bump Type | When to Use | Example |
|-----------|------------|---------|
| **PATCH** | Bug fixes only | 0.1.0 → 0.1.1 |
| **MINOR** | New features (backward-compatible) | 0.1.0 → 0.2.0 |
| **MAJOR** | Breaking changes (API, schema, database) | 0.1.0 → 1.0.0 |

**During MVP (v0.x.y):** Minor versions may have breaking changes (still iterating).  
**At v1.0.0:** Backward-compatibility commitment begins.

---

## Integration with CI/CD

### Manual Git Tag Workflow

```bash
# 1. Make changes and commit
git add ...
git commit -m "Feature X"

# 2. Bump version
./version.sh bump minor

# 3. Commit version bump
git add VERSION
git commit -m "Release v0.2.0"

# 4. Create tag
./version.sh tag

# 5. Push all
git push origin main v0.2.0
```

### Automated Release (Phase 1+)

GitHub Actions workflow can automate:
- Version bump on workflow dispatch
- Commit + tag creation
- GitHub Release creation with notes

See `VERSIONING.md` § "CI/CD Integration" for example workflow.

---

## Troubleshooting

### "Tag already exists"

```bash
git tag -d v0.1.0       # Delete local tag
git push origin -d v0.1.0  # Delete remote tag (if pushed by mistake)
./version.sh tag        # Create tag again
```

### Need to release patch for old version

```bash
# Create release branch from old tag
git checkout -b release/0.1.x v0.1.0

# Bump patch
./version.sh bump patch  # 0.1.0 → 0.1.1

# Commit & tag
git add VERSION
git commit -m "Hotfix: 0.1.1"
./version.sh tag

# Push
git push origin release/0.1.x v0.1.1
```

---

## Definition of Done (Release)

Before tagging a release, ensure:

✓ All tests pass (`make test`)  
✓ Code linted (`make lint`)  
✓ No security warnings (gitleaks, cargo audit, npm audit)  
✓ Documentation updated (`docs/START-HERE.md`, architecture docs)  
✓ Release notes written (`docs/releases/v{VERSION}.md`)  
✓ Version bumped (`./version.sh bump <type>`)  
✓ Commit created (`git commit -m "Release v{VERSION}"`)  
✓ Tag created (`./version.sh tag`)  
✓ Pushed to remote (`git push origin main v{VERSION}`)  

See `RELEASE-CHECKLIST.md` for full checklist.

---

## FAQ

**Q: Can I revert a version bump?**  
A: Yes, before tagging: `git checkout VERSION && ./version.sh set 0.1.0`

**Q: What if I pushed a version bump but haven't tagged yet?**  
A: Revert the commit: `git revert HEAD`, then repeat the workflow.

**Q: Should I sync version to Cargo.toml/package.json?**  
A: Optional. The root `VERSION` is the source of truth. See `VERSIONING.md` § "Updating Service Versions" for sync script if desired (Phase 1+ feature).

**Q: How do we track schema versions separately?**  
A: Use `db/SCHEMA_VERSION` file. See `VERSIONING.md` § "Database Schema Versioning".

---

**For complete details, see:**
- `VERSIONING.md` — comprehensive versioning strategy
- `RELEASE-CHECKLIST.md` — full release process and DoD
- `Makefile` — make targets for version management

**Last Updated:** 2025-12-18
