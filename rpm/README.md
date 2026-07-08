# Kernel RPM Packaging

RPM package building system for Linux kernel, based on Fedora kernel packaging practices.

**Note**: RPM packages now use the same versioning scheme as Debian packages, with timestamps automatically extracted from `debian/changelog`. See [VERSION-NAMING.md](VERSION-NAMING.md) for details.

## Key Features

- **Fedora-compatible**: Uses the same flat directory structure as Fedora's kernel packaging
- **Mainline kernel**: Builds from upstream kernel.org releases (e.g., v6.18.20)
- **Individual patch application**: Applies patches one-by-one from `intel/patches/series` for better debugging
- **Complete kernel configs**: Base config + fragments = full .config (~10K lines) for reproducible builds
- **Shared config logic**: Uses `debian/config/amd64/defines.toml` for consistent merge order with Debian
- **Multiple packages**: Builds kernel, kernel-devel, kernel-tools, and kernel-tools-libs

## Quick Start

### Prerequisites

**Debian/Ubuntu:**

```bash
sudo apt-get install -y \
    rpm \
    build-essential \
    bc bison flex \
    libelf-dev libssl-dev \
    libncurses-dev \
    kmod cpio rsync xz-utils \
    python3 perl \
    libaudit-dev binutils-dev \
    libcap-dev libnuma-dev \
    libslang2-dev zlib1g-dev \
    asciidoc xmlto
```

**Fedora/CentOS/RHEL:**

```bash
sudo dnf install -y \
    rpm-build rpmdevtools \
    gcc make binutils \
    bc bison flex \
    elfutils-devel openssl-devel \
    ncurses-devel \
    kmod xz rsync \
    python3 perl \
    audit-libs-devel binutils-devel \
    libcap-devel numactl-devel \
    slang-devel zlib-devel \
    asciidoc xmlto
```

### 1. Prepare Source Files

First, prepare all required source files:

```bash
cd rpm

# Prepare sources for kernel 6.18.20
./scripts/prepare-sources.sh --version 6.18.20

# Or force regenerate all
./scripts/prepare-sources.sh --version 6.18.20 --force
```

This will:
- Download `linux-6.18.20.tar.xz` from kernel.org
  - **Note**: Version normalization follows kernel.org naming convention:
    * `7.0.0` → downloads `linux-7.0.tar.xz` (initial releases omit `.0`)
    * `7.0.0-rc1` → downloads `linux-7.0-rc1.tar.xz` (RC versions also omit `.0`)
    * `6.18.0` → downloads `linux-6.18.tar.xz`, but `6.18.33` → `linux-6.18.33.tar.xz`
- Create `patches.tar.gz` archive from `intel/patches/` (containing series + individual patches)
- Generate complete `.config` files by merging (delegates to `generate-configs.sh`):
  - **Base config** (9566 lines from Fedora): `rpm/kernel-x86_64-base.config`
  - **Config fragments** from `intel/config/` (following `debian/config/amd64/defines.toml` order)
  - Result: ~10K line complete configs for reproducible builds
  - Generates **all flavours** in one run:
    - `kernel-x86_64.config` — standard (`amd64`)
    - `kernel-x86_64-rt.config` — RT, adds `config.rt` fragment (`rt-amd64`)
    - `kernel-x86_64-test.config` — test (`test`)
  - **Note**: config generation is skipped if `kernel-x86_64.config` already exists.
    Use `--force` (or run `./scripts/generate-configs.sh` directly) to regenerate.
    Finalized during build via `make olddefconfig` in the spec's `%prep`.
- Download Fedora build scripts (`mod-sign.sh`, etc.)

**Note**: 
- Patches are applied individually during build for better debugging
- Config merge order follows `debian/config/amd64/defines.toml` for consistency with Debian builds

### 2. Build RPM Packages

```bash
# Standard build (source + binary RPMs)
./scripts/build.sh

# Binary-only build (faster)
./scripts/build.sh --binary-only

# Clean build with custom jobs
./scripts/build.sh --clean --jobs 16

# RT (PREEMPT_RT) build (uses kernel-x86_64-rt.config, produces kernel-rt-* packages)
./scripts/build.sh --define "with_rt 1"
```

### 3. Install Packages

```bash
# On Fedora/CentOS/RHEL
sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel-*.rpm

# On Debian/Ubuntu (requires alien or dpkg-deb conversion)
sudo rpm -ivh ~/rpmbuild/RPMS/x86_64/kernel-*.rpm
```

### Building in Docker (Alternative)

```bash
# From project root

# 1. Build Docker image
./docker-build.sh --build-image rpm

# 2. Build RPM
./docker-build.sh rpm
```

## Detailed Workflow

### Prepare Sources Script

The `prepare-sources.sh` script orchestrates the entire source preparation:

```bash
./scripts/prepare-sources.sh [OPTIONS]

Options:
  -v, --version VERSION    Kernel version (e.g., 6.18.20)
  -f, --force              Force re-download and regenerate
  --skip-kernel            Skip kernel tarball download
  --skip-patches           Skip patch generation
  --skip-configs           Skip config generation
  --skip-scripts           Skip Fedora scripts download
  -b, --branch BRANCH      Fedora branch for scripts (default: rawhide)
```

### Individual Source Preparation

You can also prepare sources individually:

```bash
# Generate configs only
./scripts/generate-configs.sh

# Download Fedora scripts only
./scripts/setup-fedora-sources.sh

# Create patches tarball manually
tar -czf patches.tar.gz -C ../intel patches/
```

### Build Options

```bash
./scripts/build.sh [OPTIONS]

Options:
  -c, --clean         Clean previous builds
  -b, --binary-only   Build binary RPMs only (no source RPM)
  -s, --skip-prep     Skip preparation (faster rebuilds)
  -j, --jobs NUM      Number of parallel jobs
  -a, --arch ARCH     Target architecture
```

## Package Overview

### kernel
- `/boot/vmlinuz-*` - Kernel image
- `/boot/System.map-*` - Kernel symbols
- `/boot/config-*` - Kernel configuration
- `/lib/modules/*` - Kernel modules

### kernel-devel
- `/usr/src/kernels/*` - Headers and build infrastructure for building external modules

### kernel-tools
- `perf` - Performance analysis tool
- `turbostat` - CPU frequency and power monitoring
- `cpupower` - CPU power management
- `x86_energy_perf_policy` - Power policy tool
- `tmon` - Thermal monitoring

### kernel-tools-libs
- `libcpupower.so` - CPU power library

## Directory Structure (Fedora-style)

This implementation follows Fedora's flat directory layout from [Fedora's kernel repository](https://src.fedoraproject.org/rpms/kernel):

```
rpm/
├── kernel.spec                      # RPM spec file
├── kernel-local                     # User customization file (optional)
│
├── patches -> ../intel/patches     # Symlink to patches (for reference)
├── linux-6.18.20.tar.xz            # Kernel source tarball (generated)
├── patches.tar.gz                   # Patches archive (generated from intel/patches)
│
├── kernel-x86_64-base.config       # Base config from Fedora (9566 lines, tracked in git)
├── kernel-x86_64.config            # Generated: base + fragments (9984 lines)
├── kernel-x86_64-rt.config         # Generated: base + fragments + RT (10014 lines)
│
├── mod-sign.sh                      # Fedora build scripts (downloaded)
├── mod-denylist.sh
├── filtermods.py
│
└── scripts/                         # Build automation scripts
    ├── prepare-sources.sh           # Prepare all source files
    ├── generate-configs.sh          # Generate configs: base + fragments (uses defines.toml)
    ├── build.sh                     # Build RPM packages
    ├── setup-fedora-sources.sh      # Download Fedora scripts
    └── update-version.sh            # Update kernel version
```

## Integration with Debian Packaging

This RPM packaging shares the repository with Debian packaging:

```
debian-kernel/
├── intel/          # Shared patches and configs
│   ├── patches/
│   └── config/
├── debian/          # Debian/Ubuntu packaging
└── rpm/            # Fedora/RHEL packaging (this directory)
```

Both use the same patches and configs from `intel/`.

## Resources

- [Fedora Kernel Repository](https://src.fedoraproject.org/rpms/kernel)
- [Fedora Kernel Documentation](https://docs.fedoraproject.org/en-US/quick-docs/kernel/)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [Linux Kernel Build System](https://www.kernel.org/doc/html/latest/kbuild/index.html)
- [Kernel.org](https://www.kernel.org/)

## License

GPL-2.0-or-later (same as Linux kernel)
