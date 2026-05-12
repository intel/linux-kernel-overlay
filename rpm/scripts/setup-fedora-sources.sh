#!/bin/bash
# Setup Fedora rawhide kernel sources for RPM build
# Downloads spec file and build scripts from Fedora's git repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPM_DIR="$(dirname "$SCRIPT_DIR")"
FEDORA_REPO="https://src.fedoraproject.org/rpms/kernel"
FEDORA_BRANCH="${FEDORA_BRANCH:-rawhide}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat <<EOF
Setup Fedora Kernel Sources for RPM Build

Usage: $0 [OPTIONS]

OPTIONS:
    -b, --branch BRANCH    Fedora branch (default: rawhide)
    -f, --force            Force re-download even if files exist
    -h, --help             Show this help message

EXAMPLES:
    # Download from rawhide (bleeding edge)
    $0

    # Download from Fedora 40
    $0 --branch f40

    # Force re-download
    $0 --force

DESCRIPTION:
    This script downloads the following from Fedora's kernel repository:
    - kernel.spec (main spec file)
    - Build scripts (mod-sign.sh, parallel_xz.sh, etc.)
    - Configuration files
    - Filter modules scripts

OUTPUT:
    Files are downloaded to:
    - rpm/SPECS/kernel.spec
    - rpm/SOURCES/scripts/

EOF
}

FORCE_DOWNLOAD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--branch)
            FEDORA_BRANCH="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_DOWNLOAD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_info "Setting up Fedora kernel sources from branch: ${FEDORA_BRANCH}"

# Create directories
mkdir -p "$RPM_DIR/SPECS"
mkdir -p "$RPM_DIR/SOURCES/scripts"

# Download kernel.spec
SPEC_FILE="$RPM_DIR/SPECS/kernel.spec"
if [ -f "$SPEC_FILE" ] && [ "$FORCE_DOWNLOAD" = false ]; then
    print_warn "kernel.spec already exists. Use --force to re-download."
else
    print_info "Downloading kernel.spec..."
    curl -L -o "$SPEC_FILE" \
        "${FEDORA_REPO}/raw/${FEDORA_BRANCH}/f/kernel.spec" || {
        print_error "Failed to download kernel.spec"
        exit 1
    }
    print_info "Downloaded: $SPEC_FILE"
fi

# Download common build scripts
SCRIPTS=(
    "mod-sign.sh"
    "parallel_xz.sh"
    "filter-modules.sh.fedora"
    "generate_bls_conf.sh"
    "generate_crashkernel_default.sh"
)

print_info "Downloading build scripts..."
for script in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="$RPM_DIR/SOURCES/scripts/$script"
    if [ -f "$SCRIPT_PATH" ] && [ "$FORCE_DOWNLOAD" = false ]; then
        print_warn "  $script already exists, skipping."
        continue
    fi

    print_info "  Downloading $script..."
    curl -L -o "$SCRIPT_PATH" \
        "${FEDORA_REPO}/raw/${FEDORA_BRANCH}/f/$script" || {
        print_warn "  Failed to download $script (might not exist in this branch)"
        continue
    }
    chmod +x "$SCRIPT_PATH"
done

# Download .gitignore if exists
print_info "Downloading additional files..."
curl -L -o "$RPM_DIR/SOURCES/.gitignore" \
    "${FEDORA_REPO}/raw/${FEDORA_BRANCH}/f/.gitignore" 2>/dev/null || true

print_info ""
print_info "============================================================"
print_info "Fedora kernel sources setup completed!"
print_info "============================================================"
print_info ""
print_info "Downloaded files:"
print_info "  - Spec file: rpm/SPECS/kernel.spec"
print_info "  - Scripts:   rpm/SOURCES/scripts/"
print_info ""
print_info "Next steps:"
print_info "  1. Review the spec file: rpm/SPECS/kernel.spec"
print_info "  2. Customize for your needs (optional)"
print_info "  3. Build RPM: ./rpm/scripts/build.sh"
print_info ""
print_info "Note: The spec file may reference additional files that need"
print_info "      to be downloaded or generated. Check the spec file for"
print_info "      Source entries and adjust as needed."
