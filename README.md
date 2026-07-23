# Intel Kernel Packaging System

Custom Linux kernel packaging system supporting both Debian (.deb) and RPM (.rpm) packages, optimized for Intel platforms.

> **⚠️ Important Notice**
> 
> This repository and its releases are provided for **reference and evaluation purposes only**. They are **not intended for production use**. Use at your own risk.

## Version 2.0 - Major Upgrade

**This is version 2.0** of the Intel kernel overlay system, representing a complete architectural redesign from v1.0.

### What's New in v2.0

**v1.0** (legacy: `iot-kernel-overlay`) was a simple overlay system with:
- Single shell script (`build.sh`) for building
- Basic quilt-based patch management
- Debian packages only
- Manual kernel configuration merging
- Limited to Ubuntu OS

**v2.0** (this repository) is a production-grade packaging system with:
- ✅ **Multi-Format Support**: Both Debian (.deb) and RPM (.rpm) packages from one repository
  > **Note**: Only the Debian (.deb) packages are officially evaluated. The RPM (.rpm) build is provided as an **experimental** option and is not officially validated.
- ✅ **Unified Build System**: Comprehensive Makefile replacing simple shell scripts
- ✅ **Kernel Tools Packaging**: Build kernel tools (perf, cpupower, bpftool, etc.) as separate deb packages
- ✅ **Docker Integration**: Containerized builds for clean, reproducible environments
- ✅ **Enhanced Overlay Architecture**: Shared Intel patches/configs via symlinks for both Debian and RPM
- ✅ **Professional Packaging**: Follows Debian kernel team's modern build system (defines.toml, gencontrol.py)
- ✅ **Automated Verification**: Package consistency checks to ensure correct installation
- ✅ **Better Maintainability**: Organized documentation, structured scripts, comprehensive tooling

## Overview

This repository provides tools and configuration for building custom kernel packages with Intel-specific features and optimizations. It supports:

- **Debian/Ubuntu** packaging (.deb) - [Details](debian/README.md)
- **Fedora/CentOS/RHEL** packaging (.rpm) - [Details](rpm/README.md)
- **Intel Platform Optimization** - Custom patches and configurations
- **Unified Build Interface** - Single Makefile for all operations

### Key Features

- ✅ **Multi-Format Support**: Build both Debian and RPM packages from one repository
- ✅ **Intel Platform Optimization**: Customized configuration for Intel processors and hardware
- ✅ **Shared Overlay System**: Single source of truth for patches and configurations
- ✅ **Multiple Kernel Flavours**: Standard (amd64), Real-Time (rt-amd64), Test kernels
- ✅ **RT Kernel Auto-Configuration**: Automatic boot parameter setup for RT kernels
- ✅ **Module Packaging Tools**: Create standalone packages for individual kernel modules
- ✅ **Docker Support**: Clean, reproducible builds in containers

## Intel Overlay System

This repository uses an **overlay system** to manage Intel-specific patches and configurations separately from the base kernel and packaging logic.

### Directory Structure

```
debian-kernel/
├── intel/                         # OVERLAY: Intel patches & configs (shared)
│   ├── patches/                   # Intel kernel patches
│   │   ├── intel/                # Intel-specific patches
│   │   │   ├── 0001-ippu-driver.patch
│   │   │   ├── 0002-npu-support.patch
│   │   │   └── ...
│   │   └── series                # Patch application order
│   ├── config/                    # Intel platform configurations
│   │   └── amd64/intel/          # Intel feature configs
│   │       ├── camera.cfg        # Camera/IPU support
│   │       ├── drm.cfg           # Graphics optimizations
│   │       ├── ethernet.cfg      # Intel Ethernet drivers
│   │       ├── security.cfg      # Intel security features
│   │       ├── npu.cfg           # Neural Processing Unit
│   │       └── ...
│   ├── kernel-rt-parameter        # RT kernel boot parameters (auto-applied)
│   └── README.md                  # Overlay documentation
│
├── debian/                         # Debian/Ubuntu packaging
│   ├── config/
│   │   └── amd64/intel -> ../../../intel/config/amd64/intel  # Symlink to overlay
│   ├── patches/
│   │   └── intel -> ../../intel/patches/intel          # Symlink to overlay
│   └── README.md     # Debian package guide
│
└── rpm/                            # Fedora/CentOS/RHEL packaging
    ├── patches -> ../intel/patches                     # Symlink to overlay
    ├── scripts/                                         # Generates configs from intel/config/
    ├── kernel-x86_64-base.config                        # Base RPM kernel config
    └── README.md                   # RPM package guide
```

### How the Overlay Works

1. **Single Source of Truth**: All Intel-specific patches and configurations are in `intel/`
2. **Shared Access**: Debian accesses the overlay via symlinks; RPM symlinks patches and generates its configs from the overlay
3. **Automatic Integration**: Build systems automatically apply patches and merge configs
4. **Easy Maintenance**: Update once in `intel/`, applies to all packaging formats

## Package Naming Scheme

This project uses **vendor-prefixed naming** to support multi-version kernel repositories and coexistence with system packages:

### Package Names

All packages use the `linux-intel-*` prefix:

- **Source package**: `linux-intel`
- **Kernel packages**: `linux-intel-image-amd64`, `linux-intel-modules-*-amd64`, `linux-intel-headers-*`
- **Tool packages**: `linux-intel-cpupower`, `linux-intel-perf`, `linux-intel-bpftool`, etc.
- **Library packages**: `libcpupower-intel1`, `libcpupower-intel-dev`

### Binary Names

Tool binaries use the `-intel` suffix to avoid conflicts with system tools:

- **cpupower**: `cpupower-intel`, `turbostat-intel`, `x86_energy_perf_policy-intel`, `intel-speed-select-intel`
- **perf**: `perf-intel`
- **bpftool**: `bpftool-intel`
- **rtla**: `rtla-intel`
- **usbip**: `usbip-intel`, `usbipd-intel`

### Version Format

**Current Implementation:**

Package versions follow the format:
```
{version}-{type}+{environment}+{release}+{cve}+{timestamp}
```

**Example:**
```
7.0.0-mainline+preprod+linux+260617t095128z
```

**Components:**
- `7.0.0` - Upstream kernel version (required)
- `mainline` - Kernel type (required)
  - `mainline` - Intel Edge kernel based on community mainline
  - `lts` - Intel Edge kernel based on community LTS
  - `next` - Next-generation development kernel (early-stage, lower stability)
- `preprod` - Environment (optional, omitted for prod)
  - `preprod` - Pre-production, for testing
  - *(omitted)* - Production-ready
- `linux` - Release name (required)
  - `linux` - Standard Linux release
  - `xenomai` - Xenomai real-time variant
  - `android` - Android kernel
  - `emt` - Embedded variant
- `cve` - CVE flag (optional)
  - Present when the build includes CVE fixes
- `260617t095128z` - Build timestamp (YYMMDDtHHMMSSz)

**Additional Examples:**
- `7.0.0-mainline+linux+260617t095128z` - Production mainline kernel
- `6.18.0-lts+preprod+linux+cve+260617t095128z` - Pre-prod LTS with CVE fixes
- `6.12.0-next+preprod+linux+260617t095128z` - Pre-prod next-generation kernel
- `7.1-rc3-mainline+xenomai+260617t095128z` - RC version with Xenomai

**Version Format Design Notes:**

For detailed design rationale and alternative approaches considered, see [debian/README.md - Version Format Design](debian/README.md#version-format-design).

### Rationale

- **Coexistence**: Multiple kernel versions can be installed simultaneously
- **BKC Integration**: Support for BKC (Best Known Configuration) environments
- **APT Repositories**: Enable multi-version repositories with proper dependency resolution
- **System Compatibility**: Packages automatically replace system equivalents when installed

See [debian/README.md](debian/README.md#package-conflicts-with-system-tools) for details on package conflicts and automatic replacement.

## Quick Start

### Building in Docker

For clean, reproducible builds without installing dependencies:

```bash
# Build Docker image (first time only, Ubuntu 26.04 by default)
./docker-build.sh --build-image

# Or specify the Ubuntu version explicitly
./docker-build.sh --build-image --dockerfile Dockerfile.ubuntu26.04   # Ubuntu 26.04 (default)
./docker-build.sh --build-image --dockerfile Dockerfile.ubuntu24.04   # Ubuntu 24.04

# Build Debian packages in container
./docker-build.sh deb              # Full build (kernel + tools)
./docker-build.sh deb-minimal      # Minimal build (kernel only, faster)

# Build RPM packages in container (experimental; auto-prepares sources, standard + RT)
./docker-build.sh rpm
./docker-build.sh rpm-prepare      # Only prepare RPM sources

# Build both Debian and RPM packages
./docker-build.sh all

# Show all available commands and options
./docker-build.sh -h
```

**Output**: Debian packages in `build/packages/deb/`, RPM packages in `build/packages/rpm/`.

To install the generated `.deb` packages (recommended order, RT kernel, and tool packages), see **[debian/README.md — Installation Order](debian/README.md#installation-order)**.

See [docker/README.md](docker/README.md) for Docker build details.

## Configuration Workflow

### Quick Workflow Overview

1. **Add/modify patches** in `intel/patches/intel/`
2. **Add/modify configs** in `intel/config/amd64/intel/`
3. **Test build** with `./docker-build.sh deb` or `./docker-build.sh rpm`
4. **Commit changes** to git

For detailed step-by-step instructions, see **[intel/README.md](intel/README.md)** — covering how to add and register patches, create configuration fragments, patch application order, the config merging process, and overlay best practices.

## Version Information

- **Current Version**: v2.0
- **Base Kernel**: Upstream Linux kernel with Intel patches
- **Supported Platforms**: Intel x86_64 processors
- **Packaging Formats**: Debian (.deb), RPM (.rpm)
- **Package Naming**: See [Package Naming Scheme](#package-naming-scheme) above

## Package Documentation

- **[Debian Packages](debian/README.md)** - Complete guide to Debian packages
  - Package types and descriptions
  - Installation scenarios
  - Standard vs RT kernel comparison
  - RT kernel auto-configuration

- **[RPM Packages](rpm/README.md)** - Complete guide to RPM packages
  - RPM build system
  - Customization options
  - Fedora integration

- **[Intel Overlay](intel/README.md)** - Shared patches and configurations
  - Patch management
  - Configuration fragments
  - Intel platform features
  - RT kernel boot parameters

- **[RT Kernel Parameters](intel/kernel-rt-parameter)** - RT kernel auto-configuration parameter list
  - Automatic boot parameter setup
  - Parameter customization

## Contributing

For detailed information on adding Intel features, patch management, and configuration guidelines, see **[intel/README.md](intel/README.md)**.

### General Guidelines

- Follow Linux kernel coding style for patches
- Test builds for both Debian and RPM formats
- Use clear, descriptive commit messages
- Include "Co-Authored-By" for pair programming

## License

This package combines:
- Linux kernel: GPL-2.0
- Debian packaging: GPL-2.0
- Intel customizations: GPL-2.0 (Copyright Intel Corporation)

See individual files for specific license information.

## Resources

- [Linux Kernel Documentation](https://www.kernel.org/doc/)
- [Intel Developer Zone](https://www.intel.com/content/www/us/en/developer/overview.html)
- [Debian Kernel Packaging](https://kernel-team.pages.debian.net/kernel-handbook/)
- [Fedora Kernel Packaging](https://docs.fedoraproject.org/en-US/quick-docs/kernel/)

## Support

For issues and questions:
- Check troubleshooting sections in documentation
- Review existing issues in the repository
- See package-specific guides for detailed help
