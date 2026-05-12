# Kernel Version String Configuration

## Overview

This document explains how the kernel version string is configured in RPM packages to ensure consistency between:
1. RPM package names
2. `uname -r` output after installation
3. Module installation paths (`/lib/modules/`)
4. Boot files in `/boot/`

## Version Components

The full version string consists of:

```
6.18.20-intel+260417t093242z
│       │     └─ Timestamp (YYMMDDTHHMMSSZ)
│       └─ Vendor identifier
└─ Base kernel version
```

## How It Works

### 1. Version Extraction

The build system extracts the full version from `debian/changelog`:

```bash
FULL_VERSION=$(head -1 debian/changelog | sed -n 's/.*(\([^)]*\)).*/\1/p' | tr '[:upper:]' '[:lower:]')
# Result: 6.18.20-intel+260417t093242z
```

### 2. RPM Spec Variables

The spec file defines these variables:

```spec
%define full_version 6.18.20-intel+260417t093242z
%define kernel_version 6.18.20
%define version_suffix intel+260417t093242z
%define buildid 6.18.20-intel+260417t093242z
```

### 3. Kernel Build Configuration

During the build phase, the version is set via `LOCALVERSION`:

```bash
make LOCALVERSION="-intel+260417t093242z" all
make LOCALVERSION="-intel+260417t093242z" modules_install
```

This ensures the kernel's `KERNELRELEASE` matches the package version.

## Installed Files and Paths

After installation, the following files and directories will be created:

### Boot Files
```
/boot/vmlinuz-6.18.20-intel+260417t093242z
/boot/System.map-6.18.20-intel+260417t093242z
/boot/config-6.18.20-intel+260417t093242z
```

### Kernel Modules
```
/lib/modules/6.18.20-intel+260417t093242z/
├── kernel/
│   ├── drivers/
│   ├── fs/
│   └── ...
├── modules.builtin
├── modules.dep
└── ...
```

### Development Files
```
/usr/src/kernels/6.18.20-intel+260417t093242z/
├── Makefile
├── Module.symvers
├── .config
├── include/
└── scripts/
```

## Verification After Installation

### Check Kernel Version

After installing the RPM and rebooting:

```bash
# Should output: 6.18.20-intel+260417t093242z
uname -r
```

### Check Module Path

```bash
# Verify module directory exists
ls -l /lib/modules/6.18.20-intel+260417t093242z/

# Check if modules can be loaded
modprobe <module_name>

# List loaded modules
lsmod
```

### Check Boot Files

```bash
# List all kernel files
ls -lh /boot/vmlinuz-*
ls -lh /boot/System.map-*
ls -lh /boot/config-*
```

### Verify GRUB Entry

```bash
# Check GRUB configuration
grep menuentry /boot/grub2/grub.cfg | grep 6.18.20-intel

# Or for GRUB Legacy
grep title /boot/grub/menu.lst | grep 6.18.20-intel
```

## Common Issues and Solutions

### Issue 1: Module Not Found

**Symptom**: `modprobe: FATAL: Module not found in directory /lib/modules/X`

**Cause**: Version mismatch between kernel (`uname -r`) and module path.

**Solution**: Verify that:
```bash
# These should match
uname -r
ls /lib/modules/
```

If they don't match, the `LOCALVERSION` was not set correctly during build.

### Issue 2: Multiple Module Directories

**Symptom**: Multiple directories in `/lib/modules/`:
```
/lib/modules/6.18.20/          # Wrong
/lib/modules/6.18.20-intel+260417t093242z/  # Correct
```

**Cause**: `LOCALVERSION` not passed to `modules_install` target.

**Solution**: The spec file now explicitly sets `LOCALVERSION` for both `make all` and `make modules_install`.

### Issue 3: GRUB Can't Find Kernel

**Symptom**: Boot menu shows old kernel or new kernel doesn't appear.

**Solution**: Regenerate GRUB configuration:
```bash
# Fedora/RHEL/CentOS
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Debian/Ubuntu
sudo update-grub
```

## Build Process Flow

1. **Extract Version** from `debian/changelog`
2. **Set RPM Variables** (`kernel_version`, `version_suffix`, `buildid`)
3. **Create `localversion` File** with suffix during `%prep`
4. **Build Kernel** with `LOCALVERSION="-intel+260417t093242z"`
5. **Install Modules** with same `LOCALVERSION` to correct path
6. **Install Boot Files** with full version in filename
7. **Package Files** with consistent paths

## Comparison with Debian Packages

### Debian Package Structure
```
Package: linux-image-6.18.20-intel+260417t093242z-amd64
Files:
  /boot/vmlinuz-6.18.20-intel+260417t093242z-amd64
  /lib/modules/6.18.20-intel+260417t093242z-amd64/
```

### RPM Package Structure
```
Package: kernel-6.18.20-intel+260417t093242z.x86_64
Files:
  /boot/vmlinuz-6.18.20-intel+260417t093242z
  /lib/modules/6.18.20-intel+260417t093242z/
```

**Note**: Debian includes architecture suffix (`-amd64`) in the kernel version string, while RPM uses it only in the package name (`.x86_64.rpm`).

## Testing the Configuration

### Before Building

Verify the version will be set correctly:

```bash
# Extract version from changelog
FULL_VERSION=$(head -1 debian/changelog | sed -n 's/.*(\([^)]*\)).*/\1/p' | tr '[:upper:]' '[:lower:]')
echo "Version: $FULL_VERSION"

# Check what files will be in the RPM
cd rpm
rpmspec -q --qf '[%{FILENAMES}\n]' \
    --define "full_version $FULL_VERSION" \
    kernel.spec | grep -E "(boot|lib/modules|usr/src)"
```

### After Building

```bash
# Extract RPM without installing
rpm2cpio kernel-*.rpm | cpio -idmv

# Check the extracted files
ls -R boot/
ls -R lib/modules/
```

### After Installing

```bash
# Install the package
sudo rpm -ivh kernel-*.rpm

# Verify installation
uname -r
ls /lib/modules/
ls /boot/vmlinuz-*
```

## References

- Kernel Makefile: How `KERNELRELEASE` is composed
- Fedora Kernel Spec: Example RPM packaging
- `debian/changelog`: Source of version information
- `rpm/VERSION-NAMING.md`: Package naming conventions
