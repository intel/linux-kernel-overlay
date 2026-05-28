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
│   │   └── intel/                # Intel feature configs
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
│   │   └── amd64/intel -> ../../../intel/config/intel  # Symlink to overlay
│   ├── patches/
│   │   └── intel -> ../../intel/patches/intel          # Symlink to overlay
│   └── README.md     # Debian package guide
│
└── rpm/                            # Fedora/CentOS/RHEL packaging
    ├── kernel-config/
    │   └── intel -> ../../intel/config/intel           # Symlink to overlay
    ├── patches -> ../intel/patches                     # Symlink to overlay
    └── README.md                   # RPM package guide
```

### How the Overlay Works

1. **Single Source of Truth**: All Intel-specific patches and configurations are in `intel/`
2. **Symbolic Links**: Both Debian and RPM packaging access overlay via symlinks
3. **Automatic Integration**: Build systems automatically apply patches and merge configs
4. **Easy Maintenance**: Update once in `intel/`, applies to all packaging formats

### Intel Platform Features

The overlay includes optimizations and drivers for Intel hardware:

- **IPU/NPU**: Image Processing Unit and Neural Processing Unit for AI/ML
- **Graphics**: Intel GPU optimizations (i915, Xe drivers)
- **Networking**: Intel Ethernet (e1000e, igb, ixgbe) and WiFi (iwlwifi)
- **Audio**: Intel SOF (Sound Open Firmware)
- **Security**: Intel SGX, TDX, TME
- **Platform**: LPSS (Low Power Subsystem), PMT, IDXD, Thunderbolt

### Managing Patches and Configurations

For detailed information on adding, organizing, and managing Intel patches and configuration fragments, see **[intel/README.md](intel/README.md)**. This includes:

- How to add and register patches
- Creating configuration fragments
- Patch application order
- Configuration merging process
- Best practices for overlay management

## Quick Start

### Prerequisites

**System Requirements:**
- Linux distribution (Debian 12+, Ubuntu 22.04+, Fedora 40+, CentOS Stream 9)
- 20GB+ free disk space
- 8GB+ RAM (16GB recommended for parallel builds)
- Multi-core processor

**Required Software (Debian/Ubuntu):**

Install build dependencies before starting:

```bash
sudo apt-get update
sudo apt-get install -y \
    git build-essential bc bison flex libssl-dev libelf-dev \
    libncurses-dev dwarves debhelper rsync quilt \
    python3 python3-tomli cpio kmod
```

Package descriptions:
- `git`: Version control system (for cloning repository and tracking changes)
- `build-essential`: GCC compiler and basic build tools
- `bc`, `bison`, `flex`: Build utilities required by kernel
- `libssl-dev`: SSL library for kernel crypto and module signing
- `libelf-dev`: ELF library for BTF (BPF Type Format) support
- `libncurses-dev`: For menuconfig (optional)
- `dwarves`: Provides pahole for BTF generation
- `debhelper`: Debian package creation tools
- `rsync`: File synchronization (used by Makefile)
- `quilt`: Patch management tool
- `python3`, `python3-tomli`: Required for gencontrol.py
- `cpio`, `kmod`: Kernel packaging dependencies

**Git Configuration:**

Git configuration is **optional** for building (v2.0 uses `quilt` directly, not `git quiltimport`). Only configure git if you plan to commit changes:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

> **Note**: Unlike v1.0 which required git configuration for patch application (`git quiltimport`), v2.0 uses `quilt push` directly, so you can build without configuring git.

**Required Software (Fedora/RHEL/CentOS):**

```bash
sudo dnf install -y \
    git @development-tools bc bison flex openssl-devel elfutils-libelf-devel \
    ncurses-devel dwarves rpm-build rsync quilt \
    python3 python3-tomli cpio kmod
```

### Building Debian Packages

```bash
# 1. Setup (first time only)
make deb-setup

# 2. Build packages
make deb              # Full build (kernel + tools + headers)
make deb-minimal      # Minimal build (kernel image only, faster)

# 3. Install
sudo dpkg -i build/packages/deb/linux-image-*-amd64_*.deb
sudo update-grub
sudo reboot

# For RT kernel (auto-configures boot parameters)
sudo dpkg -i build/packages/deb/linux-image-*-rt-amd64_*.deb
# RT parameters are automatically applied to /etc/default/grub
sudo reboot
```

**Output**: Packages in `build/packages/deb/`

**Build Modes**:
- **Full build** (default): Builds kernel image + tools (perf, cpupower, etc.) + headers (~2-4 hours)
- **Minimal build**: Builds kernel image only, skips tools (~1-2 hours, faster for testing)

See [debian/README.md](debian/README.md) for detailed Debian package documentation including:
- Package types and descriptions
- Installation scenarios
- Troubleshooting guides
- Package verification

### Building RPM Packages

```bash
# 1. Prepare sources (first time only)
cd rpm
./scripts/prepare-sources.sh --version 6.18.20

# 2. Build packages
./scripts/build.sh

# 3. Install
sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel-*.rpm
sudo reboot
```

**Output**: Packages in `~/rpmbuild/RPMS/x86_64/`

See [rpm/README.md](rpm/README.md) for detailed RPM package documentation.

### Using the Makefile

The Makefile provides a unified interface for all build operations:

```bash
# Show all available targets
make help

# Debian builds
make deb-setup     # First-time setup
make deb           # Build packages (full: kernel + tools)
make deb-minimal   # Build packages (minimal: kernel only, faster)
make clean-deb     # Clean Debian artifacts

# RPM builds
make rpm-prepare   # Prepare sources
make rpm           # Build packages
make clean-rpm     # Clean RPM artifacts

# Build both formats
make all

# Check status
make status
```

### Building in Docker

For clean, reproducible builds without installing dependencies:

```bash
# Build Docker image (first time only, Ubuntu 24.04 by default)
./docker-build.sh --build-image

# Or specify Ubuntu version explicitly
./docker-build.sh --build-image --dockerfile Dockerfile.ubuntu26.04

# Build packages in container
./docker-build.sh deb              # Full build (kernel + tools)
./docker-build.sh deb-minimal      # Minimal build (kernel only, faster)
# Or use --mode option
./docker-build.sh deb --mode minimal

# Or open interactive shell
./docker-build.sh shell
```

See [docker/README.md](docker/README.md) for Docker build details.

## Configuration Workflow

### Quick Workflow Overview

1. **Add/modify patches** in `intel/patches/intel/`
2. **Add/modify configs** in `intel/config/intel/`
3. **Test build** with `make deb` or `make rpm`
4. **Commit changes** to git

For detailed step-by-step instructions on adding Intel features, including patch management, configuration fragments, and best practices, see **[intel/README.md](intel/README.md)**.

## Version Information

- **Current Version**: v2.0
- **Base Kernel**: Upstream Linux kernel with Intel patches
- **Supported Platforms**: Intel x86_64 processors
- **Packaging Formats**: Debian (.deb), RPM (.rpm)

### Version Format

Package versions use the format: `<upstream>-intel+<timestamp>`

Example: `6.18.20-intel+260417t093242z`
- `6.18.20` - Upstream kernel version
- `intel` - Intel distribution marker
- `260417t093242z` - Build timestamp (YYMMDDTHHMMSSz)

## Module Packaging

Create standalone packages for individual kernel modules:

```bash
# Example: i915 graphics driver
./debian/bin/create-module-package.sh i915 \
    'drivers/gpu/drm/i915/*.ko' \
    debian/build/build_amd64_none_amd64
```

See [debian/MODULE_PACKAGING.md](debian/MODULE_PACKAGING.md) for detailed module packaging documentation.

## Package Documentation

- **[Debian Packages](debian/README.md)** - Complete guide to Debian packages
  - Package types and descriptions
  - Installation scenarios
  - Troubleshooting
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

- **[RT Kernel Parameters](docs/RT-KERNEL-PARAMETERS.md)** - RT kernel auto-configuration
  - Automatic boot parameter setup
  - Parameter customization
  - Installation and removal process

- **[RT Package Structure](docs/RT-PACKAGE-STRUCTURE.md)** - RT kernel package details
  - Package composition
  - Installation flow
  - Which package does what

## Troubleshooting

### Common Issues

**"No rule to make target 'debian/control'"**
```bash
# Run setup first
make deb-setup
```

**"Source tarball not found"**
```bash
# For Debian
make deb-setup

# For RPM
cd rpm && ./scripts/prepare-sources.sh --version 6.18.20
```

**Module loading issues**
```bash
# Verify kernel version matches module directory
scripts/verify-kernel-package.sh \
    build/packages/deb/linux-binary-*.deb \
    build/packages/deb/linux-modules-*.deb
```

**Configuration conflicts**
```bash
# Regenerate configuration
make -f debian/rules debian/control
cd rpm && ./scripts/generate-configs.sh
```

See package-specific documentation for detailed troubleshooting:
- Debian: [debian/README.md](debian/README.md#common-issues--solutions)
- RPM: [rpm/README.md](rpm/README.md#troubleshooting)

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
