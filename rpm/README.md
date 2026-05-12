# Kernel RPM Packaging

RPM package building system for Linux kernel, based on Fedora kernel packaging practices.

**Note**: RPM packages now use the same versioning scheme as Debian packages, with timestamps automatically extracted from `debian/changelog`. See [VERSION-NAMING.md](VERSION-NAMING.md) for details.

## Directory Structure (Fedora-style)

This implementation follows Fedora's flat directory layout from [Fedora's kernel repository](https://src.fedoraproject.org/rpms/kernel):

```
rpm/
├── kernel.spec                      # RPM spec file
├── kernel-local                     # User customization file (optional)
│
├── patches -> ../common/patches     # Symlink to patches (for reference)
├── linux-6.18.20.tar.xz            # Kernel source tarball (generated)
├── patches.tar.gz                   # Patches archive (generated from common/patches)
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

## Key Features

- **Fedora-compatible**: Uses the same flat directory structure as Fedora's kernel packaging
- **Mainline kernel**: Builds from upstream kernel.org releases (e.g., v6.18.20)
- **Individual patch application**: Applies patches one-by-one from `common/patches/series` for better debugging
- **Complete kernel configs**: Base config + fragments = full .config (~10K lines) for reproducible builds
- **Shared config logic**: Uses `debian/config/amd64/defines.toml` for consistent merge order with Debian
- **Multiple packages**: Builds kernel, kernel-devel, kernel-tools, and kernel-tools-libs

## Quick Start

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
- Create `patches.tar.gz` archive from `common/patches/` (containing series + individual patches)
- Generate complete `.config` files by merging:
  - **Base config** (9566 lines from Fedora)
  - **Config fragments** from `common/config/` (following `debian/config/amd64/defines.toml` order)
  - Result: ~10K line complete configs for reproducible builds
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
```

### 3. Install Packages

```bash
# On Fedora/CentOS/RHEL
sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel-*.rpm

# On Debian/Ubuntu (requires alien or dpkg-deb conversion)
sudo rpm -ivh ~/rpmbuild/RPMS/x86_64/kernel-*.rpm
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
tar -czf rpm/patches.tar.gz -C common patches/
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

## Customization

### Kernel Configuration

The config generation uses a base + fragments approach:

```
kernel-x86_64-base.config (9566 lines, Fedora base)
    +
common/config/amd64/intel/*.cfg (30 fragments, ~400 lines)
    =
kernel-x86_64.config (9984 lines, complete .config)
```

**Config merge order** is defined in `debian/config/amd64/defines.toml` to ensure consistency with Debian builds.

To customize kernel config:

1. **Option A (Recommended)**: Edit config fragments in `common/config/`
   ```bash
   echo "CONFIG_MY_DRIVER=m" >> common/config/amd64/intel/mydriver.cfg
   # Add to debian/config/amd64/defines.toml under config = [...]
   ./scripts/generate-configs.sh
   ```

2. **Option B**: Use `kernel-local` file (for temporary/experimental configs)
   ```bash
   echo "CONFIG_MY_DRIVER=m" >> rpm/kernel-local
   ```

3. **Option C**: Update base config (for major changes)
   ```bash
   # Update rpm/kernel-x86_64-base.config
   # Then regenerate all variants
   ./scripts/generate-configs.sh
   ```

### Adding Patches

Add patches to `common/patches/intel/` and update `common/patches/series`:

```bash
# Add new patch
cp my-feature.patch common/patches/intel/9999-my-feature.patch

# Update series file
echo "intel/9999-my-feature.patch" >> common/patches/series

# Regenerate patches tarball
./scripts/prepare-sources.sh --skip-kernel --skip-configs --skip-scripts --force
```

### Changing Kernel Version

```bash
# Update version in kernel.spec
sed -i 's/%define kernel_version.*/%define kernel_version 6.19.0/' rpm/kernel.spec

# Prepare new sources
./scripts/prepare-sources.sh --version 6.19.0 --force

# Build
./scripts/build.sh --clean
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
- `libperf-jvmti.so` - Perf JVM support

## Comparison with Traditional RPM Layout

| Aspect | Traditional | This Implementation (Fedora-style) |
|--------|-------------|-------------------------------------|
| Layout | `SPECS/` and `SOURCES/` subdirs | Flat (all in rpm/) |
| Patches | Individual `.patch` files | Series-based individual application |
| Configs | One file per variant | Generated from fragments |
| Source tracking | Manual `git add` in subdirs | Direct `git add` in rpm/ |
| Compatibility | Generic | Fedora-compatible |
| Patch debugging | Moderate | Excellent (shows exact failing patch) |

## Prerequisites

### For Debian/Ubuntu Systems

```bash
sudo apt-get install -y \
    rpm \
    build-essential \
    bc bison flex \
    libelf-dev libssl-dev \
    libncurses-dev \
    kmod cpio rsync xz-utils \
    python3 perl \
    libaudit-dev libbinutils-dev \
    libcap-dev libnuma-dev \
    libslang2-dev zlib1g-dev \
    asciidoc xmlto
```

### For Fedora/CentOS/RHEL Systems

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

## Docker Build (Alternative)

```bash
# From project root

# 1. Build Docker image
./docker-build.sh --build-image rpm

# 2. Prepare sources
docker run --rm -v $(pwd):/workspace rpm-builder \
    ./rpm/scripts/prepare-sources.sh --version 6.18.20

# 3. Build RPM
./docker-build.sh rpm
```

## Troubleshooting

### Missing Dependencies

```bash
# Fedora/RHEL
sudo dnf builddep rpm/kernel.spec

# Debian/Ubuntu
# Install packages listed in Prerequisites section above
```

### Build Failures

```bash
# Check build log
less ~/rpmbuild/BUILD/linux-*/build.log

# Clean and retry
./scripts/build.sh --clean
```

### Patch Application Failures

When a patch fails, rpmbuild will show exactly which patch file failed:

```bash
# Check build log for the specific patch
less ~/rpmbuild/BUILD/linux-6.18.20/build.log

# The error message will show something like:
#   ERROR: Failed to apply patch: intel/0123-some-feature.patch

# Test the specific patch manually
cd ~/rpmbuild/BUILD/linux-6.18.20
patch -p1 --dry-run < patches/intel/0123-some-feature.patch

# Fix the patch in common/patches/intel/0123-some-feature.patch
# Then regenerate patches tarball
./scripts/prepare-sources.sh --skip-kernel --skip-configs --skip-scripts --force
```

### Config Issues

```bash
# Verify config syntax
grep -E "^CONFIG_|^# CONFIG_.*is not set" rpm/kernel-x86_64.config

# Regenerate config
./scripts/generate-configs.sh
```

## Integration with Debian Packaging

This RPM packaging shares the repository with Debian packaging:

```
debian-kernel/
├── common/          # Shared patches and configs
│   ├── patches/
│   └── config/
├── debian/          # Debian/Ubuntu packaging
└── rpm/            # Fedora/RHEL packaging (this directory)
```

Both use the same patches and configs from `common/`.

## Resources

- [Fedora Kernel Repository](https://src.fedoraproject.org/rpms/kernel)
- [Fedora Kernel Documentation](https://docs.fedoraproject.org/en-US/quick-docs/kernel/)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [Linux Kernel Build System](https://www.kernel.org/doc/html/latest/kbuild/index.html)
- [Kernel.org](https://www.kernel.org/)

## License

GPL-2.0-or-later (same as Linux kernel)
