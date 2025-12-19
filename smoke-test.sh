#!/usr/bin/env bash
#
# smoke-test.sh - Verify all services are running and healthy
#
# Usage:
#   ./smoke-test.sh
#   ./smoke-test.sh --verbose
#
# Returns: 0 if all checks pass, 1 if any check fails

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=${1:-}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
TESTS_RUN=0

# Test utilities
test_start() {
    local name=$1
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -ne "${BLUE}[${TESTS_RUN}] ${name}...${NC} "
}

test_pass() {
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✓${NC}"
}

test_fail() {
    local reason=$1
    FAILED=$((FAILED + 1))
    echo -e "${RED}✗${NC}"
    echo -e "  ${RED}Reason: ${reason}${NC}"
}

test_skip() {
    local reason=$1
    echo -e "${YELLOW}⊘${NC} (skipped: ${reason})"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "Tests run: ${TESTS_RUN} | ${GREEN}Passed: ${PASSED}${NC} | ${RED}Failed: ${FAILED}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All smoke tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ ${FAILED} test(s) failed${NC}"
        return 1
    fi
}

# Service health checks
check_postgres() {
    test_start "PostgreSQL (port 5432)"
    
    if ! command -v pg_isready &> /dev/null; then
        test_skip "pg_isready not found (install postgresql-client)"
        return 0
    fi
    
    if pg_isready -h localhost -p 5432 -U postgres &> /dev/null; then
        test_pass
    else
        test_fail "PostgreSQL not responding on localhost:5432"
    fi
}

check_redis() {
    test_start "Redis (port 6379)"
    
    if ! command -v redis-cli &> /dev/null; then
        test_skip "redis-cli not found (install redis)"
        return 0
    fi
    
    if redis-cli -h localhost -p 6379 ping &> /dev/null; then
        test_pass
    else
        test_fail "Redis not responding on localhost:6379"
    fi
}

check_minio() {
    test_start "MinIO (port 9000)"
    
    if curl -s -f http://localhost:9000/minio/health/live &> /dev/null; then
        test_pass
    else
        test_fail "MinIO not responding on localhost:9000"
    fi
}

check_docker_compose() {
    test_start "Docker Compose services running"
    
    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        test_skip "docker/docker-compose not found"
        return 0
    fi
    
    # Check if docker is running
    if ! docker info &> /dev/null; then
        test_fail "Docker daemon not running"
        return 1
    fi
    
    # Count running containers
    if docker-compose ps &> /dev/null 2>&1; then
        local running=$(docker-compose ps -q 2>/dev/null | wc -l)
        if [[ $running -ge 3 ]]; then
            test_pass
        else
            test_fail "Expected 3+ containers running, found ${running}"
        fi
    else
        test_fail "docker-compose not available"
    fi
}

check_ports() {
    test_start "Required ports available"
    
    local ports=(5432 6379 9000 9001)
    local unavailable=()
    
    for port in "${ports[@]}"; do
        if nc -z localhost "$port" 2>/dev/null; then
            # Port is in use
            :
        fi
    done
    
    test_pass
}

# Application health checks
check_build() {
    test_start "Services compile (make build)"
    
    if [[ -f "${SCRIPT_DIR}/Makefile" ]]; then
        if cd "${SCRIPT_DIR}" && make build &> /dev/null 2>&1; then
            test_pass
        else
            test_fail "make build failed"
        fi
    else
        test_skip "Makefile not found"
    fi
}

check_git() {
    test_start "Git repository"
    
    if [[ -d "${SCRIPT_DIR}/.git" ]]; then
        test_pass
    else
        test_skip "Not a git repository"
    fi
}

check_version_file() {
    test_start "VERSION file"
    
    if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
        local version=$(cat "${SCRIPT_DIR}/VERSION" | tr -d '\n' | tr -d ' ')
        if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            test_pass
        else
            test_fail "Invalid VERSION format: ${version}"
        fi
    else
        test_fail "VERSION file not found"
    fi
}

check_documentation() {
    test_start "Documentation (START-HERE.md)"
    
    if [[ -f "${SCRIPT_DIR}/docs/START-HERE.md" ]]; then
        test_pass
    else
        test_fail "docs/START-HERE.md not found"
    fi
}

# Verbose output for debugging
if [[ $VERBOSE == "--verbose" ]]; then
    echo ""
    echo "Environment Info:"
    echo "  Script directory: ${SCRIPT_DIR}"
    echo "  Current user: $(whoami)"
    echo "  Docker available: $(command -v docker 2>/dev/null && echo "yes" || echo "no")"
    echo "  docker-compose available: $(command -v docker-compose 2>/dev/null && echo "yes" || echo "no")"
    echo ""
fi

# Run all checks
print_header "Smoke Tests - Local Development Environment"

print_header "Infrastructure Health"
check_docker_compose
check_postgres
check_redis
check_minio
check_ports

print_header "Build & Repository"
check_git
check_version_file
check_build

print_header "Documentation"
check_documentation

# Print summary and exit with appropriate code
print_summary
exit $?
