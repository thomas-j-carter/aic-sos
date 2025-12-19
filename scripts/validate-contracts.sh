#!/bin/bash
#
# validate-contracts.sh — Validate all contract files
#
# Validates:
#   - OpenAPI specification (contracts/openapi/openapi.yaml)
#   - JSON event schemas (contracts/events/*.schema.json)
#   - Connector manifests (contracts/connectors/*/manifest.yaml)
#   - Policy rules (contracts/policy/policy.rego)
#
# Exit codes:
#   0 — All validations passed
#   1 — At least one validation failed
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACTS_DIR="$REPO_ROOT/contracts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0
PASSED=0

# Helper functions
print_pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASSED++))
}

print_fail() {
  echo -e "${RED}✗${NC} $1"
  ((FAILED++))
}

print_info() {
  echo -e "${YELLOW}ℹ${NC} $1"
}

echo "Validating contract files..."
echo ""

# 1. Validate OpenAPI specification
echo "1. OpenAPI Specification"
if [ -f "$CONTRACTS_DIR/openapi/openapi.yaml" ]; then
  if command -v swagger-cli &> /dev/null; then
    if swagger-cli validate "$CONTRACTS_DIR/openapi/openapi.yaml" > /dev/null 2>&1; then
      print_pass "OpenAPI specification valid"
    else
      print_fail "OpenAPI specification invalid"
      swagger-cli validate "$CONTRACTS_DIR/openapi/openapi.yaml" || true
    fi
  else
    print_info "swagger-cli not installed (skipped OpenAPI validation)"
    print_info "To validate: npm install -g @apidevtools/swagger-cli"
  fi
else
  print_fail "OpenAPI file not found: $CONTRACTS_DIR/openapi/openapi.yaml"
fi
echo ""

# 2. Validate event schemas
echo "2. Event JSON Schemas"
if command -v ajv &> /dev/null; then
  for schema in "$CONTRACTS_DIR"/events/*.schema.json; do
    if [ -f "$schema" ]; then
      schema_name=$(basename "$schema")
      # Validate schema syntax
      if ajv validate -s "$schema" 2>/dev/null; then
        print_pass "$schema_name"
      else
        print_fail "$schema_name"
      fi
    fi
  done
else
  print_info "ajv-cli not installed (skipped JSON schema validation)"
  print_info "To validate: npm install -g ajv-cli"
  # Still validate basic JSON syntax
  for schema in "$CONTRACTS_DIR"/events/*.schema.json; do
    if [ -f "$schema" ]; then
      schema_name=$(basename "$schema")
      if jq empty "$schema" 2>/dev/null; then
        print_pass "$schema_name (JSON syntax)"
      else
        print_fail "$schema_name (JSON syntax invalid)"
      fi
    fi
  done
fi
echo ""

# 3. Validate connector manifests
echo "3. Connector Manifests"
for manifest in "$CONTRACTS_DIR"/connectors/*/manifest.yaml; do
  if [ -f "$manifest" ]; then
    manifest_dir=$(dirname "$manifest")
    connector_name=$(basename "$manifest_dir")
    
    # Check required fields using yq or basic grep
    if command -v yq &> /dev/null; then
      if yq eval '.id and .version and .kind' "$manifest" > /dev/null 2>&1; then
        print_pass "$connector_name manifest valid"
      else
        print_fail "$connector_name manifest missing required fields (id, version, kind)"
      fi
    else
      # Basic validation: check for required keys
      if grep -q "^id:" "$manifest" && grep -q "^version:" "$manifest" && grep -q "^kind:" "$manifest"; then
        print_pass "$connector_name manifest has required fields"
      else
        print_fail "$connector_name manifest missing required fields (id, version, kind)"
      fi
    fi
  fi
done
echo ""

# 4. Validate policy rules (basic check)
echo "4. Policy Rules"
if [ -f "$CONTRACTS_DIR/policy/policy.rego" ]; then
  if grep -q "^package policy" "$CONTRACTS_DIR/policy/policy.rego"; then
    print_pass "Policy file exists and has package declaration"
    
    # Try to validate with OPA if available
    if command -v opa &> /dev/null; then
      if opa check "$CONTRACTS_DIR/policy/policy.rego" > /dev/null 2>&1; then
        print_pass "Policy Rego syntax valid (OPA check)"
      else
        print_fail "Policy Rego syntax invalid (see OPA output)"
        opa check "$CONTRACTS_DIR/policy/policy.rego" || true
      fi
    else
      print_info "OPA not installed (full policy validation skipped)"
      print_info "To validate: brew install opa"
    fi
  else
    print_fail "Policy file missing 'package policy' declaration"
  fi
else
  print_fail "Policy file not found: $CONTRACTS_DIR/policy/policy.rego"
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════"
echo "Validation Summary:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "════════════════════════════════════════════════════════"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All contract validations passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some contract validations failed${NC}"
  exit 1
fi
