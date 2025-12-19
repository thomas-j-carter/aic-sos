
# Monorepo layout (no Bazel)

repo/
  services/
    control-plane/            # Go
    execution-plane/          # Rust core + Go orchestration glue
    connector-gateway/        # Rust/Go; PEP before external calls
    policy/                   # OPA bundles + tests + tooling
    ui/                       # TS/React
    agent/                    # Rust outbound-only agent
  contracts/                  # OpenAPI + event schemas + connector manifests
  diagrams/                   # Mermaid .mmd
  docs/                       # RFCs and notes
  infra/
    terraform/                # AWS cell template
    helm/                     # optional later
  tooling/
    cli/                      # dev/admin CLI (Go or TS)
  scripts/
  docker-compose.yaml
