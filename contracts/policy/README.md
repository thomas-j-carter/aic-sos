
# Policy bundle schema & SemVer rules

## Bundle structure
A PolicyBundle is an immutable package that includes:
- Rego modules (OPA)
- data documents (allowed tool actions, caps, routing constraints)
- metadata: version, signature, created_at, compatibility

## Versioning rules
- SemVer: MAJOR.MINOR.PATCH
- MAJOR changes:
  - change enforcement defaults
  - change decision semantics
  - broaden tool write permissions by default
  - change retention/residency defaults
  - require explicit tenant adoption + ApprovalArtifact
- MINOR changes:
  - additive rules/features (off by default) and new optional constraints
- PATCH changes:
  - bug fixes, tightening permissions, docs, non-behavioral changes

## TTL and fail-closed
Execution PEP and Connector Gateway PEP MUST:
- refresh bundle at TTL (default 10 minutes; configurable 5–15)
- fail closed for external tool actions if bundle is stale beyond TTL
