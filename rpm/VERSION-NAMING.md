# RPM Package Version Naming

## Overview

RPM packages use a timestamp-based versioning scheme that ensures unique identification of each build and maintains consistency with the project's versioning standard.

## Version Format

**Package Name Format**: `kernel-VERSION-RELEASE.ARCH.rpm`

Where:
- `VERSION`: Base kernel version (e.g., `6.18.20`)
- `RELEASE`: Vendor identifier and timestamp (e.g., `intel+260417t093242z`)
- `ARCH`: Target architecture (e.g., `x86_64`)

**Example**: `kernel-6.18.20-intel+260417t093242z.x86_64.rpm`

## Version Components

### Base Version
The upstream kernel version number:
```
6.18.20
```

### Release String
Format: `VENDOR+TIMESTAMP`

Example: `intel+260417t093242z`

Components:
- **Vendor**: `intel` (identifies the build source)
- **Timestamp**: `260417t093242z` (build timestamp)

### Timestamp Format

Format: `YYMMDDtHHMMSSz`

Example: `260417t093242z`
- `26`: Year 2026
- `04`: April
- `17`: Day 17
- `t`: Time separator (lowercase)
- `09`: Hour 09 (UTC)
- `32`: Minute 32
- `42`: Second 42
- `z`: UTC indicator (lowercase)

## Automatic Version Detection

The build system automatically extracts version information from `debian/changelog`:

```bash
# From debian/changelog first line:
linux (6.18.20-intel+260417t093242z) intel; urgency=medium

# Extracted version (converted to lowercase):
6.18.20-intel+260417t093242z
```

**Note**: Version strings are automatically converted to lowercase for consistent naming.

## Version String Consistency

The same version string is used throughout the system:

- **Package name**: `kernel-6.18.20-intel+260417t093242z.x86_64.rpm`
- **Kernel version**: `6.18.20-intel+260417t093242z` (uname -r)
- **Module path**: `/lib/modules/6.18.20-intel+260417t093242z/`
- **Boot files**: `/boot/vmlinuz-6.18.20-intel+260417t093242z`

This consistency ensures the kernel can locate and load modules correctly after installation.

## Generated Packages

A complete build produces:

```
kernel-6.18.20-intel+260417t093242z.x86_64.rpm         # Main kernel package
kernel-6.18.20-intel+260417t093242z.src.rpm            # Source package
kernel-devel-6.18.20-intel+260417t093242z.x86_64.rpm   # Development headers
kernel-tools-6.18.20-intel+260417t093242z.x86_64.rpm   # Kernel tools
kernel-tools-libs-6.18.20-intel+260417t093242z.x86_64.rpm      # Tool libraries
kernel-tools-devel-6.18.20-intel+260417t093242z.x86_64.rpm     # Tool development files
```

## File Installation Paths

After package installation:

### Boot Files
```
/boot/vmlinuz-6.18.20-intel+260417t093242z
/boot/System.map-6.18.20-intel+260417t093242z
/boot/config-6.18.20-intel+260417t093242z
```

### Kernel Modules
```
/lib/modules/6.18.20-intel+260417t093242z/
```

All kernel modules are installed under this directory, matching the `uname -r` output.

### Development Files
```
/usr/src/kernels/6.18.20-intel+260417t093242z/
```

Headers and build files for compiling external kernel modules.

## Building Packages

The version is automatically extracted during build:

```bash
# Build RPM packages
make rpm

# The build system:
# 1. Reads debian/changelog
# 2. Extracts version: 6.18.20-intel+260417t093242z
# 3. Converts to lowercase
# 4. Passes to rpmbuild via --define "full_version ..."
# 5. Sets LOCALVERSION during kernel build
```

## Updating Version

To change the version, update the first line of `debian/changelog`:

```bash
# Edit changelog
vim debian/changelog

# Example entry:
linux (6.18.20-intel+260512t143000z) intel; urgency=medium

# Rebuild packages
make rpm
```

The new version will be automatically detected and used.

## Manual Version Override

You can manually specify the version at build time:

```bash
cd ~/rpmbuild/SPECS
rpmbuild -ba kernel.spec --define "full_version 6.18.20-intel+260512t143000z"
```

## Case Handling

Version strings are automatically normalized to lowercase:

| Input (changelog)                | Output (RPM package)              |
|----------------------------------|-----------------------------------|
| 6.18.20-Intel+260417T093242Z     | 6.18.20-intel+260417t093242z      |
| 6.18.20-INTEL+260417T093242Z     | 6.18.20-intel+260417t093242z      |
| 6.18.20-intel+260417t093242z     | 6.18.20-intel+260417t093242z      |

This ensures consistent package naming regardless of the case used in the changelog.

## Benefits

1. **Traceability**: Timestamp identifies exact build time
2. **Uniqueness**: Each build has a unique identifier
3. **Consistency**: Same version across package name, uname -r, and module paths
4. **Automation**: Version extracted automatically from changelog
5. **Case-insensitive**: Automatic normalization to lowercase

## Configuration Files

The version naming is configured in:

- **rpm/kernel.spec**: RPM spec file with version variable definitions
- **rpm/scripts/build.sh**: Extracts version from debian/changelog
- **Makefile**: Build orchestration
- **debian/changelog**: Source of version information

## Verification

After building, verify the version consistency:

```bash
# Verify RPM packages
make verify-rpm-packages

# Manual verification
./scripts/verify-kernel-package-rpm.sh build/packages/rpm/kernel-*.rpm
```

See `rpm/KERNEL-VERSION.md` for detailed information about kernel version consistency.

## Troubleshooting

### Version Not Detected

If the build shows `intel+unknown`:

```bash
# Check if debian/changelog exists
ls -l debian/changelog

# Check the format
head -1 debian/changelog

# Expected format:
# linux (VERSION-SUFFIX) DISTRIBUTION; urgency=LEVEL
```

### Version Mismatch After Installation

If `uname -r` doesn't match the package name, see `rpm/KERNEL-VERSION.md` for kernel version configuration details.

## Related Documentation

- `rpm/KERNEL-VERSION.md`: Kernel version string configuration and consistency
- `rpm/README.md`: General RPM packaging documentation
- `scripts/verify-kernel-package-rpm.sh`: Package verification script
