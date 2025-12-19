# Contracts Workflow Quick Visual Guide

## The Contract → Code Flow

```
┌───────────────────────────────────────────────────────────────────────┐
│                         CONTRACT TYPES                                 │
├─────────────────────────────────────┬─────────────────────────────────┤
│ OPENAPI SPEC                        │ EVENT SCHEMAS                   │
│ contracts/openapi/openapi.yaml      │ contracts/events/*.schema.json  │
├─────────────────────────────────────┼─────────────────────────────────┤
│ ✓ Defines REST endpoints            │ ✓ Defines domain events         │
│ ✓ Request/response structures       │ ✓ Event data validation         │
│ ✓ Authentication, error codes       │ ✓ Async messaging contracts    │
├─────────────────────────────────────┼─────────────────────────────────┤
│ GENERATES:                          │ GENERATES:                      │
│ → Go HTTP handlers + routes         │ → TypeScript event validators   │
│ → TypeScript API client + types     │ → Go event validators           │
└─────────────────────────────────────┴─────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│ CONNECTOR MANIFESTS                 │ POLICY RULES                    │
│ contracts/connectors/{id}/          │ contracts/policy/policy.rego    │
│ manifest.yaml                       │                                 │
├─────────────────────────────────────┼─────────────────────────────────┤
│ ✓ Defines integrations (OAuth, API  │ ✓ Defines governance rules      │
│   key, etc.)                        │ ✓ Deny-by-default enforcement  │
│ ✓ Tool actions + required scopes    │ ✓ Allowlists, approval rules   │
├─────────────────────────────────────┼─────────────────────────────────┤
│ GENERATES:                          │ VALIDATES:                      │
│ → TypeScript connector loader       │ → OPA/Rego syntax check        │
│ → Go connector loader               │ → (semantic validation in Phase1)│
└─────────────────────────────────────┴─────────────────────────────────┘
```

## Developer Workflow (5 Steps)

```
Step 1: Update Contract
┌─────────────────────────────────────┐
│ nano contracts/openapi/openapi.yaml │
│                                     │
│ Add new endpoint:                   │
│ /v1/workflows/{id}/versions:        │
│   get: ...                          │
└──────────────┬──────────────────────┘
               │
               ▼
Step 2: Validate & Generate
┌─────────────────────────────────────┐
│ make contracts                      │
│                                     │
│ ✓ OpenAPI valid                     │
│ ✓ Schemas valid                     │
│ ✓ Manifests valid                   │
│                                     │
│ Generated:                          │
│ → services/*/generated/             │
│ → apps/web/generated/               │
│ → contracts/generated/              │
└──────────────┬──────────────────────┘
               │
               ▼
Step 3: Implement Handler
┌─────────────────────────────────────┐
│ nano services/control-plane/        │
│   handler.go                        │
│                                     │
│ func (h *Handler)                  │
│   ListWorkflowVersions(...) {       │
│   // your business logic            │
│ }                                   │
└──────────────┬──────────────────────┘
               │
               ▼
Step 4: Commit Together
┌─────────────────────────────────────┐
│ git add contracts/openapi/          │
│         services/*/generated/       │
│         services/control-plane/     │
│           handler.go                │
│                                     │
│ git commit -m "feat: add endpoint"  │
└──────────────┬──────────────────────┘
               │
               ▼
Step 5: Push & CI Validates
┌─────────────────────────────────────┐
│ git push origin my-feature          │
│                                     │
│ GitHub Actions:                     │
│ [contracts-validate]                │
│   ✓ Validates contracts             │
│   ✓ Regenerates stubs               │
│   ✓ Checks for uncommitted diffs    │
│   ✓ PR can merge if all pass ✅     │
└─────────────────────────────────────┘
```

## Make Commands

```bash
make contracts              # Full cycle: validate + generate + show summary
                            # Use after updating any contract

make contracts-validate     # Just validate (no generation)
                            # Quick check before editing

make contracts-generate     # Just regenerate stubs
                            # After validation passed

make contracts-clean        # Remove all generated files
                            # Clean slate before regeneration
```

## What Gets Generated

### From OpenAPI Spec

```
contracts/openapi/openapi.yaml
    │
    ├──→ services/control-plane/generated/
    │    ├── main_api.go (route definitions)
    │    ├── models.go (request/response types)
    │    └── routers.go (HTTP handlers)
    │
    └──→ apps/web/generated/
         ├── api.ts (typed API client)
         ├── models.ts (TypeScript types)
         └── index.ts (exports)
```

### From Event Schemas

```
contracts/events/
├── run.completed.v1.schema.json
├── approval.required.v1.schema.json
└── ... (5 event types)
    │
    └──→ contracts/generated/validators/
         ├── events.ts (TypeScript validators using ajv)
         └── events.go (Go validators using gojsonschema)

Usage:
TypeScript: validateEvent('run.completed.v1', eventData)
Go:         validator.Validate("run.completed.v1", eventBytes)
```

### From Connector Manifests

```
contracts/connectors/
├── github/manifest.yaml
├── servicenow/manifest.yaml
└── slack/manifest.yaml
    │
    └──→ contracts/generated/connectors/
         ├── load.ts (TypeScript registry)
         └── load.go (Go registry)

Usage:
TypeScript: getConnector('github')
Go:         connectors.GetConnector("github")
```

## Generated Files Are Safe to Commit

All generated files have a header:

```go
// Code generated by openapi-generator. DO NOT EDIT.
```

Or:

```typescript
// Code generated from JSON schemas. DO NOT EDIT.
```

**Why commit them?**
- ✅ Code review sees what changed
- ✅ Git history tracks API evolution
- ✅ Faster CI (no need to regenerate)
- ✅ Diff-friendly (shows exactly what changed)

**Why the "DO NOT EDIT" header?**
- ❌ Your edits will be overwritten on next generation
- ✅ Edit the contract instead (openapi.yaml, *.schema.json)
- ✅ Edit handler logic (business logic code)

## CI Job Flow

```
┌─────────────────────────────────────┐
│ Developer pushes PR                 │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ contracts-validate job runs         │
├─────────────────────────────────────┤
│ Step 1: Validate contracts          │
│   ✓ OpenAPI syntax                  │
│   ✓ JSON schemas                    │
│   ✓ Connector manifests             │
│   ✓ Policy rules                    │
└──────────────┬──────────────────────┘
               │
               ├─ Any validation failed?
               │  YES → Job fails ❌ → PR blocked
               │
               ▼
┌─────────────────────────────────────┐
│ Step 2: Generate from contracts     │
│   → Go stubs                        │
│   → TS types                        │
│   → Validators                      │
│   → Connectors                      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Step 3: Compare to committed        │
│                                     │
│ git diff services/*/generated       │
│ git diff apps/*/generated           │
│ git diff contracts/generated        │
└──────────────┬──────────────────────┘
               │
               ├─ Any uncommitted diffs?
               │  Phase 0: ⚠️  Warning
               │  Phase 1: ❌ Fail
               │
               ▼
┌─────────────────────────────────────┐
│ Step 4: All other CI jobs run       │
│   ✓ go-build, go-test, go-lint     │
│   ✓ rust-build, rust-test, ...     │
│   ✓ ts-check, ts-test              │
│   ✓ security-gitleaks, audits      │
└──────────────┬──────────────────────┘
               │
               ├─ All required jobs pass?
               │  YES → ci-status = SUCCESS ✅
               │  NO  → ci-status = FAILURE ❌
               │
               ▼
┌─────────────────────────────────────┐
│ PR Merge Decision                   │
├─────────────────────────────────────┤
│ ✅ ci-status = SUCCESS              │
│    + all reviews approved           │
│    → Merge allowed                  │
│                                     │
│ ❌ ci-status = FAILURE              │
│    → Merge blocked                  │
│    → Fix contracts/code and retry   │
└─────────────────────────────────────┘
```

## Common Scenarios

### Scenario 1: Add New API Endpoint

```
┌─ contracts/openapi/openapi.yaml
│  Add: /v1/workflows/{id}/versions
│       with GET method
│
├─ make contracts
│  ✓ Generated: services/*/generated
│  ✓ Generated: apps/web/generated
│
├─ services/control-plane/handler.go
│  Implement: ListWorkflowVersions(...)
│
├─ git add contracts/ services/*/generated handler.go
│
└─ git push origin my-feature
   CI validates & generates ✅
```

### Scenario 2: Add New Event Type

```
┌─ contracts/events/workflow.published.v1.schema.json
│  Create new event schema
│
├─ make contracts
│  ✓ Validated
│  ✓ Generated: contracts/generated/validators
│
├─ services/my-service/emitter.go
│  Emit event using validator
│
├─ git add contracts/ contracts/generated emitter.go
│
└─ git push origin my-feature
   CI validates & generates ✅
```

### Scenario 3: Add New Connector

```
┌─ contracts/connectors/stripe/manifest.yaml
│  Create new connector definition
│
├─ make contracts
│  ✓ Validated
│  ✓ Generated: contracts/generated/connectors
│
├─ services/connector-gateway/stripe/
│  Implement connector integration
│
├─ git add contracts/ contracts/generated stripe/
│
└─ git push origin my-feature
   CI validates & generates ✅
```

## When Something Goes Wrong

```
Problem: "OpenAPI invalid"
┌─ Run: swagger-cli validate contracts/openapi/openapi.yaml
├─ Check: YAML indentation (use 2 spaces)
├─ Check: All required fields present
└─ Fix: nano contracts/openapi/openapi.yaml → make contracts

Problem: "Generated files differ"
┌─ Run: make contracts (locally)
├─ Review: git diff services/*/generated
├─ Stage: git add services/*/generated
└─ Commit: git commit -m "chore: regenerate contract stubs"

Problem: "JSON schema invalid"
┌─ Run: jq . contracts/events/my-event.schema.json
├─ Check: JSON syntax (jq will show error)
├─ Check: Required properties defined
└─ Fix: nano contracts/events/my-event.schema.json

Problem: "Tools not installed"
┌─ Run: npm install -g @apidevtools/swagger-cli
├─ Run: npm install -g @openapitools/openapi-generator-cli
├─ Run: npm install -g ajv-cli
└─ Try: make contracts again
```

## File Structure

```
contracts/
├── openapi/
│   ├── openapi.yaml                    ← REST API contract
│   └── .openapi-config.yaml            ← Generator config
│
├── events/
│   ├── run.completed.v1.schema.json
│   ├── approval.required.v1.schema.json
│   ├── policy.denied.v1.schema.json
│   ├── incident.created.v1.schema.json
│   └── connector.scope_changed.v1.schema.json
│
├── connectors/
│   ├── github/
│   │   └── manifest.yaml
│   ├── servicenow/
│   │   └── manifest.yaml
│   └── slack/
│       └── manifest.yaml
│
├── policy/
│   └── policy.rego
│
└── generated/                          ← AUTO-GENERATED
    ├── validators/
    │   ├── events.ts
    │   └── events.go
    └── connectors/
        ├── load.ts
        └── load.go

services/*/
└── generated/                          ← AUTO-GENERATED
    ├── main_api.go
    ├── models.go
    └── routers.go

apps/web/
└── generated/                          ← AUTO-GENERATED
    ├── api.ts
    ├── models.ts
    └── index.ts

scripts/
├── validate-contracts.sh               ← Validation tool
└── generate-contracts.sh               ← Generation tool
```

## Key Principles

```
┌─ Write Contracts First
│  "API shape first, code second"
│  - Enables parallel development
│  - Clear contract enforcement
│  - Type safety by construction

├─ Never Hand-Edit Generated Files
│  "Generated files get overwritten"
│  - Edit the contract instead
│  - Edit the business logic code
│  - Use "Code generated" header as reminder

├─ Commit Contracts + Stubs Together
│  "Atomic changes"
│  - Contract updates with generated code
│  - Implementation changes separate
│  - Clear git history of API evolution

├─ Validate Before Commit
│  "Fail fast"
│  - Run `make contracts` locally
│  - Catch errors before push
│  - CI verifies with fresh generation

└─ Document Contract Changes
│  "Clear intent"
│  - Explain what changed in commit message
│  - List breaking changes (if any)
│  - Link to related issues/PRs
```

---

**Quick Start:** Update contract → `make contracts` → Implement handler → Commit together → Push → CI validates ✅
