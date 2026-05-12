#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Build RPM packages for the kernel (Fedora-style flat layout)
# Usage: ./build.sh [OPTIONS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPM_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$RPM_DIR")"

# Default values
CLEAN_BUILD=0
SKIP_PREP=0
JOBS=$(nproc)
BUILD_ARCH=$(uname -m)
BUILD_BINARY_ONLY=0

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Build kernel RPM packages (Fedora-style).

OPTIONS:
    -c, --clean         Clean build (remove previous builds)
    -s, --skip-prep     Skip preparation steps
    -b, --binary-only   Build binary RPMs only (no source RPM)
    -j, --jobs NUM      Number of parallel jobs (default: $JOBS)
    -a, --arch ARCH     Target architecture (default: $BUILD_ARCH)
    -h, --help          Show this help message

EXAMPLES:
    # Standard build
    ./build.sh

    # Clean build with 8 parallel jobs
    ./build.sh --clean --jobs 8

    # Binary-only build (faster)
    ./build.sh --binary-only

PREREQUISITES:
    Before building, ensure you have prepared the sources:
        ./scripts/prepare-sources.sh --version 6.18.20

    This will generate:
        - rpm/linux-6.18.20.tar.xz
        - rpm/patch-6.18.20-custom.patch
        - rpm/kernel-x86_64.config
        - rpm/mod-sign.sh, etc.

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean)
            CLEAN_BUILD=1
            shift
            ;;
        -s|--skip-prep)
            SKIP_PREP=1
            shift
            ;;
        -b|--binary-only)
            BUILD_BINARY_ONLY=1
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -a|--arch)
            BUILD_ARCH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "======================================================================"
echo "Kernel RPM Build Script (Fedora-style)"
echo "======================================================================"
echo "RPM Directory:    $RPM_DIR"
echo "Spec File:        $RPM_DIR/kernel.spec"
echo "Architecture:     $BUILD_ARCH"
echo "Parallel Jobs:    $JOBS"
echo "======================================================================"

# Check if rpmbuild is installed
if ! command -v rpmbuild &> /dev/null; then
    echo "Error: rpmbuild is not installed"
    echo ""
    echo "Install on Debian/Ubuntu:"
    echo "  sudo apt-get install rpm"
    echo ""
    echo "Install on Fedora/CentOS/RHEL:"
    echo "  sudo dnf install rpm-build"
    exit 1
fi

# Check if spec file exists
SPEC_FILE="$RPM_DIR/kernel.spec"
if [[ ! -f "$SPEC_FILE" ]]; then
    echo "Error: Spec file not found: $SPEC_FILE"
    exit 1
fi

# Check if required source files exist
echo "Checking required source files..."
REQUIRED_FILES=(
    "linux-*.tar.xz"
    "patches.tar.gz"
    "kernel-x86_64.config"
    "kernel-local"
)

MISSING_FILES=0
for pattern in "${REQUIRED_FILES[@]}"; do
    if ! ls "$RPM_DIR"/$pattern &> /dev/null; then
        echo "  [MISSING] $pattern"
        MISSING_FILES=1
    else
        found_file=$(ls "$RPM_DIR"/$pattern | head -1)
        echo "  [OK] $(basename "$found_file")"
    fi
done

if [[ $MISSING_FILES -eq 1 ]]; then
    echo ""
    echo "Error: Missing required source files!"
    echo ""
    echo "Please run prepare-sources.sh first:"
    echo "  ./scripts/prepare-sources.sh --version 6.18.20"
    exit 1
fi

echo ""

# Clean previous builds if requested
if [[ $CLEAN_BUILD -eq 1 ]]; then
    echo "Cleaning previous builds..."
    rm -rf ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SRPMS}/*kernel*
    echo "Clean completed."
    echo ""
fi

# Setup rpmbuild directory structure
echo "Setting up rpmbuild directories..."
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SRPMS,SOURCES,SPECS}

# Copy all source files to ~/rpmbuild/SOURCES/
echo "Copying source files to ~/rpmbuild/SOURCES/..."
rsync -av \
    --include='linux-*.tar.xz' \
    --include='patches.tar.gz' \
    --include='kernel-*.config' \
    --include='kernel-local' \
    --include='mod-*.sh' \
    --include='*.py' \
    --exclude='*' \
    "$RPM_DIR/" ~/rpmbuild/SOURCES/

# Copy spec file to ~/rpmbuild/SPECS/
echo "Copying spec file to ~/rpmbuild/SPECS/..."
cp "$SPEC_FILE" ~/rpmbuild/SPECS/

# Build RPM packages
echo "======================================================================"
echo "Starting RPM build..."
echo "======================================================================"
echo ""

cd ~/rpmbuild/SPECS

# Determine build type
if [[ $BUILD_BINARY_ONLY -eq 1 ]]; then
    BUILD_TYPE="-bb"
    BUILD_DESC="binary RPMs only"
elif [[ $SKIP_PREP -eq 1 ]]; then
    BUILD_TYPE="-bb --short-circuit"
    BUILD_DESC="binary RPMs (short-circuit)"
else
    BUILD_TYPE="-ba"
    BUILD_DESC="source and binary RPMs"
fi

echo "Build type: $BUILD_DESC"
echo ""

# Run rpmbuild
# Note: Using --nodeps because we're on Ubuntu/Debian with equivalent packages installed
# but rpmbuild doesn't recognize Debian packages as satisfying RPM dependencies
rpmbuild $BUILD_TYPE kernel.spec \
    --define "_smp_mflags -j$JOBS" \
    --target="$BUILD_ARCH" \
    --nodeps

BUILD_STATUS=$?

if [[ $BUILD_STATUS -eq 0 ]]; then
    echo ""
    echo "======================================================================"
    echo "Build completed successfully!"
    echo "======================================================================"
    echo ""
    echo "Binary RPM packages:"
    find ~/rpmbuild/RPMS/$BUILD_ARCH/ -name "*.rpm" -type f -exec basename {} \; 2>/dev/null | sort | sed 's/^/  /'
    echo ""
    if [[ $BUILD_BINARY_ONLY -eq 0 ]] && [[ $SKIP_PREP -eq 0 ]]; then
        echo "Source RPM packages:"
        find ~/rpmbuild/SRPMS/ -name "kernel*.src.rpm" -type f -exec basename {} \; 2>/dev/null | sed 's/^/  /'
        echo ""
    fi
    echo "Locations:"
    echo "  Binary RPMs: ~/rpmbuild/RPMS/$BUILD_ARCH/"
    if [[ $BUILD_BINARY_ONLY -eq 0 ]] && [[ $SKIP_PREP -eq 0 ]]; then
        echo "  Source RPM:  ~/rpmbuild/SRPMS/"
    fi
    echo "======================================================================"
else
    echo ""
    echo "======================================================================"
    echo "Build failed with status: $BUILD_STATUS"
    echo "======================================================================"
    echo ""
    echo "Check the build log for errors:"
    echo "  ~/rpmbuild/BUILD/kernel-*/build.log"
    exit $BUILD_STATUS
fi
