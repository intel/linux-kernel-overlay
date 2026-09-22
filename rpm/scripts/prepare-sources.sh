#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Prepare all source files for RPM build (Fedora-style flat layout)
# - Downloads kernel tarball
# - Creates patches tarball from intel/patches (series + individual patches)
# - Generates kernel config files from intel/config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPM_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$RPM_DIR")"
INTEL_DIR="$PROJECT_ROOT/intel"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Default values
KERNEL_VERSION="6.18.20"
FORCE_DOWNLOAD=false
SKIP_KERNEL=false
SKIP_PATCHES=false
SKIP_CONFIGS=false

show_usage() {
    cat <<EOF
Prepare RPM Build Sources (Fedora-style)

Usage: $0 [OPTIONS]

OPTIONS:
    -v, --version VERSION    Kernel version (default: $KERNEL_VERSION)
    -f, --force              Force re-download and regenerate
    --skip-kernel            Skip kernel tarball download
    --skip-patches           Skip patches tarball creation
    --skip-configs           Skip config generation
    -h, --help               Show this help message

EXAMPLES:
    # Prepare all sources for kernel 6.18.20
    $0 --version 6.18.20

    # Force regenerate all
    $0 --force

    # Only generate patches and configs
    $0 --skip-kernel

WHAT IT DOES:
    1. Downloads linux-VERSION.tar.xz to rpm/
    2. Creates rpm/patches.tar.gz from intel/patches/ (series + patches)
    3. Generates rpm/kernel-*.config from intel/config/

OUTPUT STRUCTURE (Fedora-style flat layout):
    rpm/
    ├── linux-6.18.20.tar.xz           # Kernel source
    ├── patches.tar.gz                 # Patches (extracted during build)
    ├── patches -> ../intel/patches   # Symlink for reference
    ├── kernel-x86_64.config           # Generated configs
    └── kernel.spec                    # Spec file (create separately)

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            KERNEL_VERSION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_DOWNLOAD=true
            shift
            ;;
        --skip-kernel)
            SKIP_KERNEL=true
            shift
            ;;
        --skip-patches)
            SKIP_PATCHES=true
            shift
            ;;
        --skip-configs)
            SKIP_CONFIGS=true
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

echo "======================================================================"
echo "Prepare RPM Build Sources (Fedora-style)"
echo "======================================================================"
echo "Kernel Version:   $KERNEL_VERSION"
echo "RPM Directory:    $RPM_DIR"
echo "Common Directory: $INTEL_DIR"
echo "======================================================================"
echo ""

# ======================================================================
# Step 1: Download kernel tarball
# ======================================================================
if [ "$SKIP_KERNEL" = false ]; then
    print_step "Step 1: Downloading kernel tarball"

    KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
    # Map the packaging version onto the upstream tarball/tag name:
    #   - strip a trailing .0    (7.0.0 -> 7.0, 6.18.0 -> 6.18, but 6.18.33 stays)
    #   - Debian '~rc' -> '-rc'  (7.3~rc3 -> 7.3-rc3, the spelling kernel.org and git use)
    UPSTREAM_VERSION=$(echo "$KERNEL_VERSION" | sed -E 's/^([0-9]+\.[0-9]+)\.0([-~]rc[0-9]+)?$/\1\2/; s/~rc/-rc/')
    UPSTREAM_TARBALL="linux-${UPSTREAM_VERSION}.tar.xz"
    KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/${UPSTREAM_TARBALL}"
    KERNEL_GIT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

    # kernel.org only publishes released tarballs under v*.x/; -rc trees exist
    # solely as git tags, so build the tarball from the tag instead.
    fetch_tarball_from_git() {
        local tmpdir rc=0
        tmpdir=$(mktemp -d)
        print_info "Cloning tag v${UPSTREAM_VERSION} from ${KERNEL_GIT_URL}"
        if git clone --quiet --depth 1 --branch "v${UPSTREAM_VERSION}" \
                "$KERNEL_GIT_URL" "$tmpdir/linux"; then
            print_info "Creating $KERNEL_TARBALL (top-level dir: linux-${UPSTREAM_VERSION}/)"
            git -C "$tmpdir/linux" archive --format=tar \
                --prefix="linux-${UPSTREAM_VERSION}/" HEAD \
                | xz -T0 > "$RPM_DIR/$KERNEL_TARBALL" || rc=1
        else
            rc=1
        fi
        rm -rf "$tmpdir"
        return $rc
    }

    if [ -f "$RPM_DIR/$KERNEL_TARBALL" ] && [ "$FORCE_DOWNLOAD" = false ]; then
        print_info "Kernel tarball already exists: $KERNEL_TARBALL"
    elif case "$UPSTREAM_VERSION" in *-rc*) true ;; *) false ;; esac; then
        print_info "Release candidate: no kernel.org tarball exists, using git tag"
        if ! fetch_tarball_from_git; then
            rm -f "$RPM_DIR/$KERNEL_TARBALL"
            print_error "Failed to create kernel tarball from tag v${UPSTREAM_VERSION}"
            print_error "  Git URL: $KERNEL_GIT_URL"
            exit 1
        fi
        print_info "Created: $KERNEL_TARBALL ($(du -h "$RPM_DIR/$KERNEL_TARBALL" | cut -f1))"
    else
        print_info "Downloading from: $KERNEL_URL"
        if curl -L -o "$RPM_DIR/$KERNEL_TARBALL" "$KERNEL_URL"; then
            # Verify the download is a valid tar.xz file
            if ! file "$RPM_DIR/$KERNEL_TARBALL" | grep -q "XZ compressed data"; then
                print_error "Downloaded file is not a valid XZ archive"
                print_error "URL might be incorrect or kernel.org might be unavailable"
                rm -f "$RPM_DIR/$KERNEL_TARBALL"
                exit 1
            fi
            print_info "Downloaded: $KERNEL_TARBALL ($(du -h "$RPM_DIR/$KERNEL_TARBALL" | cut -f1))"
        else
            print_error "Failed to download kernel tarball"
            print_error "  URL: $KERNEL_URL"
            print_warn "You may need to download manually from https://kernel.org"
            exit 1
        fi
    fi
    echo ""
else
    print_warn "Skipping kernel tarball download"
    echo ""
fi

# ======================================================================
# Step 2: Create patches tarball
# ======================================================================
if [ "$SKIP_PATCHES" = false ]; then
    print_step "Step 2: Creating patches tarball"

    PATCHES_TARBALL="$RPM_DIR/patches.tar.gz"

    if [ -f "$PATCHES_TARBALL" ] && [ "$FORCE_DOWNLOAD" = false ]; then
        print_info "Patches tarball already exists: $(basename $PATCHES_TARBALL)"
    else
        # Check if patches directory (symlink) exists
        if [ ! -L "$RPM_DIR/patches" ] && [ ! -d "$RPM_DIR/patches" ]; then
            print_error "patches directory/symlink not found: $RPM_DIR/patches"
            print_warn "Expected symlink: rpm/patches -> ../intel/patches"
            exit 1
        fi

        # Create tarball from intel/patches
        print_info "Creating tarball from intel/patches/..."
        if tar -czf "$PATCHES_TARBALL" -C "$INTEL_DIR" \
            --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
            patches/; then
            # Verify tarball was created and is not empty
            if [ ! -s "$PATCHES_TARBALL" ]; then
                print_error "Patches tarball is empty or not created"
                exit 1
            fi
            PATCH_COUNT=$(grep -v "^#\|^$" "$INTEL_DIR/patches/series" | wc -l)
            print_info "Created: $PATCHES_TARBALL ($(du -h "$PATCHES_TARBALL" | cut -f1))"
            print_info "  Contains: $PATCH_COUNT patches + series file"
        else
            print_error "Failed to create patches tarball"
            exit 1
        fi
    fi
    echo ""
else
    print_warn "Skipping patches tarball creation"
    echo ""
fi

# ======================================================================
# Step 3: Generate kernel config files
# ======================================================================
if [ "$SKIP_CONFIGS" = false ]; then
    print_step "Step 3: Generating kernel config files"

    CONFIG_FILE="$RPM_DIR/kernel-x86_64.config"

    if [ -f "$CONFIG_FILE" ] && [ "$FORCE_DOWNLOAD" = false ]; then
        print_info "Config file already exists: $(basename $CONFIG_FILE)"
    else
        # Call the generate-configs.sh script
        if [ -x "$SCRIPT_DIR/generate-configs.sh" ]; then
            print_info "Running generate-configs.sh..."
            if "$SCRIPT_DIR/generate-configs.sh"; then
                # Verify config file was generated
                if [ ! -s "$CONFIG_FILE" ]; then
                    print_error "Config file not generated or is empty: $CONFIG_FILE"
                    exit 1
                fi
                print_info "Config generated successfully: $(basename $CONFIG_FILE)"
            else
                print_error "Config generation failed"
                exit 1
            fi
        else
            print_error "generate-configs.sh not found or not executable"
            print_warn "Please run: chmod +x $SCRIPT_DIR/generate-configs.sh"
            exit 1
        fi
    fi
    echo ""
else
    print_warn "Skipping config generation"
    echo ""
fi

# ======================================================================
# Summary
# ======================================================================
print_info "======================================================================"
print_info "Source preparation completed!"
print_info "======================================================================"
print_info ""
print_info "Generated files in rpm/:"
ls -lh "$RPM_DIR" | grep -E "linux-.*\.tar\.|patch-.*\.patch|kernel-.*\.config" || true
print_info ""
print_info "Next steps:"
print_info "  1. Review/customize kernel.spec if needed"
print_info "  2. Build RPM: ./scripts/build.sh"
print_info ""
