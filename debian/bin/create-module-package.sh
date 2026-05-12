#!/bin/bash
# Script to create a separate deb package for a specific kernel module
# Usage: ./create-module-package.sh <module-name> <module-path-pattern> <build-dir>

set -e

MODULE_NAME="$1"
MODULE_PATTERN="$2"
BUILD_DIR="$3"

if [ -z "$MODULE_NAME" ] || [ -z "$MODULE_PATTERN" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <module-name> <module-path-pattern> <build-dir>"
    echo "Example: $0 i915 'drivers/gpu/drm/i915/*.ko' debian/build/build_amd64_none_amd64"
    exit 1
fi

# Get kernel version from build directory
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory $BUILD_DIR does not exist"
    exit 1
fi

KERNEL_VERSION=$(make -C "$BUILD_DIR" -s kernelrelease 2>/dev/null || echo "unknown")
if [ "$KERNEL_VERSION" = "unknown" ]; then
    echo "Warning: Could not determine kernel version, trying alternate method"
    KERNEL_VERSION=$(basename $(ls -d "$BUILD_DIR"/lib/modules/* 2>/dev/null | head -1) 2>/dev/null || echo "unknown")
fi

echo "Creating package: linux-module-${MODULE_NAME}"
echo "Kernel version: $KERNEL_VERSION"
echo "Module pattern: $MODULE_PATTERN"

# Create temporary package directory
PKG_DIR="debian/linux-module-${MODULE_NAME}"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/lib/modules/${KERNEL_VERSION}/kernel"

# Find and copy matching modules
MODULE_BASE="${BUILD_DIR}/lib/modules/${KERNEL_VERSION}/kernel"
if [ ! -d "$MODULE_BASE" ]; then
    MODULE_BASE="${BUILD_DIR}"
fi

echo "Searching for modules in: $MODULE_BASE"
MODULES_FOUND=0

# Use find to locate modules
while IFS= read -r -d '' module_file; do
    rel_path="${module_file#$MODULE_BASE/}"
    target_dir="$PKG_DIR/lib/modules/${KERNEL_VERSION}/kernel/$(dirname "$rel_path")"
    mkdir -p "$target_dir"
    cp -v "$module_file" "$target_dir/"
    MODULES_FOUND=$((MODULES_FOUND + 1))
done < <(find "$MODULE_BASE" -path "*/$MODULE_PATTERN" -print0 2>/dev/null)

if [ $MODULES_FOUND -eq 0 ]; then
    echo "Error: No modules found matching pattern: $MODULE_PATTERN"
    exit 1
fi

echo "Found and copied $MODULES_FOUND module(s)"

# Create control file
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: linux-module-${MODULE_NAME}
Version: ${KERNEL_VERSION}-1
Section: kernel
Priority: optional
Architecture: amd64
Maintainer: Intel Corporation <baoli.zhang@linux.intel.com>
Depends: linux-image-${KERNEL_VERSION} | linux-base-${KERNEL_VERSION}
Description: ${MODULE_NAME} kernel module for Linux ${KERNEL_VERSION}
 This package contains the ${MODULE_NAME} kernel module(s).
 .
 Module pattern: ${MODULE_PATTERN}
EOF

# Create postinst script to run depmod
cat > "$PKG_DIR/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
    # Get kernel version from our module path
    for kver in /lib/modules/*; do
        if [ -d "$kver/kernel" ]; then
            kver=$(basename "$kver")
            echo "Running depmod for kernel $kver"
            depmod -a "$kver" || true
        fi
    done
fi

#DEBHELPER#

exit 0
EOF

chmod 755 "$PKG_DIR/DEBIAN/postinst"

# Create postrm script
cat > "$PKG_DIR/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    # Get kernel version from our module path
    for kver in /lib/modules/*; do
        if [ -d "$kver/kernel" ]; then
            kver=$(basename "$kver")
            echo "Running depmod for kernel $kver"
            depmod -a "$kver" || true
        fi
    done
fi

#DEBHELPER#

exit 0
EOF

chmod 755 "$PKG_DIR/DEBIAN/postrm"

# Build the package
PACKAGE_FILE="linux-module-${MODULE_NAME}_${KERNEL_VERSION}-1_amd64.deb"
echo "Building package: $PACKAGE_FILE"
dpkg-deb --build "$PKG_DIR" "../$PACKAGE_FILE"

echo "Package created successfully: ../$PACKAGE_FILE"
echo ""
echo "To install: sudo dpkg -i ../$PACKAGE_FILE"
echo "To remove: sudo apt remove linux-module-${MODULE_NAME}"
