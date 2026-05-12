#!/bin/bash
# Kernel RPM package version consistency checker
# Validates that kernel binary version matches module directory name

set -e

KERNEL_RPM="$1"

if [ -z "$KERNEL_RPM" ]; then
    echo "Usage: $0 <kernel-*.rpm>"
    exit 1
fi

if [ ! -f "$KERNEL_RPM" ]; then
    echo "Error: File not found: $KERNEL_RPM"
    exit 1
fi

# Check if this is a kernel package (not kernel-devel, kernel-tools, etc.)
if [[ ! "$(basename "$KERNEL_RPM")" =~ ^kernel-[0-9]+\.[0-9]+\.[0-9]+-.*\.rpm$ ]]; then
    echo "Error: Not a kernel package (should be kernel-VERSION-RELEASE.ARCH.rpm)"
    echo "Given: $(basename "$KERNEL_RPM")"
    exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "=== RPM Kernel Package Version Consistency Check ==="
echo ""

# Extract RPM package
echo "[1/4] Extracting RPM package..."
cd "$TMPDIR"
rpm2cpio "$KERNEL_RPM" | cpio -idm >/dev/null 2>&1

if [ ! -d "$TMPDIR" ]; then
    echo "❌ ERROR: Failed to extract RPM package!"
    exit 1
fi

# Find kernel binary
echo "[2/4] Finding kernel binary..."
KERNEL_FILE=$(find "$TMPDIR/boot" -name "vmlinuz-*" 2>/dev/null | head -1)
if [ ! -f "$KERNEL_FILE" ]; then
    echo "❌ ERROR: No kernel binary found in package!"
    echo "   Expected location: /boot/vmlinuz-*"
    ls -la "$TMPDIR/boot/" 2>/dev/null || echo "   (boot directory not found)"
    exit 1
fi

KERNEL_FILENAME=$(basename "$KERNEL_FILE")

# Check for unexpanded RPM macros in filename
if [[ "$KERNEL_FILENAME" == *"%{"* ]]; then
    echo "⚠️  WARNING: Unexpanded RPM macros detected in filename!"
    echo "   Filename: $KERNEL_FILENAME"
    echo ""
    echo "   This package was built with an old spec file that had bugs."
    echo "   The spec file has been fixed - please rebuild the package."
    echo ""
    echo "   To rebuild: make clean-rpm && make rpm"
    echo ""
    exit 2
fi

# Extract kernel version from binary
echo "[3/4] Extracting kernel version from binary..."
KERNEL_VERSION=$(strings "$KERNEL_FILE" | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+-[^ ]+" | head -1)

if [ -z "$KERNEL_VERSION" ]; then
    echo "❌ ERROR: Could not extract kernel version from binary!"
    echo "   Binary file: $KERNEL_FILENAME"
    exit 1
fi

# Find module directory
echo "[4/4] Checking module directory..."
MODULE_DIRS=$(ls "$TMPDIR/lib/modules/" 2>/dev/null)

if [ -z "$MODULE_DIRS" ]; then
    echo "❌ ERROR: No module directory found in package!"
    echo "   Expected location: /lib/modules/"
    exit 1
fi

# Count module directories (should be exactly one)
MODULE_DIR_COUNT=$(echo "$MODULE_DIRS" | wc -l)
if [ "$MODULE_DIR_COUNT" -ne 1 ]; then
    echo "⚠️  WARNING: Found $MODULE_DIR_COUNT module directories (expected 1):"
    echo "$MODULE_DIRS" | sed 's/^/    /'
fi

MODULE_DIR=$(echo "$MODULE_DIRS" | head -1)

# Count modules
MODULE_COUNT=$(find "$TMPDIR/lib/modules/$MODULE_DIR" -name "*.ko*" 2>/dev/null | wc -l)

# Display results
echo ""
echo "📦 RPM package:        $(basename "$KERNEL_RPM")"
echo "📦 Package version:    $(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$KERNEL_RPM" 2>/dev/null)"
echo ""
echo "🔍 Kernel binary:      $KERNEL_FILENAME"
echo "🔍 Binary version:     $KERNEL_VERSION"
echo "📁 Module directory:   $MODULE_DIR"
echo "📦 Module count:       $MODULE_COUNT"
echo ""

# Verify match
if [ "$KERNEL_VERSION" = "$MODULE_DIR" ]; then
    echo "✅ SUCCESS: Kernel version and module directory match!"
    echo ""
    echo "   When installed, the system will have:"
    echo "   • uname -r output:    $KERNEL_VERSION"
    echo "   • Module path:        /lib/modules/$MODULE_DIR/"
    echo "   • Boot kernel:        /boot/$KERNEL_FILENAME"
    echo ""
    exit 0
else
    echo "❌ FAILURE: Version mismatch detected!"
    echo ""
    echo "⚠️  This will cause boot failure:"
    echo "    • Kernel will identify as:    $KERNEL_VERSION (uname -r)"
    echo "    • But modprobe will look in:  /lib/modules/$MODULE_DIR/"
    echo "    • Result: No modules can be loaded"
    echo ""
    echo "💡 Root cause:"
    echo "    The LOCALVERSION used during kernel build does not match"
    echo "    the LOCALVERSION used during 'make modules_install'"
    echo ""
    echo "💡 Fix for RPM builds:"
    echo "    1. Check rpm/kernel.spec:"
    echo "       • Ensure %{buildid} is set correctly"
    echo "       • Verify LOCALVERSION is passed to both 'make' and 'modules_install'"
    echo ""
    echo "    2. The build commands should be:"
    echo "       make LOCALVERSION=\"-<suffix>\" all"
    echo "       make LOCALVERSION=\"-<suffix>\" modules_install"
    echo ""
    echo "    3. See rpm/KERNEL-VERSION.md for detailed configuration"
    echo ""
    exit 1
fi
