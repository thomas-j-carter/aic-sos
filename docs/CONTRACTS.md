# Contracts as Truth Workflow

**Status:** PHASE-0 Foundational Pattern  
**Version:** 0.1.0  
**Owner:** Architecture Team

---

## Overview

The **"Contracts as Truth"** workflow treats OpenAPI specs, JSON schemas, and connector manifests as the single source of truth for API contracts. Changes to contracts automatically trigger code generation, ensuring that your API definitions, client code, and server stubs are always in sync.

### Key Principle

> **Write contracts first, generate code second.** Never commit hand-written stubs that contradict the contract.

---

## What Are Contracts?

### 1. OpenAPI Specification (`contracts/openapi/openapi.yaml`)

The primary REST API contract defining:
- All HTTP endpoints (`/v1/tenants`, `/v1/workflows`, etc.)
- Request/response schemas
- Authentication requirements
- Error responses

**Single source of truth for:**
- Go server route handlers
- TypeScript/React API client types
- API documentation

### 2. Event Schemas (`contracts/events/*.schema.json`)

JSON Schema definitions for domain events:
- `run.completed.v1.schema.json` — Workflow run finished
- `approval.required.v1.schema.json` — Manual approval needed
- `policy.denied.v1.schema.json` — Policy blocked action
- `incident.created.v1.schema.json` — New incident from ITSM
- `connector.scope_changed.v1.schema.json` — Connector permissions updated

**Single source of truth for:**
- Event validation in services
- TypeScript event types
- Producer/consumer contract validation

### 3. Connector Manifests (`contracts/connectors/{id}/manifest.yaml`)

YAML definitions for integrations:
- `contracts/connectors/github/manifest.yaml`
- `contracts/connectors/servicenow/manifest.yaml`
- `contracts/connectors/slack/manifest.yaml`

**Define:**
- Connector ID, version, display name
- Authentication type (OAuth2, API Key, etc.)
- Tool actions (what the connector can do)
- Required scopes for each action

**Single source of truth for:**
- Available connectors in the system
- Tool action registry
- Scope requirements for policy evaluation

### 4. Policy Rules (`contracts/policy/policy.rego`)

OPA/Rego rules defining governance:
- Allowlisted tool actions (safe by default)
- Reversible writes (don't require HITL)
- High-risk actions (require approval)
- Scope requirement rules

**Single source of truth for:**
- Policy simulation logic
- Deny-by-default enforcement
- Audit rule definitions

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────┐
│ Developer updates contract                              │
│ (e.g., adds new endpoint to openapi.yaml)               │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ make contracts (local)                                  │
│ ├─ Validate OpenAPI spec syntax                         │
│ ├─ Validate JSON schema syntax                          │
│ ├─ Generate Go server stubs                             │
│ ├─ Generate TypeScript client types                     │
│ ├─ Generate event validators                            │
│ └─ Generate connector loaders                           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Developer commits:                                      │
│ ├─ Contract files (openapi.yaml, *.schema.json)         │
│ ├─ Generated stubs (marked "Code generated")            │
│ └─ Implementation changes (handler code, etc.)          │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ CI: contracts-validate job                              │
│ ├─ Validate all contracts                               │
│ ├─ Regenerate stubs                                     │
│ ├─ Check all generated files are committed              │
│ └─ BLOCKING: PR cannot merge if validation fails        │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ ✅ All checks pass → PR can merge                        │
│ Contracts + generated code committed together           │
└─────────────────────────────────────────────────────────┘
```

---

## How to Use

### 1. Update a Contract

**Scenario:** Add a new endpoint to the API

```yaml
# contracts/openapi/openapi.yaml
paths:
  /v1/workflows/{workflow_id}/versions:
    get:
      summary: List workflow versions
      parameters:
        - in: path
          name: workflow_id
          required: true
          schema: { type: string }
      responses:
        "200":
          description: List of versions
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/WorkflowVersion'
```

### 2. Validate & Generate Locally

```bash
# Validate contract syntax
make contracts-validate

# OR validate + regenerate stubs
make contracts

# View what changed
git diff contracts/openapi/openapi.yaml
git diff services/*/generated/
git diff apps/web/generated/

# Review generated files before committing
# (They're marked "Code generated by openapi-generator")
```

### 3. Implement Handler Code

```go
// services/control-plane/handler.go
// The handler function signature is now generated and validated against the contract

func (h *Handler) ListWorkflowVersions(w http.ResponseWriter, r *http.Request) {
  workflowID := chi.URLParam(r, "workflow_id")
  
  // Your implementation here
  // Type safety guaranteed by generated types
  versions, err := h.store.ListWorkflowVersions(ctx, workflowID)
  if err != nil {
    http.Error(w, "not found", http.StatusNotFound)
    return
  }
  
  w.Header().Set("Content-Type", "application/json")
  json.NewEncoder(w).Encode(versions)
}
```

### 4. Commit Everything

```bash
# Stage contracts and generated code
git add contracts/openapi/openapi.yaml
git add services/control-plane/generated/
git add apps/web/generated/

# Stage implementation
git add services/control-plane/handler.go

# Commit together (contracts + stubs + impl)
git commit -m "feat: add workflow versions endpoint

- Add /v1/workflows/{id}/versions GET endpoint
- Generate Go server stubs and TS client types
- Implement handler in control-plane service

Implements #123"
```

### 5. Push to GitHub

```bash
git push origin my-feature

# GitHub Actions automatically:
# ✅ contracts-validate job runs
# ✅ Validates all contracts
# ✅ Regenerates stubs
# ✅ Ensures no uncommitted generated files
# ✅ PR can merge if all checks pass
```

---

## Supported Contract Types & Generation

### OpenAPI → Code Generation

**Input:** `contracts/openapi/openapi.yaml`

| Target | Tool | Output | Use Case |
|--------|------|--------|----------|
| **Go Server** | openapi-generator (go-server) | `services/*/generated/` | Route handlers, request/response types |
| **TypeScript Client** | openapi-generator (typescript-fetch) | `apps/web/generated/` | API client, types, fetch bindings |

**What gets generated:**
- ✅ HTTP method stubs (POST, GET, PUT, DELETE)
- ✅ Request/response type definitions
- ✅ Path parameter validation
- ✅ Query parameter parsing
- ❌ Business logic (you write this)
- ❌ Database queries (you write this)

### JSON Schemas → Validators

**Input:** `contracts/events/*.schema.json`

**Generated:**
- TypeScript validator (`contracts/generated/validators/events.ts`) using ajv
- Go validator (`contracts/generated/validators/events.go`) using gojsonschema

**Use in code:**
```typescript
// TypeScript
import { validateEvent } from './generated/validators/events';

const valid = validateEvent('run.completed.v1', eventData);
```

```go
// Go
validator, _ := validators.NewEventValidator()
isValid, err := validator.Validate("run.completed.v1", eventBytes)
```

### Connector Manifests → Loaders

**Input:** `contracts/connectors/{id}/manifest.yaml`

**Generated:**
- TypeScript loader (`contracts/generated/connectors/load.ts`)
- Go loader (`contracts/generated/connectors/load.go`)

**Use in code:**
```typescript
import { getConnector, getToolAction } from './generated/connectors/load';

const github = getConnector('github');
const action = getToolAction('github', 'github.get_pull_request');
```

---

## Make Targets

### `make contracts`

**Validates ALL contracts + regenerates stubs (full workflow)**

```bash
$ make contracts

Validating contract files...

1. OpenAPI Specification
✓ OpenAPI specification valid

2. Event JSON Schemas
✓ approval.required.v1.schema.json
✓ connector.scope_changed.v1.schema.json
...

3. Connector Manifests
✓ github manifest has required fields
...

Generating contract stubs...
→ services/control-plane/generated/ (OpenAPI server stubs)
→ apps/web/generated/ (OpenAPI client types + fetch client)
→ contracts/generated/validators/events.ts
→ contracts/generated/connectors/load.ts

✓ All contracts validated and stubs regenerated

Check git diff to see generated changes:
  git diff services/ apps/
```

### `make contracts-validate`

**Validates contracts only (no generation)**

```bash
$ make contracts-validate

Validating OpenAPI spec...
Validating JSON schemas...
Validating connector manifests...
Validating policy rules...

✓ All contract validations passed
```

### `make contracts-generate`

**Regenerate stubs only (skips validation)**

```bash
$ make contracts-generate

Generating contract stubs...
→ services/control-plane/generated/ (OpenAPI server stubs)
→ apps/web/generated/ (OpenAPI client types + fetch client)
...
```

### `make contracts-clean`

**Remove all generated files**

```bash
$ make contracts-clean

Removing generated contract files...
✓ Generated files removed
Run 'make contracts' to regenerate
```

---

## In CI: contracts-validate Job

The GitHub Actions `contracts-validate` job:

1. **Validates** all contracts (OpenAPI, JSON schemas, manifests)
2. **Generates** fresh stubs from contracts
3. **Compares** generated stubs to committed versions
4. **Fails PR** if any uncommitted generated files detected

**Why?** Ensures contracts and generated code never drift. If a developer updates a contract but forgets to regenerate stubs, CI catches it.

```yaml
# From .github/workflows/ci.yaml

contracts-validate:
  name: 'Contracts: Validate & Generate'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Validate contracts
      run: ./scripts/validate-contracts.sh

    - name: Generate contract stubs
      run: ./scripts/generate-contracts.sh

    - name: Check for uncommitted generated files
      run: |
        # Fail if git status shows differences in generated files
        if [ -n "$(git status --porcelain services/*/generated)" ]; then
          echo "⚠ Generated files differ from committed versions"
          git diff --name-only
          exit 1  # Phase 1: enforce. Phase 0: warning
        fi
```

---

## Troubleshooting

### "OpenAPI specification invalid"

**Cause:** YAML syntax error or missing required fields

**Fix:**
```bash
# Validate locally
swagger-cli validate contracts/openapi/openapi.yaml

# Common issues:
# - Indentation (use 2 spaces, not tabs)
# - Missing "description:" field (required)
# - Invalid $ref syntax (must start with #/)
# - Cyclic references

# Edit the file
nano contracts/openapi/openapi.yaml

# Validate again
make contracts-validate
```

### "JSON schema invalid"

**Cause:** Invalid JSON syntax or schema structure

**Fix:**
```bash
# Validate with jq first
jq . contracts/events/my-event.schema.json

# If that fails, JSON syntax is broken
# Common issues:
# - Missing comma between properties
# - Unquoted keys
# - Trailing commas

# Then validate schema
ajv validate -s contracts/events/my-event.schema.json
```

### "Generated files differ from committed"

**Cause:** Contracts updated but stubs not regenerated

**Fix:**
```bash
# Regenerate stubs
make contracts

# Review changes
git diff services/*/generated apps/*/generated

# Commit generated files
git add services/*/generated apps/*/generated
git commit -m "chore: regenerate contract stubs after contract updates"
```

### openapi-generator not found

**Cause:** Tools not installed globally

**Fix (Local):**
```bash
npm install -g @openapitools/openapi-generator-cli

# Or use Docker:
docker run --rm -v ${PWD}:/local openapitools/openapi-generator-cli \
  generate -i /local/contracts/openapi/openapi.yaml \
  -g go-server -o /local/services/control-plane/generated/
```

**Fix (CI):** The workflow handles installation automatically:
```yaml
- run: npm install -g @openapitools/openapi-generator-cli
```

---

## Best Practices

### 1. Contract-First Development

Write the contract **before** implementing:

```bash
# 1. Add endpoint to OpenAPI spec
nano contracts/openapi/openapi.yaml

# 2. Validate & generate
make contracts

# 3. Implement handler (types already exist!)
nano services/control-plane/handler.go

# 4. Commit contracts + stubs + impl together
git add contracts/ services/*/generated/ services/control-plane/handler.go
git commit -m "feat: new endpoint"
```

### 2. Never Edit Generated Files Directly

Generated files have headers:

```go
// Code generated by openapi-generator. DO NOT EDIT.
```

**Why?** Your edits will be overwritten on next generation. Edit the contract instead.

```bash
# ❌ WRONG: Edit generated file
nano services/control-plane/generated/models.go

# ✅ RIGHT: Edit contract
nano contracts/openapi/openapi.yaml

# ✅ RIGHT: Edit handler logic
nano services/control-plane/handler.go
```

### 3. Version Your Contracts

Use semantic versioning in contract files:

```json
// contracts/events/my-event.v1.schema.json
{
  "properties": {
    "event_version": {
      "const": 1,
      "minimum": 1
    }
  }
}
```

This enables:
- Multiple schema versions (v1, v2, v3)
- Backwards compatibility
- Smooth migrations

### 4. Validate Before Commit

Always run validation locally before pushing:

```bash
make contracts-validate
make contracts-generate

# If anything changed, commit the changes
git diff contracts/ services/*/generated

# Then push
git push
```

### 5. Document Contract Changes

When modifying OpenAPI spec, explain the change:

```bash
git commit -m "feat: add workflow versions endpoint

Modified contracts:
  - Added GET /v1/workflows/{id}/versions endpoint
  - Added WorkflowVersion schema

Generated:
  - Updated Go server stubs
  - Updated TypeScript client types

Breaking changes: None
Migration path: Additive, backwards compatible"
```

---

## Phase Roadmap

### Phase 0 (Current)

- ✅ Basic validation (OpenAPI, JSON schemas, manifests)
- ✅ Code generation (Go, TypeScript)
- ✅ Committed stubs alongside contracts
- ⚠️ Uncommitted generated files = warning (not blocking)

### Phase 1 (Next)

- [ ] Enforce committed stubs (blocking on CI failure)
- [ ] Contract versioning (support v1, v2, v3 side-by-side)
- [ ] Event schema migration tooling
- [ ] GraphQL schema support (in addition to OpenAPI)
- [ ] gRPC proto generation
- [ ] Rust code generation (from OpenAPI)

### Phase 2 (Future)

- [ ] Automated API changelog generation
- [ ] Contract compatibility checker (warn on breaking changes)
- [ ] Consumer/producer contract testing
- [ ] SDK generation (Python, Go, Rust clients)
- [ ] Web-based contract explorer

---

## Related Documentation

- [OpenAPI 3.0 Specification](https://spec.openapis.org/oas/v3.0.3)
- [JSON Schema Specification](https://json-schema.org/)
- [OpenAPI Generator](https://openapi-generator.tech/)
- [OPA/Rego Documentation](https://www.openpolicyagent.org/docs/latest/)
- [.github/CI.md](.github/CI.md) — CI/CD pipeline (includes contracts-validate job)

---

## FAQ

### Q: What if I need a contract field that doesn't map to generated code?

**A:** Use OpenAPI extensions (`x-*`):

```yaml
/v1/runs:
  post:
    summary: Trigger workflow run
    x-idempotency-required: true  # Custom field
    x-rate-limit: 100-per-minute  # Custom field
    requestBody:
      content:
        application/json:
          schema: ...
```

Your middleware can read these extensions at runtime.

### Q: Can I commit generated files?

**A:** Yes, and you should! This allows:

1. Code review of generated changes
2. Diff-friendly CI logs
3. Faster builds (no need to regenerate)
4. Git history of contract evolution

### Q: What if openapi-generator produces bad code?

**A:** You can:

1. **Customize the template** (edit `.openapi-config.yaml`)
2. **Edit generated code** (acceptable for Phase 0, but mark with comments)
3. **Switch generators** (consider swagger-codegen, etc.)
4. **Hand-write critical parts** (then note in the contract)

In Phase 1, we'll create custom templates for our specific needs.

### Q: How do I version an endpoint?

**A:** Use OpenAPI path versioning:

```yaml
/v1/workflows:
  post:
    summary: Create workflow (v1)

/v2/workflows:
  post:
    summary: Create workflow (v2, enhanced)
```

Or use header-based versioning:

```yaml
/workflows:
  post:
    parameters:
      - in: header
        name: API-Version
        schema: { type: string, enum: ['v1', 'v2'] }
```

### Q: Can events have versions?

**A:** Yes, use versioned schema filenames:

```
contracts/events/run.completed.v1.schema.json
contracts/events/run.completed.v2.schema.json (new fields)
```

Handle multiple versions in validator:

```typescript
import v1 from './run.completed.v1.schema.json';
import v2 from './run.completed.v2.schema.json';

const validators = { v1, v2 };
const validate = ajv.compile(validators['v' + eventData.event_version]);
```

---

## Support & Escalation

- 💡 **Enhancement request:** Create issue with label `contract`
- 🐛 **Validation failure:** Check `.github/CI.md#contract-validation-troubleshooting`
- 🚨 **CI blocking all PRs:** Check if tools are installed (npm install -g ...)
- ❓ **How do I...?** Check this guide or ask in #architecture

---

**Key Takeaway:** Contracts are your source of truth. Update the contract, run `make contracts`, commit everything together. This keeps your API, types, stubs, and documentation perfectly in sync.

**Owner:** @maintainer  
**Last Updated:** 2024  
**Next Review:** 2025-Q1 (Phase 1 planning)
