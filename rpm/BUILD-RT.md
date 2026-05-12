# Building RT (Real-Time) Kernel RPM Packages

## Overview

This project supports building both standard and PREEMPT_RT real-time kernel packages.

## RT Kernel Variants

| Variant | Package Name | Config File | Use Case |
|---------|-------------|-------------|----------|
| Standard | `kernel-*` | `kernel-x86_64.config` | General purpose workloads |
| RT | `kernel-rt-*` | `kernel-x86_64-rt.config` | Real-time workloads requiring deterministic latency |

## Building RT Kernel

### Quick Start

```bash
# Build RT kernel packages
make rpm-rt
```

This will:
1. Check if source files are prepared (runs `rpm-prepare` if needed)
2. Build RT kernel using `kernel-x86_64-rt.config`
3. Generate packages named `kernel-rt-*` instead of `kernel-*`
4. Verify package consistency
5. Place packages in `build/packages/rpm/`

### Generated RT Packages

After building, you will have:

```
kernel-rt-6.18.20-intel+260417t093242z.x86_64.rpm
kernel-rt-6.18.20-intel+260417t093242z.src.rpm
kernel-rt-devel-6.18.20-intel+260417t093242z.x86_64.rpm
kernel-rt-tools-6.18.20-intel+260417t093242z.x86_64.rpm
kernel-rt-tools-libs-6.18.20-intel+260417t093242z.x86_64.rpm
kernel-rt-tools-devel-6.18.20-intel+260417t093242z.x86_64.rpm
```

### Docker Build

```bash
# Build RT kernel in Docker container
./docker-build.sh rpm-rt
```

## RT Configuration

The RT kernel config is generated from:

1. **Base config**: `rpm/kernel-x86_64-base.config` (Fedora base)
2. **Intel config fragments**: `common/config/amd64/intel/*.cfg`
3. **RT config**: `common/config/config.rt` (PREEMPT_RT settings)

The merge order is defined in `debian/config/amd64/defines.toml` under the `rt-amd64` flavour.

## Installing RT Kernel

```bash
# Install RT kernel
sudo rpm -ivh kernel-rt-*.rpm

# Reboot and select RT kernel from GRUB menu
sudo reboot

# After boot, verify RT kernel is running
uname -r
# Should show: 6.18.20-intel+260417t093242z

# Verify PREEMPT_RT is enabled
uname -a | grep PREEMPT
# Should show: PREEMPT_RT or similar
```

## Building Both Standard and RT

```bash
# Build standard kernel
make rpm

# Build RT kernel
make rpm-rt

# Both packages will be in build/packages/rpm/
ls build/packages/rpm/
```

## Differences Between Standard and RT

### Package Names
- Standard: `kernel-*`
- RT: `kernel-rt-*`

### Kernel Configuration
- Standard: General purpose optimizations
- RT: PREEMPT_RT patches and real-time optimizations

### Installation
Both can be installed side-by-side:
```bash
# Install both
sudo rpm -ivh kernel-*.rpm kernel-rt-*.rpm

# You will have two boot options:
# - 6.18.20-intel+260417t093242z (standard)
# - 6.18.20-intel+260417t093242z (RT)
```

## Advanced Usage

### Manual rpmbuild

```bash
# Prepare sources first
make rpm-prepare

# Build RT kernel manually
cd ~/rpmbuild/SPECS
rpmbuild -ba kernel.spec \
    --define "full_version 6.18.20-intel+260417t093242z" \
    --define "with_rt 1" \
    --nodeps
```

### Customizing RT Config

Edit the RT-specific config:
```bash
vim common/config/config.rt
```

Then regenerate configs:
```bash
make rpm-prepare
```

## Troubleshooting

### Config File Not Found

If you see:
```
Error: RT config not found: rpm/kernel-x86_64-rt.config
Run 'make rpm-prepare' to generate configs.
```

Solution:
```bash
make rpm-prepare
```

### Verifying RT Config

Check that RT config was used:
```bash
# Extract RPM
rpm2cpio kernel-rt-*.rpm | cpio -idmv

# Check boot config
grep PREEMPT boot/config-*
# Should show: CONFIG_PREEMPT_RT=y
```

## Related Documentation

- `rpm/README.md`: General RPM packaging guide
- `rpm/VERSION-NAMING.md`: Package naming conventions
- `rpm/KERNEL-VERSION.md`: Kernel version consistency
- `common/config/config.rt`: RT-specific kernel options
