# Creating Individual Kernel Module Packages

This document describes how to create separate deb packages for specific kernel modules from an existing kernel build.

## Overview

After building the kernel with `dpkg-buildpackage` or your build script, you can extract specific modules and package them separately using the `create-module-package.sh` script.

## Usage

### Basic Syntax

```bash
debian/bin/create-module-package.sh <module-name> <module-pattern> <build-dir>
```

### Parameters

- **module-name**: Name for the package (e.g., `i915`, `e1000e`, `iwlwifi`)
- **module-pattern**: Glob pattern to match module files (e.g., `drivers/gpu/drm/i915/*.ko`)
- **build-dir**: Path to the kernel build directory (e.g., `debian/build/build_amd64_none_amd64`)

## Examples

### 1. Package Intel i915 Graphics Driver

```bash
cd /home/baoli/codes/debian-kernel
debian/bin/create-module-package.sh i915 \
    'drivers/gpu/drm/i915/*.ko' \
    debian/build/build_amd64_none_amd64
```

This creates: `linux-module-i915_<version>_amd64.deb`

### 2. Package Intel Ethernet Driver (e1000e)

```bash
debian/bin/create-module-package.sh e1000e \
    'drivers/net/ethernet/intel/e1000e/*.ko' \
    debian/build/build_amd64_none_amd64
```

### 3. Package Intel WiFi Driver

```bash
debian/bin/create-module-package.sh iwlwifi \
    'drivers/net/wireless/intel/iwlwifi/*.ko' \
    debian/build/build_amd64_none_amd64
```

### 4. Package All DRM Modules

```bash
debian/bin/create-module-package.sh drm \
    'drivers/gpu/drm/*.ko' \
    debian/build/build_amd64_none_amd64
```

### 5. Package Specific Module by Name

```bash
debian/bin/create-module-package.sh amdgpu \
    'drivers/gpu/drm/amd/amdgpu/amdgpu.ko' \
    debian/build/build_amd64_none_amd64
```

## Finding Module Paths

To find the correct module path pattern:

```bash
# List all built modules
find debian/build/build_amd64_none_amd64 -name "*.ko" | sort

# Search for specific module
find debian/build/build_amd64_none_amd64 -name "*i915*.ko"

# List modules by subsystem
find debian/build/build_amd64_none_amd64/drivers/gpu/drm -name "*.ko"
```

## Package Output

The script creates:
- Package file: `../linux-module-<name>_<version>_amd64.deb`
- Package name: `linux-module-<name>`

## Installation

```bash
# Install the module package
sudo dpkg -i ../linux-module-i915_<version>_amd64.deb

# Check installed files
dpkg -L linux-module-i915

# Remove the package
sudo apt remove linux-module-i915
```

## Package Details

Each module package includes:
- The kernel module files (*.ko)
- Proper dependency on the kernel image/base package
- Post-install and post-remove scripts that run `depmod` to update module dependencies
- Package metadata (control file)

## Dependencies

The module packages depend on:
- `linux-image-<version>` OR `linux-base-<version>`

This ensures the module package matches the kernel version.

## Use Cases

1. **Selective Updates**: Update only graphics drivers without rebuilding entire kernel
2. **Testing**: Install test versions of specific modules
3. **Distribution**: Share specific drivers with others
4. **Rollback**: Keep old and new versions of a module for easy rollback
5. **Modular Installation**: Install only needed drivers on different systems

## Notes

- The script must be run after a successful kernel build
- Modules are copied from the build directory, not the installed system
- The package version matches the kernel version
- Running `depmod` after installation ensures module dependencies are correct
- Module signing is preserved if the original modules were signed

## Troubleshooting

### No modules found
- Check the build directory path
- Verify the module pattern matches actual file paths
- Ensure the kernel build completed successfully

### Module not loading after install
- Run `depmod -a` manually
- Check `dmesg` for error messages
- Verify kernel version matches: `uname -r`

### Dependency issues
- Install the matching kernel package first
- Check package dependencies: `dpkg -I <package>.deb`
