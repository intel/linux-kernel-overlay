#!/bin/bash
# Kernel package version consistency checker
# Validates that kernel binary version matches module directory name

set -e

BINARY_DEB="$1"
MODULES_DEB="$2"

if [ -z "$BINARY_DEB" ] || [ -z "$MODULES_DEB" ]; then
    echo "Usage: $0 <linux-binary-*.deb> <linux-modules-*.deb>"
    exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "=== Kernel Package Version Consistency Check ==="
echo ""

# Extract binary package
echo "[1/4] Extracting binary package..."
dpkg-deb -x "$BINARY_DEB" "$TMPDIR/binary" >/dev/null 2>&1

# Extract modules package
echo "[2/4] Extracting modules package..."
dpkg-deb -x "$MODULES_DEB" "$TMPDIR/modules" >/dev/null 2>&1

# Find kernel binary
KERNEL_FILE=$(find "$TMPDIR/binary/boot" -name "vmlinuz-*" | head -1)
if [ ! -f "$KERNEL_FILE" ]; then
    echo "❌ ERROR: No kernel binary found in package!"
    exit 1
fi

# Extract kernel version from binary
echo "[3/4] Extracting kernel version from binary..."
KERNEL_VERSION=$(strings "$KERNEL_FILE" | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+-[^ ]+" | head -1)

if [ -z "$KERNEL_VERSION" ]; then
    echo "❌ ERROR: Could not extract kernel version from binary!"
    exit 1
fi

# Find module directory
echo "[4/4] Checking module directory..."
MODULE_DIR=$(ls "$TMPDIR/modules/usr/lib/modules/" 2>/dev/null || ls "$TMPDIR/modules/lib/modules/" 2>/dev/null)

if [ -z "$MODULE_DIR" ]; then
    echo "❌ ERROR: No module directory found in package!"
    exit 1
fi

# Display results
echo ""
echo "📦 Binary package:  $(basename "$BINARY_DEB")"
echo "📦 Modules package: $(basename "$MODULES_DEB")"
echo ""
echo "🔍 Kernel binary version:  $KERNEL_VERSION"
echo "📁 Module directory name:   $MODULE_DIR"
echo ""

# Verify match
if [ "$KERNEL_VERSION" = "$MODULE_DIR" ]; then
    echo "✅ SUCCESS: Kernel version and module directory match!"
    echo ""
    exit 0
else
    echo "❌ FAILURE: Version mismatch detected!"
    echo ""
    echo "⚠️  This will cause boot failure:"
    echo "    • Kernel will identify as: $KERNEL_VERSION"
    echo "    • But modprobe will look in: /lib/modules/$MODULE_DIR/"
    echo "    • Result: No modules can be loaded (including critical drivers like NVMe)"
    echo ""
    echo "💡 Fix: Ensure CONFIG_LOCALVERSION is set correctly in kernel config"
    echo "    See debian/rules.real for LOCALVERSION_IMAGE configuration"
    echo ""
    exit 1
fi
