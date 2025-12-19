VERSION := $(shell cat VERSION | tr -d '\n' | tr -d ' ')

.PHONY: help build version version-show version-bump-patch version-bump-minor version-bump-major version-tag version-tags \
	dev dev-up dev-down dev-logs dev-status dev-reset smoke-test \
	contracts contracts-validate contracts-generate contracts-clean

help:
	@echo "AI Workflow Governance Platform - Make Targets"
	@echo ""
	@echo "Quick Start:"
	@echo "  make dev                      Start full dev environment (docker + services)"
	@echo "  make smoke-test               Run smoke tests on dev environment"
	@echo ""
	@echo "Development:"
	@echo "  make dev-up                   Start docker containers (Postgres, Redis, MinIO)"
	@echo "  make dev-down                 Stop docker containers"
	@echo "  make dev-logs [SERVICE=name]  View container logs (SERVICE=postgres|redis|minio)"
	@echo "  make dev-status               Show container status"
	@echo "  make dev-reset                Stop containers and remove volumes (fresh start)"
	@echo ""
	@echo "Build:"
	@echo "  make build                    Build all services (Go, Rust, TS)"
	@echo ""
	@echo "Contracts:"
	@echo "  make contracts                Validate and regenerate all contract stubs"
	@echo "  make contracts-validate       Validate OpenAPI, JSON schemas, connector manifests"
	@echo "  make contracts-generate       Regenerate OpenAPI stubs, event validators"
	@echo "  make contracts-clean          Remove generated files (regenerate on next make contracts)"
	@echo ""
	@echo "Version Management:"
	@echo "  make version                  Show current version"
	@echo "  make version-bump-patch       Bump patch version (0.1.0 → 0.1.1)"
	@echo "  make version-bump-minor       Bump minor version (0.1.0 → 0.2.0)"
	@echo "  make version-bump-major       Bump major version (0.1.0 → 1.0.0)"
	@echo "  make version-tag              Create git tag for current version"
	@echo "  make version-tags             Show component Docker tags"
	@echo ""
	@echo "Release:"
	@echo "  See RELEASE-CHECKLIST.md for full release workflow"
	@echo ""
	@echo "Documentation:"
	@echo "  See docs/START-HERE.md for quick start"
	@echo "  See VERSIONING-QUICKSTART.md for version management"
	@echo "  See docs/CONTRACTS.md for contract workflow"

# Development environment commands
dev: dev-up build smoke-test
	@echo ""
	@echo "✓ Development environment is ready!"
	@echo ""
	@echo "Available services:"
	@echo "  PostgreSQL:        localhost:5432 (user: postgres, password: postgres)"
	@echo "  Redis:             localhost:6379"
	@echo "  MinIO S3:          localhost:9000 (console: http://localhost:9001)"
	@echo "  MinIO Console:     http://localhost:9001 (user: minio, password: minio123)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Review docs/START-HERE.md for architecture overview"
	@echo "  2. Implement your first feature or workflow"
	@echo "  3. See VERSIONING-QUICKSTART.md for release process"

dev-up:
	@echo "Starting development infrastructure..."
	docker-compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@docker-compose ps

dev-down:
	@echo "Stopping development infrastructure..."
	docker-compose down

dev-logs:
	@if [ -z "$(SERVICE)" ]; then \
		docker-compose logs -f; \
	else \
		docker-compose logs -f $(SERVICE); \
	fi

dev-status:
	@echo "Container Status:"
	@docker-compose ps
	@echo ""
	@echo "Health Check Summary:"
	@echo -n "  PostgreSQL: "; docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1 && echo "✓ OK" || echo "✗ Not ready"
	@echo -n "  Redis:      "; docker-compose exec -T redis redis-cli ping > /dev/null 2>&1 && echo "✓ OK" || echo "✗ Not ready"
	@echo -n "  MinIO:      "; curl -s -f http://localhost:9000/minio/health/live > /dev/null 2>&1 && echo "✓ OK" || echo "✗ Not ready"

dev-reset:
	@echo "Resetting development environment (removing volumes)..."
	docker-compose down -v
	@echo "✓ Development environment reset. Run 'make dev' to restart."

smoke-test:
	@echo "Running smoke tests..."
	@chmod +x ./smoke-test.sh
	@./smoke-test.sh

build:
	cd services/control-plane && go build ./...
	cd services/connector-gateway && go build ./...
	cd services/execution-plane && cargo build
	cd services/agent && cargo build

version:
	@./version.sh show

version-show:
	@./version.sh show

version-bump-patch:
	./version.sh bump patch

version-bump-minor:
	./version.sh bump minor

version-bump-major:
	./version.sh bump major

version-tag:
	./version.sh tag

version-tags:
	@./version.sh tags

# Contract validation and generation
contracts: contracts-validate contracts-generate
	@echo ""
	@echo "✓ All contracts validated and stubs regenerated"
	@echo ""
	@echo "Check git diff to see generated changes:"
	@echo "  git diff services/ apps/"
	@echo ""
	@echo "Verify uncommitted generated files:"
	@echo "  git status | grep generated"

contracts-validate:
	@echo "Validating contract files..."
	@chmod +x ./scripts/validate-contracts.sh
	@./scripts/validate-contracts.sh

contracts-generate:
	@echo "Generating contract stubs..."
	@chmod +x ./scripts/generate-contracts.sh
	@./scripts/generate-contracts.sh
	@echo "✓ Contract stubs generated"
	@echo ""
	@echo "Regenerated files:"
	@echo "  - services/*/generated/ (OpenAPI server stubs)"
	@echo "  - apps/web/generated/ (OpenAPI client + types)"
	@echo "  - contracts/generated/ (event validators, connector loaders)"

contracts-clean:
	@echo "Removing generated contract files..."
	@find services -type d -name "generated" -exec rm -rf {} + 2>/dev/null || true
	@find apps -type d -name "generated" -exec rm -rf {} + 2>/dev/null || true
	@find contracts -type d -name "generated" -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Generated files removed"
	@echo "Run 'make contracts' to regenerate"
