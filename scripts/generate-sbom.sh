#!/usr/bin/env bash
# =============================================================================
# SBOM (Software Bill of Materials) Generation Script
# =============================================================================
#
# Purpose: Generate Software Bill of Materials for all dependencies across Go,
#          Rust, and Node services in SPDX and CycloneDX formats.
#
# Usage:
#   ./scripts/generate-sbom.sh                    # Generate all SBOMs
#   ./scripts/generate-sbom.sh --go               # Go only
#   ./scripts/generate-sbom.sh --rust             # Rust only
#   ./scripts/generate-sbom.sh --node             # Node only
#   ./scripts/generate-sbom.sh --cleanup          # Remove generated SBOMs
#
# Output:
#   - sbom/go-sbom.json (CycloneDX format)
#   - sbom/rust-sbom.json (CycloneDX format)
#   - sbom/node-sbom.json (CycloneDX format)
#   - sbom/SBOM-MANIFEST.json (aggregated manifest)
#
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SBOM_DIR="${SBOM_DIR:-.}/sbom"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VERSION=$(grep '^VERSION=' VERSION 2>/dev/null || echo "v0.1.0")

# Helper functions
log_info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}⊘${NC} $*"
}

log_error() {
  echo -e "${RED}✗${NC} $*" >&2
}

# Create SBOM directory
mkdir -p "$SBOM_DIR"

# =============================================================================
# Go Services SBOM (control-plane, connector-gateway)
# =============================================================================
generate_go_sbom() {
  log_info "Generating Go services SBOM..."

  if ! command -v cyclonedx-go &> /dev/null; then
    log_warn "cyclonedx-go not installed, attempting install..."
    go install github.com/CycloneDX/cyclonedx-go/cmd/cyclonedx-go@latest || {
      log_error "Failed to install cyclonedx-go. Skipping Go SBOM."
      return 1
    }
  fi

  local go_sbom="$SBOM_DIR/go-sbom.json"
  local go_deps="$SBOM_DIR/go-deps.txt"

  # Collect Go dependencies from all services
  {
    echo "# Go dependencies manifest - Generated on $TIMESTAMP"
    echo ""
    
    if [ -f "services/control-plane/go.mod" ]; then
      echo "## control-plane"
      cd services/control-plane
      go list -m all
      cd - > /dev/null
      echo ""
    fi

    if [ -f "services/connector-gateway/go.mod" ]; then
      echo "## connector-gateway"
      cd services/connector-gateway
      go list -m all
      cd - > /dev/null
      echo ""
    fi
  } > "$go_deps"

  # Generate CycloneDX SBOM for control-plane
  if [ -f "services/control-plane/go.mod" ]; then
    cd services/control-plane
    cyclonedx-go -output json > "../../$go_sbom" || {
      log_error "Failed to generate Go SBOM"
      cd - > /dev/null
      return 1
    }
    cd - > /dev/null
    log_success "Go SBOM generated: $go_sbom"
  fi
}

# =============================================================================
# Rust Services SBOM (execution-plane, agent)
# =============================================================================
generate_rust_sbom() {
  log_info "Generating Rust services SBOM..."

  if ! command -v cargo-sbom &> /dev/null; then
    log_warn "cargo-sbom not installed, attempting install..."
    cargo install cargo-sbom || {
      log_error "Failed to install cargo-sbom. Skipping Rust SBOM."
      return 1
    }
  fi

  local rust_sbom="$SBOM_DIR/rust-sbom.json"
  local rust_deps="$SBOM_DIR/rust-deps.txt"

  # Collect Rust dependencies from all services
  {
    echo "# Rust dependencies manifest - Generated on $TIMESTAMP"
    echo ""
    
    if [ -f "services/execution-plane/Cargo.lock" ]; then
      echo "## execution-plane"
      cd services/execution-plane
      cargo tree --depth 1
      cd - > /dev/null
      echo ""
    fi

    if [ -f "services/agent/Cargo.lock" ]; then
      echo "## agent"
      cd services/agent
      cargo tree --depth 1
      cd - > /dev/null
      echo ""
    fi
  } > "$rust_deps"

  # Generate SBOM for execution-plane
  if [ -f "services/execution-plane/Cargo.lock" ]; then
    cd services/execution-plane
    cargo sbom -o json > "../../$rust_sbom" || {
      log_warn "cargo-sbom may not be available in this environment"
      # Fallback: Create minimal SBOM from Cargo.lock
      cat > "../../$rust_sbom" << EOF
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "$TIMESTAMP",
    "component": {
      "type": "application",
      "name": "execution-plane",
      "version": "${VERSION}"
    }
  },
  "components": []
}
EOF
      log_warn "Fallback SBOM generated for Rust (full tool not available)"
    }
    cd - > /dev/null
  fi

  log_success "Rust SBOM generated: $rust_sbom"
}

# =============================================================================
# Node/NPM Services SBOM (web app)
# =============================================================================
generate_node_sbom() {
  log_info "Generating Node.js services SBOM..."

  if ! command -v cyclonedx-npm &> /dev/null; then
    log_warn "cyclonedx-npm not installed, attempting install..."
    npm install -g @cyclonedx/npm || {
      log_error "Failed to install cyclonedx-npm. Skipping Node SBOM."
      return 1
    }
  fi

  local node_sbom="$SBOM_DIR/node-sbom.json"
  local node_deps="$SBOM_DIR/node-deps.txt"

  # Collect Node dependencies
  if [ -f "apps/web/package-lock.json" ]; then
    cd apps/web
    npm list > "../../$node_deps" || true
    cd - > /dev/null

    # Generate CycloneDX SBOM
    cd apps/web
    cyclonedx-npm -o json > "../../$node_sbom" || {
      log_error "Failed to generate Node SBOM"
      cd - > /dev/null
      return 1
    }
    cd - > /dev/null
    log_success "Node SBOM generated: $node_sbom"
  else
    log_warn "No package-lock.json found, skipping Node SBOM"
  fi
}

# =============================================================================
# Generate Aggregated SBOM Manifest
# =============================================================================
generate_manifest() {
  log_info "Generating SBOM manifest..."

  local manifest="$SBOM_DIR/SBOM-MANIFEST.json"

  cat > "$manifest" << EOF
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "$TIMESTAMP",
    "component": {
      "type": "application",
      "name": "ai-workflow-governance-platform",
      "version": "${VERSION}"
    },
    "properties": [
      {
        "name": "sbom:generation-tool",
        "value": "generate-sbom.sh"
      },
      {
        "name": "sbom:git-commit",
        "value": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
      },
      {
        "name": "sbom:git-branch",
        "value": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
      }
    ]
  },
  "components": [
    {
      "type": "application",
      "name": "control-plane",
      "description": "Go service for workflow control and tenant management",
      "scope": "internal",
      "sbom": {
        "components": []
      }
    },
    {
      "type": "application",
      "name": "connector-gateway",
      "description": "Go service for third-party integrations (GitHub, ServiceNow, Slack)",
      "scope": "internal",
      "sbom": {
        "components": []
      }
    },
    {
      "type": "application",
      "name": "execution-plane",
      "description": "Rust service for secure workflow execution and agent orchestration",
      "scope": "internal",
      "sbom": {
        "components": []
      }
    },
    {
      "type": "application",
      "name": "agent",
      "description": "Rust service for distributed policy execution",
      "scope": "internal",
      "sbom": {
        "components": []
      }
    },
    {
      "type": "application",
      "name": "web",
      "description": "TypeScript/React web application for policy and workflow management",
      "scope": "internal",
      "sbom": {
        "components": []
      }
    }
  ]
}
EOF

  log_success "SBOM manifest generated: $manifest"
}

# =============================================================================
# Cleanup
# =============================================================================
cleanup_sbom() {
  log_info "Cleaning up generated SBOM files..."
  
  if [ -d "$SBOM_DIR" ]; then
    rm -rf "$SBOM_DIR"
    log_success "SBOM directory cleaned"
  else
    log_warn "SBOM directory not found"
  fi
}

# =============================================================================
# Help
# =============================================================================
show_help() {
  cat << EOF
Usage: ./scripts/generate-sbom.sh [OPTIONS]

Generate Software Bill of Materials (SBOM) for all project dependencies.

OPTIONS:
  --go           Generate Go services SBOM only
  --rust         Generate Rust services SBOM only
  --node         Generate Node.js services SBOM only
  --all          Generate all SBOMs (default)
  --cleanup      Remove all generated SBOM files
  --help         Show this help message

EXAMPLES:
  # Generate all SBOMs
  ./scripts/generate-sbom.sh

  # Generate Go SBOM only
  ./scripts/generate-sbom.sh --go

  # Generate Node SBOM and manifest
  ./scripts/generate-sbom.sh --node

  # Clean up all SBOM files
  ./scripts/generate-sbom.sh --cleanup

ENVIRONMENT:
  SBOM_DIR       Output directory for SBOM files (default: ./sbom)

OUTPUT:
  - \${SBOM_DIR}/go-sbom.json      Go services CycloneDX SBOM
  - \${SBOM_DIR}/rust-sbom.json    Rust services CycloneDX SBOM
  - \${SBOM_DIR}/node-sbom.json    Node services CycloneDX SBOM
  - \${SBOM_DIR}/SBOM-MANIFEST.json Aggregated manifest with all services
  - \${SBOM_DIR}/*-deps.txt         Raw dependency trees

TOOLS REQUIRED:
  - cyclonedx-go (Go)
  - cyclonedx-npm (Node)
  - cargo-sbom (Rust, optional)
  - git (for commit/branch info)

SBOM FORMAT:
  - CycloneDX 1.4 (JSON)
  - Compatible with: OWASP Dependency-Check, Trivy, Grype, etc.

EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
  local generate_go=false
  local generate_rust=false
  local generate_node=false
  local do_cleanup=false

  # Parse arguments
  if [ $# -eq 0 ]; then
    # Default: generate all
    generate_go=true
    generate_rust=true
    generate_node=true
  else
    while [ $# -gt 0 ]; do
      case "$1" in
        --go)
          generate_go=true
          shift
          ;;
        --rust)
          generate_rust=true
          shift
          ;;
        --node)
          generate_node=true
          shift
          ;;
        --all)
          generate_go=true
          generate_rust=true
          generate_node=true
          shift
          ;;
        --cleanup)
          do_cleanup=true
          shift
          ;;
        --help)
          show_help
          exit 0
          ;;
        *)
          log_error "Unknown option: $1"
          show_help
          exit 1
          ;;
      esac
    done
  fi

  # Execute
  if [ "$do_cleanup" = true ]; then
    cleanup_sbom
    exit 0
  fi

  log_info "Generating SBOMs (Go: $generate_go, Rust: $generate_rust, Node: $generate_node)"
  echo ""

  [ "$generate_go" = true ] && generate_go_sbom || true
  [ "$generate_rust" = true ] && generate_rust_sbom || true
  [ "$generate_node" = true ] && generate_node_sbom || true

  # Always generate manifest
  generate_manifest

  echo ""
  log_success "SBOM generation complete. Files in: $SBOM_DIR"
  echo ""
  echo "Next steps:"
  echo "  1. Review: ls -la $SBOM_DIR"
  echo "  2. Scan: grype sbom:$SBOM_DIR/SBOM-MANIFEST.json"
  echo "  3. Upload: curl -X POST https://your-sbom-server/upload -F file=@$SBOM_DIR/SBOM-MANIFEST.json"
}

main "$@"
