#!/usr/bin/env bash
#
# version.sh - Unified version management for the monorepo
#
# Usage:
#   ./version.sh show              # Print current version
#   ./version.sh set <new-version> # Update VERSION file
#   ./version.sh bump minor        # Bump version (major, minor, patch)
#   ./version.sh tag               # Create git tag for current version
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure VERSION file exists
if [[ ! -f "$VERSION_FILE" ]]; then
    echo -e "${RED}ERROR: VERSION file not found at $VERSION_FILE${NC}"
    exit 1
fi

# Read current version
read_version() {
    cat "$VERSION_FILE" | tr -d '\n' | tr -d ' '
}

# Validate semver format (major.minor.patch)
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}ERROR: Invalid version format '$version'. Expected: major.minor.patch${NC}"
        return 1
    fi
}

# Parse version components
parse_version() {
    local version=$1
    local IFS='.'
    read -ra parts <<<"$version"
    echo "${parts[0]} ${parts[1]} ${parts[2]}"
}

# Bump version (major, minor, or patch)
bump_version() {
    local version=$1
    local part=$2
    
    read major minor patch <<< "$(parse_version "$version")"
    
    case "$part" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}ERROR: Invalid bump type '$part'. Use: major, minor, patch${NC}"
            return 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Show current version
show_version() {
    local version=$(read_version)
    echo -e "${GREEN}Current version: ${YELLOW}$version${NC}"
}

# Set version
set_version() {
    local new_version=$1
    validate_version "$new_version" || return 1
    
    echo "$new_version" > "$VERSION_FILE"
    echo -e "${GREEN}✓ Version updated to ${YELLOW}$new_version${NC}"
}

# Create git tag
create_tag() {
    local version=$(read_version)
    local tag_name="v${version}"
    
    # Check if tag already exists
    if git rev-parse "$tag_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Tag '$tag_name' already exists${NC}"
        return 1
    fi
    
    git tag -a "$tag_name" -m "Release version $version"
    echo -e "${GREEN}✓ Created git tag: ${YELLOW}$tag_name${NC}"
    echo -e "${GREEN}To push: ${YELLOW}git push origin $tag_name${NC}"
}

# List component tags (Docker-style tags for each service)
list_component_tags() {
    local version=$(read_version)
    local services=("control-plane" "execution-plane" "connector-gateway" "agent")
    
    echo -e "${GREEN}Component tags for version $version:${NC}"
    for service in "${services[@]}"; do
        echo "  ${YELLOW}${service}:v${version}${NC}"
    done
}

# Main command dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        show_version
        return 0
    fi
    
    local cmd=$1
    
    case "$cmd" in
        show)
            show_version
            ;;
        set)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}ERROR: set requires a version argument${NC}"
                echo "Usage: $0 set <version>"
                exit 1
            fi
            set_version "$2"
            ;;
        bump)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}ERROR: bump requires a part argument (major, minor, patch)${NC}"
                exit 1
            fi
            local current=$(read_version)
            local new=$(bump_version "$current" "$2")
            echo -e "${YELLOW}Bumping $2: $current → $new${NC}"
            set_version "$new"
            ;;
        tag)
            create_tag
            ;;
        tags)
            list_component_tags
            ;;
        *)
            echo -e "${RED}ERROR: Unknown command '$cmd'${NC}"
            echo "Usage:"
            echo "  $0 show             # Print current version"
            echo "  $0 set <version>    # Set version (e.g., 0.2.0)"
            echo "  $0 bump <part>      # Bump version (major, minor, patch)"
            echo "  $0 tag              # Create git tag for current version"
            echo "  $0 tags             # Show component tags (Docker-style)"
            exit 1
            ;;
    esac
}

main "$@"
