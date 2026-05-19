# Intel Linux Kernel Resources

This directory contains Intel-specific kernel resources used by both Debian and RPM packaging systems.

## Directory Structure

```
intel/
├── patches/                    # Shared kernel patches
│   ├── series                 # Patch application order
│   └── intel/                 # Intel-specific patches
│       ├── *.patch           # Upstream bug fixes
│       ├── *.drm             # Graphics driver patches
│       ├── *.audio           # Audio subsystem patches
│       ├── *.ethernet        # Network driver patches
│       └── ...
├── config/                    # Shared kernel configurations
│   ├── config.rt              # Real-time (PREEMPT_RT) kernel config
│   ├── config.test            # Test kernel configuration
│   └── amd64/                 # AMD64 architecture configs
│       ├── base/              # Base kernel configurations
│       │   ├── config.noble-6.8.0-31-generic    # Ubuntu 24.04 Noble (kernel 6.8.0)
│       │   └── config.resolute-7.0.0-14-generic # Ubuntu 26.04 Resolute (kernel 7.0.0)
│       ├── config.test        # AMD64-specific test config
│       └── intel/             # Intel platform configs (amd64)
│           ├── bt.cfg         # Bluetooth configuration
│           ├── camera.cfg     # Camera support
│           ├── drm.cfg        # Graphics (DRM/KMS)
│           ├── ethernet.cfg   # Ethernet drivers
│           ├── features.cfg   # General features
│           ├── security.cfg   # Security features
│           └── ...
└── kernel-rt-parameter        # RT kernel boot parameters (auto-applied on install)
```

## Usage

### Debian Packaging

The Debian packaging system accesses these resources via symbolic links:

- `debian/patches/series` → `../../intel/patches/series`
- `debian/patches/intel` → `../../intel/patches/intel`
- `debian/config/config` → `../../intel/config/amd64/base/config.resolute-7.0.0-14-generic`
- `debian/config/config.rt` → `../../intel/config/config.rt`
- `debian/config/config.test` → `../../intel/config/config.test`
- `debian/config/amd64/config.test` → `../../../intel/config/amd64/config.test`
- `debian/config/amd64/intel` → `../../../intel/config/amd64/intel`

Configuration fragments are referenced in `debian/config/amd64/defines.toml`:

```toml
[flavour.build]
config = [
    'amd64/intel/bt.cfg',
    'amd64/intel/drm.cfg',
    ...
]
```

### RPM Packaging

The RPM packaging system also uses symbolic links:

- `rpm/SOURCES/patches` → `../../intel/patches` (includes `series` file)
- `rpm/SOURCES/kernel-config/config.rt` → `../../../intel/config/config.rt`
- `rpm/SOURCES/kernel-config/config.test` → `../../../intel/config/config.test`
- `rpm/SOURCES/kernel-config/amd64/config.test` → `../../../../intel/config/amd64/config.test`
- `rpm/SOURCES/kernel-config/intel` → `../../../intel/config/amd64/intel`

The RPM spec file references patches in the `%prep` section and configs in the configuration merge section.

### RT Kernel Boot Parameters

The `intel/kernel-rt-parameter` file contains boot parameters that are automatically applied when installing RT kernel packages:

- **Debian**: The `linux-image-*-rt-amd64.deb` package's postinst script reads this file and updates `/etc/default/grub` automatically
- **Location in package**: Installed to `/usr/share/doc/linux-image-VERSION/kernel-rt-parameter`
- **Format**: Single line with space-separated kernel parameters

The parameters are applied during package installation and removed when the last RT kernel is uninstalled. See [RT Kernel Parameters Documentation](../docs/RT-KERNEL-PARAMETERS.md) for details.

## Maintaining Shared Resources

### Adding a New Patch

1. Place the patch file in `intel/patches/intel/`:
   ```bash
   cp my-fix.patch intel/patches/intel/0042-my-fix.patch
   ```

2. Add it to the shared `intel/patches/series` file:
   ```bash
   echo "intel/0042-my-fix.patch" >> intel/patches/series
   ```
   
   This change will automatically be visible to both Debian and RPM packaging systems through symbolic links.

3. For RPM, also reference it in the spec file's `%prep` section if needed.

### Adding a New Config Fragment

1. Create the config file in `intel/config/intel/`:
   ```bash
   cat > intel/config/intel/myfeature.cfg <<EOF
   CONFIG_MY_FEATURE=m
   CONFIG_MY_FEATURE_OPTION=y
   EOF
   ```

2. For Debian, add it to `debian/config/amd64/defines.toml`:
   ```toml
   [flavour.build]
   config = [
       ...
       'amd64/intel/myfeature.cfg',
   ]
   ```

3. For RPM, reference it in the kernel config merge process.

### Modifying RT Kernel Parameters

The RT kernel boot parameters are stored in `intel/kernel-rt-parameter`. To customize them:

1. Edit the parameter file:
   ```bash
   vim intel/kernel-rt-parameter
   ```

2. Parameters should be on a single line, space-separated:
   ```
   parameter1=value1 parameter2=value2 parameter3 ...
   ```

3. Rebuild the RT kernel packages:
   ```bash
   make deb
   ```

4. The new parameters will be automatically applied when installing the RT kernel image package (`linux-image-*-rt-amd64.deb`).

**Current RT parameters include:**
- CPU isolation: `isolcpus`, `nohz_full`, `rcu_nocbs`
- Power management: `intel_pstate=disable`, `idle=poll`, `*_cstate=0`
- Graphics optimization: `i915.enable_guc`, `i915.max_vfs`, `i915.force_probe`
- Clock source: `clocksource=tsc`, `tsc=reliable`
- IOMMU: `intel_iommu=on`, `iommu=pt`
- And many more for RT performance optimization

See the [RT Kernel Parameters Documentation](../docs/RT-KERNEL-PARAMETERS.md) for a complete list and detailed explanation.

### Managing the Patch Series File

The `intel/patches/series` file defines the order in which patches are applied. This is crucial because:
- Some patches may depend on others
- Patch order affects the final kernel state
- Both Debian and RPM must apply patches in the same order

**Editing the series file:**
```bash
# Edit the shared series file
vim intel/patches/series

# The changes are immediately visible to both Debian and RPM
# through symbolic links
```

**Series file format:**
```
# Comments start with #
# Patches are listed relative to the patches/ directory
intel/0001-first-patch.patch
intel/0002-second-patch.drm
# More patches...
```

### Modifying Existing Resources

Simply edit the files in `intel/` — changes will automatically be visible to both packaging systems due to the symbolic links.

## Design Principles

1. **Single Source of Truth**: Patches and configurations are maintained in one place
2. **Packaging-Agnostic**: Common resources are independent of packaging format
3. **Easy Maintenance**: Update once, applies to all packaging systems
4. **Clear Separation**: Packaging-specific files stay in `debian/` and `rpm/`

## File Naming Conventions

### Patches

Format: `NNNN-description.category`

- `NNNN`: 4-digit sequence number (0001, 0002, ...)
- `description`: Brief description in kebab-case
- `category`: Subsystem identifier (optional)
  - `.patch` - General/upstream patches
  - `.drm` - Graphics subsystem
  - `.audio` - Sound subsystem
  - `.ethernet` - Network drivers
  - `.lpss` - Low Power Subsystem
  - `.ipu` - Image Processing Unit
  - `.security` - Security features
  - `.edac` - Error Detection And Correction
  - `.rt` - Real-time kernel

Examples:
- `0001-ice-Fix-memory-leak-in-ice_set_ringparam.patch`
- `0042-drm-i915-mtl-Add-C10-table-for-HDMI-Clock-25175.drm`

### Config Files

**Top-level files:**
- `config.rt` - Real-time (PREEMPT_RT) kernel configuration
- `config.test` - Test kernel configuration for validation
- `kernel-rt-parameter` - RT kernel boot parameters (auto-applied on package install)

**Architecture-specific configs:**
- `amd64/config.test` - AMD64-specific test configuration
- `amd64/intel/*.cfg` - Intel platform config fragments for amd64 architecture

**Config Fragments (amd64/intel/):**

Format: `subsystem.cfg`

Examples:
- `bt.cfg` - Bluetooth
- `drm.cfg` - Direct Rendering Manager
- `ethernet.cfg` - Ethernet drivers
- `security.cfg` - Security features
- `features.cfg` - General kernel features

## Verification

### Check Symbolic Links

```bash
# Verify Debian links
ls -l debian/patches/intel
ls -l debian/config/amd64/intel

# Verify RPM links
ls -l rpm/SOURCES/patches
ls -l rpm/SOURCES/kernel-config/intel
```

### Test Access

```bash
# Should show the same content
ls intel/patches/intel/
ls debian/patches/intel/
ls rpm/SOURCES/patches/intel/

# Should show the same config files
ls intel/config/intel/
ls debian/config/amd64/intel/
ls rpm/SOURCES/kernel-config/intel/
```

## Migration History

**2026-05-19**: RT kernel parameter auto-configuration
- Added `intel/kernel-rt-parameter` file containing boot parameters for RT kernels
- Modified `debian/templates/image.postinst.in` to automatically apply RT parameters on package install
- Modified `debian/templates/image.postrm.in` to automatically remove RT parameters on package removal
- Modified `debian/rules.real` to include RT parameter file in the `linux-image-*-rt-amd64` package
- RT parameters are automatically applied to `/etc/default/grub` during RT kernel installation
- Parameters are removed when the last RT kernel is uninstalled
- Original GRUB config is backed up to `/etc/default/grub.pre-rt`

**2026-04-28**: Initial creation
- Moved patches from `debian/patches/intel/` to `intel/patches/intel/`
- Moved configs from `debian/config/amd64/intel/` to `intel/config/amd64/intel/`
- Moved patch series file from `debian/patches/series` to `intel/patches/series`
- Moved RT and test configs:
  - `debian/config/config.rt` → `intel/config/config.rt`
  - `debian/config/config.test` → `intel/config/config.test`
  - `debian/config/amd64/config.test` → `intel/config/amd64/config.test`
- Organized architecture-specific configs under `intel/config/amd64/`
- Created symbolic links in both Debian and RPM packaging directories
- Maintained backward compatibility with existing build scripts
- Both Debian and RPM now share the same patch application order and kernel configurations

## See Also

- [Main README](../README.md) - Project overview and build instructions
- [Debian Packaging](../debian/README.Intel) - Debian-specific documentation
- [RPM Packaging](../rpm/README.md) - RPM-specific documentation
- [Module Packaging](../debian/MODULE_PACKAGING.md) - Kernel module packaging guide
- [RT Kernel Parameters](../docs/RT-KERNEL-PARAMETERS.md) - RT kernel parameter auto-configuration documentation
- [RT Package Structure](../docs/RT-PACKAGE-STRUCTURE.md) - RT kernel package structure and installation flow
