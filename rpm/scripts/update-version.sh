#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Update kernel version in spec file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPM_DIR="$(dirname "$SCRIPT_DIR")"
SPEC_FILE="$RPM_DIR/SPECS/kernel.spec"

KERNEL_VERSION=""
KERNEL_RELEASE=""
GIT_REPO=""
GIT_TAG=""
AUTO_COMMIT=1

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Update kernel version information in spec file.

OPTIONS:
    -v, --version VER   Kernel version (e.g., 6.8.0)
    -r, --release REL   Package release number (e.g., 1)
    -g, --repo URL      Git repository URL
    -t, --tag TAG       Git tag or branch
    -n, --no-commit     Do not commit changes to git
    -h, --help          Show this help message

EXAMPLES:
    # Update to kernel 6.8.0, release 1
    ./update-version.sh -v 6.8.0 -r 1

    # Update with git source
    ./update-version.sh -v 6.8.0 -r 1 \\
        -g https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \\
        -t v6.8

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            KERNEL_VERSION="$2"
            shift 2
            ;;
        -r|--release)
            KERNEL_RELEASE="$2"
            shift 2
            ;;
        -g|--repo)
            GIT_REPO="$2"
            shift 2
            ;;
        -t|--tag)
            GIT_TAG="$2"
            shift 2
            ;;
        -n|--no-commit)
            AUTO_COMMIT=0
            shift
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

# Validate inputs
if [[ -z "$KERNEL_VERSION" ]]; then
    echo "Error: Kernel version is required"
    usage
    exit 1
fi

if [[ -z "$KERNEL_RELEASE" ]]; then
    echo "Error: Package release is required"
    usage
    exit 1
fi

# Check if spec file exists
if [[ ! -f "$SPEC_FILE" ]]; then
    echo "Error: Spec file not found: $SPEC_FILE"
    exit 1
fi

echo "======================================================================"
echo "Updating Kernel Version in Spec File"
echo "======================================================================"
echo "Spec File:        $SPEC_FILE"
echo "Kernel Version:   $KERNEL_VERSION"
echo "Package Release:  $KERNEL_RELEASE"
[[ -n "$GIT_REPO" ]] && echo "Git Repository:   $GIT_REPO"
[[ -n "$GIT_TAG" ]] && echo "Git Tag:          $GIT_TAG"
echo "======================================================================"

# Backup spec file
cp "$SPEC_FILE" "$SPEC_FILE.bak"

# Update version in spec file
sed -i "s/^%define rpmversion.*/%define rpmversion  $KERNEL_VERSION/" "$SPEC_FILE"
sed -i "s/^%define pkgrelease.*/%define pkgrelease  $KERNEL_RELEASE/" "$SPEC_FILE"

# Update git source if provided
if [[ -n "$GIT_REPO" ]]; then
    sed -i "s|^%global kernel_src_repo.*|%global kernel_src_repo $GIT_REPO|" "$SPEC_FILE"
fi

if [[ -n "$GIT_TAG" ]]; then
    sed -i "s|^%global kernel_src_tag.*|%global kernel_src_tag $GIT_TAG|" "$SPEC_FILE"
fi

# Update timestamp
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)
sed -i "s/^%define specrelease.*/%define specrelease ${TIMESTAMP}_${KERNEL_RELEASE}%{?dist}/" "$SPEC_FILE"

echo ""
echo "Version updated successfully!"
echo ""

# Show diff
echo "Changes made:"
echo "======================================================================"
diff -u "$SPEC_FILE.bak" "$SPEC_FILE" || true
echo "======================================================================"

# Commit changes if requested
if [[ $AUTO_COMMIT -eq 1 ]]; then
    cd "$RPM_DIR/.."
    if git diff --quiet "$SPEC_FILE"; then
        echo ""
        echo "No changes to commit."
    else
        git add "$SPEC_FILE"
        git commit -m "rpm: Update kernel version to $KERNEL_VERSION-$KERNEL_RELEASE

Updated kernel spec file:
- Version: $KERNEL_VERSION
- Release: $KERNEL_RELEASE
- Timestamp: $TIMESTAMP"
        echo ""
        echo "Changes committed to git."
    fi
fi

# Cleanup backup
rm -f "$SPEC_FILE.bak"

echo ""
echo "Done!"
