# Intel Kernel Features Update Guide

This document explains how to update Intel-owned kernel features, patches, and configurations in this repository.

## Overview

All Intel-specific customizations are managed in the `intel/` directory:
- **Patches**: `intel/patches/intel/*.patch`
- **Configs**: `intel/config/intel/*.cfg`
- **Patch Order**: `intel/patches/series`

Both Debian and RPM packaging automatically use these files via symbolic links.

## Quick Reference

```bash
# Add new patch
cp new-feature.patch intel/patches/intel/0042-new-feature.patch
echo "intel/0042-new-feature.patch" >> intel/patches/series

# Add new config
cp new-feature.cfg intel/config/intel/new-feature.cfg

# Test changes
make clean-deb && make deb-setup && make deb

# Commit changes
git add intel/
git commit -m "feat(intel): Add new feature support"
```

---

## Managing Patches

### Directory Structure

```
intel/patches/
├── intel/                    # Intel-specific patches
│   ├── 0001-feature-a.patch
│   ├── 0002-feature-b.patch
│   └── ...
└── series                    # Patch application order
```

### Adding a New Patch

**Step 1: Prepare the patch file**

```bash
# Copy your patch to intel/patches/intel/
cp /path/to/your-patch.patch intel/patches/intel/

# Rename with sequential number (check existing patches first)
cd intel/patches/intel/
ls -1 *.patch | tail -5  # Check last patch number
mv your-patch.patch 0042-descriptive-name.patch
```

**Naming Convention:**
- Format: `NNNN-brief-description.patch`
- `NNNN`: 4-digit sequential number (0001, 0002, etc.)
- Use lowercase, hyphens for spaces
- Example: `0042-add-npu-driver-support.patch`

**Step 2: Register in series file**

```bash
# Add to intel/patches/series
echo "intel/0042-descriptive-name.patch" >> intel/patches/series
```

**Step 3: Verify patch format**

Your patch should follow standard kernel patch format:

```patch
From: Author Name <author@example.com>
Date: Mon, 20 May 2026 10:00:00 +0800
Subject: [PATCH] Brief description

Detailed explanation of what this patch does and why.

Signed-off-by: Author Name <author@example.com>
---
 path/to/file.c | 10 +++++++++-
 1 file changed, 9 insertions(+), 1 deletion(-)

diff --git a/path/to/file.c b/path/to/file.c
index abc123..def456 100644
--- a/path/to/file.c
+++ b/path/to/file.c
@@ -10,7 +10,15 @@
 ... patch content ...
```

**Step 4: Test the patch**

```bash
# Clean and rebuild to test patch application
make clean-deb
make deb-setup  # This will apply all patches

# Check if patch applied successfully
cd build/kernel
quilt applied | grep your-patch-name
```

### Updating an Existing Patch

**Option 1: Replace the patch file**

```bash
# Replace old patch with new version
cp /path/to/updated-patch.patch intel/patches/intel/0042-feature-name.patch

# Test
make clean-deb && make deb-setup
```

**Option 2: Modify patch directly**

```bash
# Edit the patch file
vim intel/patches/intel/0042-feature-name.patch

# Test changes
make clean-deb && make deb-setup
```

### Removing a Patch

**Step 1: Remove from series file**

```bash
# Edit series file and remove the line
vim intel/patches/series

# Or use sed
sed -i '/0042-feature-name.patch/d' intel/patches/series
```

**Step 2: Delete the patch file**

```bash
rm intel/patches/intel/0042-feature-name.patch
```

**Step 3: Test**

```bash
make clean-deb && make deb-setup
```

### Reordering Patches

Patch application order matters. Edit `intel/patches/series`:

```bash
vim intel/patches/series
```

Move lines up or down to change application order. Patches are applied top-to-bottom.

**Example series file:**

```
# Core platform patches (apply first)
intel/0001-platform-init.patch
intel/0002-platform-config.patch

# Driver patches
intel/0010-ipu-driver.patch
intel/0011-npu-driver.patch

# Bug fixes (apply last)
intel/0030-fix-memory-leak.patch
intel/0031-fix-race-condition.patch
```

---

## Managing Configuration Files

### Directory Structure

```
intel/config/intel/
├── camera.cfg          # Camera/IPU features
├── drm.cfg            # Graphics features
├── ethernet.cfg       # Ethernet drivers
├── npu.cfg            # NPU support
├── security.cfg       # Security features
├── wifi.cfg           # WiFi drivers
└── ...
```

### Adding a New Configuration File

**Step 1: Create the .cfg file**

```bash
# Create new config file
vim intel/config/intel/new-feature.cfg
```

**Step 2: Add configuration options**

Config files use standard kernel config format:

```bash
# Intel New Feature Configuration
CONFIG_NEW_FEATURE=y
CONFIG_NEW_FEATURE_DEBUG=n
CONFIG_NEW_FEATURE_MODULE=m

# Dependencies
CONFIG_DEPENDENCY_A=y
CONFIG_DEPENDENCY_B=m
```

**Format rules:**
- One option per line
- Use `=y` (built-in), `=m` (module), or `=n` (disabled)
- Use `# comment` for documentation
- Group related options together
- Add blank lines for readability

**Step 3: Register in defines.toml**

**IMPORTANT:** New config files must be added to the merge order list.

```bash
# Edit the architecture-specific defines file
vim debian/config/amd64/defines.toml

# Find the [[flavour]] section for 'amd64' and add your file
[[flavour]]
name = 'amd64'
[flavour.build]
config = [
    'amd64/intel/bt.cfg',
    'amd64/intel/camera.cfg',
    # ... existing files ...
    'amd64/intel/new-feature.cfg',    # <-- Add here
    'amd64/intel/wifivpro.cfg',
]

# Also add to 'rt-amd64' flavour (same config list + config.rt)
[[flavour]]
name = 'rt-amd64'
[flavour.build]
config = [
    'amd64/intel/bt.cfg',
    # ... same list as amd64 ...
    'amd64/intel/new-feature.cfg',    # <-- Add here too
    'amd64/intel/wifivpro.cfg',
    'config.rt',
]

# And to 'test' flavour if applicable
```

**Where to place your new file in the list:**
- Consider dependencies: if your config depends on options set by another file, place it **after** that file
- If other configs might override your settings, place your file **after** them
- General rule: place near related configs (e.g., new camera config near camera.cfg)

**Step 4: Test the configuration**

```bash
# Clean and rebuild
make clean-deb
make deb-setup

# Verify config was applied
cd build/kernel
grep CONFIG_NEW_FEATURE debian/build/config.amd64_none_amd64
```

### Updating an Existing Configuration File

Simply edit the file directly:

```bash
# Edit config file
vim intel/config/intel/camera.cfg

# Add new options or modify existing ones
# Example: enable a new camera sensor
echo "CONFIG_VIDEO_NEW_SENSOR=m" >> intel/config/intel/camera.cfg

# Test
make clean-deb && make deb-setup
```

### Removing a Configuration File

**Step 1: Remove from defines.toml**

```bash
# Edit the architecture-specific defines file
vim debian/config/amd64/defines.toml

# Remove the line from all flavour sections:
# - [[flavour]] name = 'amd64'
# - [[flavour]] name = 'rt-amd64'
# - [[flavour]] name = 'test' (if present)

# Before:
config = [
    'amd64/intel/camera.cfg',
    'amd64/intel/obsolete-feature.cfg',    # <-- Remove this line
    'amd64/intel/ethernet.cfg',
]

# After:
config = [
    'amd64/intel/camera.cfg',
    'amd64/intel/ethernet.cfg',
]
```

**Step 2: Delete the file**

```bash
rm intel/config/intel/obsolete-feature.cfg
```

**Step 3: Test**

```bash
make clean-deb && make deb-setup
```

### Configuration Merge Order

**IMPORTANT:** Configuration files are merged in a **specific order** defined in `debian/config/amd64/defines.toml`.

**Merge order for standard kernel (amd64):**

```toml
config = [
    'amd64/intel/bt.cfg',           # 1. Bluetooth
    'amd64/intel/camera.cfg',       # 2. Camera/IPU
    'amd64/intel/cert.cfg',         # 3. Certificates
    'amd64/intel/debug.cfg',        # 4. Debug features
    'amd64/intel/dma.cfg',          # 5. DMA
    'amd64/intel/drm.cfg',          # 6. Graphics
    'amd64/intel/edac.cfg',         # 7. EDAC
    'amd64/intel/ethernet.cfg',     # 8. Ethernet
    'amd64/intel/features.cfg',     # 9. General features
    'amd64/intel/fw.cfg',           # 10. Firmware
    'amd64/intel/hid.cfg',          # 11. HID
    'amd64/intel/idxd.cfg',         # 12. IDXD
    'amd64/intel/intel-iommu.cfg',  # 13. IOMMU
    'amd64/intel/intel_th.cfg',     # 14. Intel Trace Hub
    'amd64/intel/ipu.cfg',          # 15. IPU
    'amd64/intel/lpss.cfg',         # 16. LPSS
    'amd64/intel/media.cfg',        # 17. Media
    'amd64/intel/nmi.cfg',          # 18. NMI
    'amd64/intel/npu.cfg',          # 19. NPU
    'amd64/intel/perf.cfg',         # 20. Performance
    'amd64/intel/pks.cfg',          # 21. PKS
    'amd64/intel/pmc_core.cfg',     # 22. PMC
    'amd64/intel/pmt.cfg',          # 23. PMT
    'amd64/intel/security.cfg',     # 24. Security
    'amd64/intel/sof.cfg',          # 25. Audio (SOF)
    'amd64/intel/tbt.cfg',          # 26. Thunderbolt
    'amd64/intel/tgpio.cfg',        # 27. Timed GPIO
    'amd64/intel/thermal.cfg',      # 28. Thermal
    'amd64/intel/uncoref.cfg',      # 29. Uncore
    'amd64/intel/wifivpro.cfg',     # 30. WiFi
]
```

**For RT kernel (rt-amd64):** Same list + `'config.rt'` at the end

**Merge behavior:**
- Files are merged **top to bottom** (first to last)
- **Later files override earlier files** if the same CONFIG option appears multiple times
- Example:
  ```bash
  # In camera.cfg (position 2)
  CONFIG_VIDEO_FEATURE=m
  
  # In security.cfg (position 24, applied later)
  CONFIG_VIDEO_FEATURE=y    # This wins! Overrides camera.cfg
  ```

**When to update the merge order:**

You need to edit `debian/config/amd64/defines.toml` if you:
1. **Add a new .cfg file** - must add to the `config = [...]` list
2. **Remove a .cfg file** - must remove from the list
3. **Change merge priority** - reorder the list

**Example: Adding a new config file**

```bash
# 1. Create the new config file
vim intel/config/intel/new-feature.cfg

# 2. Add to defines.toml at desired position
vim debian/config/amd64/defines.toml

# Add line in the config array:
config = [
    'amd64/intel/bt.cfg',
    'amd64/intel/camera.cfg',
    # ... other files ...
    'amd64/intel/new-feature.cfg',  # <-- Add here
    'amd64/intel/wifivpro.cfg',
]

# 3. If this is for RT kernel, also add to rt-amd64 flavour section
# 4. Test
make clean-deb && make deb-setup
```

**Important notes:**
- The path in defines.toml is relative to `debian/config/`
- Since `amd64/intel/` is a symlink to `intel/config/intel/`, you're actually referencing `intel/config/intel/*.cfg`
- All three flavours (amd64, rt-amd64, test) use the same Intel config files
- RT kernel adds `'config.rt'` at the end to enable RT-specific options

### Configuration File Best Practices

**1. Organize by feature domain:**
```
camera.cfg      # All camera/IPU related configs
drm.cfg         # All graphics configs
ethernet.cfg    # All ethernet configs
security.cfg    # All security configs
```

**2. Use descriptive comments:**
```bash
# Intel IPU6 Camera Support
CONFIG_VIDEO_INTEL_IPU6=m
CONFIG_IPU_ISYS_BRIDGE=y

# Intel NPU (Neural Processing Unit)
CONFIG_INTEL_NPU=m
CONFIG_INTEL_NPU_DEBUG=n
```

**3. Group related options:**
```bash
# WiFi 6E support
CONFIG_IWLWIFI=m
CONFIG_IWLMVM=m
CONFIG_IWLWIFI_DEBUG=n

# WiFi 7 support (new)
CONFIG_IWLWIFI_AX210=y
CONFIG_IWLWIFI_BE200=y
```

**4. Document dependencies:**
```bash
# Requires CONFIG_PCI=y (already enabled in base config)
CONFIG_INTEL_IDXD=m

# Requires CONFIG_DMA_ENGINE=y
CONFIG_INTEL_IOATDMA=m
```

---

## RT Kernel Configuration

RT kernel boot parameters are managed separately:

### RT Boot Parameters File

**File**: `intel/kernel-rt-parameter`

**Format:**
```bash
# One parameter per line
isolcpus=1-3
nohz_full=1-3
rcu_nocbs=1-3
intel_pstate=disable
```

### Updating RT Parameters

```bash
# Edit the file
vim intel/kernel-rt-parameter

# Parameters are automatically applied during RT kernel installation
# No manual intervention needed
```

---

## Updating debian/changelog

### Overview

The `debian/changelog` file is **critical** for Debian package versioning and metadata. It must be updated whenever you make changes to patches or configurations.

**File location**: `debian/changelog`

### Changelog Format

Debian changelog follows a strict format:

```
package-name (version) distribution; urgency=level

  * Change description line 1
  * Change description line 2
    - Sub-item (indented with spaces)
  * Change description line 3

 -- Maintainer Name <email@example.com>  Day, DD Mon YYYY HH:MM:SS +ZONE
```

**Important formatting rules:**
- First line: package name, version in parentheses, distribution, urgency
- Change entries start with `  * ` (2 spaces, asterisk, space)
- Sub-items use `    - ` (4 spaces, dash, space)
- Last line: ` -- ` (space, two dashes, space), then maintainer, two spaces, date
- Date format is RFC 2822 (output of `date -R`)
- **Exact spacing matters** - deviation will cause build failures

### When to Update

Update `debian/changelog` when you:
- Add, update, or remove patches
- Add, update, or remove configuration files
- Change kernel version
- Make any changes that affect the built packages

### How to Update

**Method 1: Manual edit (recommended)**

```bash
# Edit changelog
vim debian/changelog

# Add new entry at the top (before existing entries)
# Example:
linux (6.18.20-intel+260520t120000z) intel; urgency=medium

  * Add new NPU driver support
    - Added patch intel/0055-npu-driver.patch
    - Added configuration intel/config/intel/npu-new.cfg
  * Update camera driver
    - Updated patch intel/0010-ipu-driver.patch
  * Remove deprecated Thunderbolt feature
    - Removed patch intel/0025-tbt-old.patch

 -- Your Name <your.name@intel.com>  Tue, 20 May 2026 12:00:00 +0800
```

**Method 2: Using dch (debchange) tool**

```bash
# Add new entry with automated formatting
DEBEMAIL="your.name@intel.com" DEBFULLNAME="Your Name" \
    dch --newversion 6.18.20-intel+260520t120000z \
    --distribution intel \
    "Add new NPU driver support"

# Add more entries to current version
dch -a "Update camera driver"
dch -a "Remove deprecated Thunderbolt feature"
```

### Version Format

**Current format**: `6.18.20-intel+260520t120000z`

Components:
- `6.18.20` - Upstream kernel version
- `-intel` - Distribution identifier
- `+260520t120000z` - Build timestamp
  - `260520` - Date: YYMMDD (May 20, 2026)
  - `t` - Separator
  - `120000` - Time: HHMMSS (12:00:00)
  - `z` - UTC timezone indicator

**When to increment:**
- Change timestamp for new builds: `+260520t120000z` → `+260520t130000z`
- Keep upstream version unless rebasing to new kernel: `6.18.20` → `6.18.21`

### Example Updates

#### Example 1: Adding a new feature

```bash
vim debian/changelog

# Add at the top:
linux (6.18.20-intel+260520t140000z) intel; urgency=medium

  * Add Intel NPU Gen3 support
    - Added patch intel/0060-npu-gen3-driver.patch
    - Added configuration intel/config/intel/npu-gen3.cfg
    - Updated defines.toml with new config file

 -- John Doe <john.doe@intel.com>  Tue, 20 May 2026 14:00:00 +0800
```

#### Example 2: Updating existing patches

```bash
linux (6.18.20-intel+260520t150000z) intel; urgency=medium

  * Backport security fixes from upstream
    - Updated intel/0030-security-fix-cve-2026-1234.patch
    - Updated intel/0031-security-fix-cve-2026-5678.patch
  * Improve IPU6 camera performance
    - Updated intel/0010-ipu6-driver.patch

 -- Jane Smith <jane.smith@intel.com>  Tue, 20 May 2026 15:00:00 +0800
```

#### Example 3: Removing deprecated features

```bash
linux (6.18.20-intel+260520t160000z) intel; urgency=medium

  * Remove deprecated hardware support
    - Removed intel/0020-old-platform.patch
    - Removed intel/config/intel/deprecated-hw.cfg
    - Updated defines.toml to remove old-platform config

 -- Alice Brown <alice.brown@intel.com>  Tue, 20 May 2026 16:00:00 +0800
```

#### Example 4: Kernel version upgrade

```bash
linux (6.18.21-intel+260521t100000z) intel; urgency=medium

  * Rebase to upstream kernel 6.18.21
    - Rebased all Intel patches to 6.18.21
    - Resolved conflicts in graphics and networking patches
    - Verified all patches apply cleanly

 -- Bob Johnson <bob.johnson@intel.com>  Wed, 21 May 2026 10:00:00 +0800
```

### Changelog Best Practices

1. **Be descriptive**: Clearly describe what changed and why
2. **Group related changes**: Use sub-items for related modifications
3. **Reference patches/configs**: Mention specific files that changed
4. **One entry per build**: Each version should have one changelog entry
5. **Maintain chronological order**: Newest entries at the top
6. **Test after updating**: Run `make deb-setup` to verify changelog format

### Common Mistakes to Avoid

❌ **Wrong spacing**
```
* Change item    # Missing leading spaces
 - Sub-item      # Wrong indentation
--Author         # Missing space before --
```

✅ **Correct spacing**
```
  * Change item    # 2 spaces before *
    - Sub-item     # 4 spaces before -
 -- Author         # 1 space, --, 1 space
```

❌ **Wrong date format**
```
 -- Author <email>  2026-05-20           # Wrong format
 -- Author <email>  May 20, 2026         # Wrong format
```

✅ **Correct date format**
```
 -- Author <email>  Tue, 20 May 2026 12:00:00 +0800
```

❌ **Missing blank line**
```
  * Change 1
  * Change 2
 -- Author <email>  Date
linux (old-version)...  # Missing blank line here
```

✅ **Correct blank line**
```
  * Change 1
  * Change 2

 -- Author <email>  Date

linux (old-version)...  # Blank line separates entries
```

### Validation

After updating changelog, validate the format:

```bash
# Check changelog syntax
dpkg-parsechangelog

# Should output version info without errors
# Example output:
# Source: linux
# Version: 6.18.20-intel+260520t120000z
# Distribution: intel
# Urgency: medium
# Maintainer: Your Name <your.name@intel.com>
# Date: Tue, 20 May 2026 12:00:00 +0800
# Changes:
#  linux (6.18.20-intel+260520t120000z) intel; urgency=medium
#  .
#    * Add new NPU driver support
# ...
```

If there are errors, fix the formatting and try again.

---

## Testing Changes

### Test Workflow

```bash
# 1. Make your changes (patches or configs)
vim intel/patches/intel/0042-new-patch.patch
echo "intel/0042-new-patch.patch" >> intel/patches/series

# 2. Clean previous build
make clean-deb

# 3. Setup build (applies patches and merges configs)
make deb-setup

# 4. Verify patches applied
cd build/kernel
quilt applied | tail -5

# 5. Verify config changes
grep CONFIG_YOUR_FEATURE debian/build/config.amd64_none_amd64

# 6. Build packages
cd ../..
make deb

# 7. Test installation (in VM recommended)
sudo dpkg -i build/packages/deb/linux-image-*.deb
sudo reboot
```

### Quick Verification Commands

```bash
# Check patch application status
cd build/kernel && quilt applied

# Check specific config option
grep CONFIG_OPTION build/kernel/debian/build/config.amd64_none_amd64

# List all Intel configs being applied
ls -1 intel/config/intel/*.cfg

# Count patches
wc -l intel/patches/series
```

---

## Common Workflows

### Workflow 1: Update Existing Feature

**Scenario:** Update IPU driver with new patch version

```bash
# 1. Replace old patch with new version
cp /path/to/updated-ipu-patch.patch intel/patches/intel/0010-ipu-driver.patch

# 2. Update changelog
vim debian/changelog
# Add entry:
# linux (6.18.20-intel+260520t130000z) intel; urgency=medium
#
#   * Update IPU driver to fix performance issues
#     - Updated intel/0010-ipu-driver.patch
#
#  -- Your Name <your.name@intel.com>  Tue, 20 May 2026 13:00:00 +0800

# 3. Test
make clean-deb && make deb-setup && make deb

# 4. Commit
git add intel/patches/intel/0010-ipu-driver.patch
git add debian/changelog
git commit -m "fix(intel): Update IPU driver patch"
```

### Workflow 2: Add New Feature

**Scenario:** Add support for a new Intel hardware feature

```bash
# 1. Add patch
cp new-feature.patch intel/patches/intel/0050-new-feature.patch
echo "intel/0050-new-feature.patch" >> intel/patches/series

# 2. Add config file
cat > intel/config/intel/new-feature.cfg <<EOF
# Intel New Feature Support
CONFIG_INTEL_NEW_FEATURE=m
CONFIG_INTEL_NEW_FEATURE_DEBUG=n
EOF

# 3. Register config in defines.toml
vim debian/config/amd64/defines.toml
# Add 'amd64/intel/new-feature.cfg' to config arrays in:
#   - [[flavour]] name = 'amd64'
#   - [[flavour]] name = 'rt-amd64'
#   - [[flavour]] name = 'test' (if applicable)

# 4. Update changelog
vim debian/changelog
# Add new entry at the top with updated timestamp:
# linux (6.18.20-intel+260520t140000z) intel; urgency=medium
#
#   * Add new feature support
#     - Added patch intel/0050-new-feature.patch
#     - Added configuration intel/config/intel/new-feature.cfg
#     - Updated defines.toml
#
#  -- Your Name <your.name@intel.com>  Tue, 20 May 2026 14:00:00 +0800

# 5. Test
make clean-deb && make deb-setup && make deb

# 6. Commit
git add intel/patches/intel/0050-new-feature.patch
git add intel/patches/series
git add intel/config/intel/new-feature.cfg
git add debian/config/amd64/defines.toml
git add debian/changelog
git commit -m "feat(intel): Add new feature support"
```

### Workflow 3: Remove Obsolete Feature

**Scenario:** Remove support for deprecated hardware

```bash
# 1. Remove patch
sed -i '/old-feature.patch/d' intel/patches/series
rm intel/patches/intel/0020-old-feature.patch

# 2. Remove config from defines.toml
vim debian/config/amd64/defines.toml
# Remove 'amd64/intel/old-feature.cfg' from all flavour sections

# 3. Delete config file
rm intel/config/intel/old-feature.cfg

# 4. Update changelog
vim debian/changelog
# Add entry:
# linux (6.18.20-intel+260520t150000z) intel; urgency=medium
#
#   * Remove deprecated hardware support
#     - Removed intel/0020-old-feature.patch
#     - Removed intel/config/intel/old-feature.cfg
#     - Updated defines.toml
#
#  -- Your Name <your.name@intel.com>  Tue, 20 May 2026 15:00:00 +0800

# 5. Test
make clean-deb && make deb-setup && make deb

# 6. Commit
git add -u intel/
git add debian/config/amd64/defines.toml
git add debian/changelog
git commit -m "feat(intel): Remove deprecated feature support"
```

### Workflow 4: Backport Upstream Patches

**Scenario:** Backport security fixes from newer kernel

```bash
# 1. Get patch from upstream
wget https://git.kernel.org/pub/scm/.../patch -O /tmp/fix.patch

# 2. Format patch with proper header
cat > intel/patches/intel/0060-security-fix.patch <<'EOF'
From: Upstream Author <author@kernel.org>
Date: Mon, 20 May 2026 10:00:00 +0800
Subject: [PATCH] Fix security vulnerability

Backported from upstream commit abc123def456.

Signed-off-by: Your Name <your.name@intel.com>
---
EOF
cat /tmp/fix.patch >> intel/patches/intel/0060-security-fix.patch

# 3. Register patch
echo "intel/0060-security-fix.patch" >> intel/patches/series

# 4. Update changelog
vim debian/changelog
# Add entry:
# linux (6.18.20-intel+260520t160000z) intel; urgency=high
#
#   * Backport security fixes from upstream
#     - Added intel/0060-security-fix.patch (CVE-2026-XXXX)
#
#  -- Your Name <your.name@intel.com>  Tue, 20 May 2026 16:00:00 +0800

# 5. Test and commit
make clean-deb && make deb-setup
git add intel/patches/intel/0060-security-fix.patch intel/patches/series
git add debian/changelog
git commit -m "fix(intel): Backport security fix from upstream"
```

---

## Validation Checklist

Before committing changes:

- [ ] **Changelog updated** with new version and change description
- [ ] Changelog format is valid (`dpkg-parsechangelog` succeeds)
- [ ] Patches apply cleanly (`make deb-setup` succeeds)
- [ ] Config options are valid (no warnings during build)
- [ ] Build completes successfully (`make deb`)
- [ ] Package version matches changelog version
- [ ] Packages can be installed
- [ ] Feature works as expected (tested on target hardware if available)
- [ ] Git commit message follows convention
- [ ] Documentation updated if needed

---

## Troubleshooting

### Patch Fails to Apply

**Error:** `Patch does not apply`

**Solutions:**
1. Check patch context matches kernel version
2. Verify patch file format (use `dos2unix` if needed)
3. Check if patch conflicts with other patches (order matters)
4. Regenerate patch against current kernel source

```bash
# Check where patch fails
cd build/kernel
quilt push intel/0042-failing-patch.patch
# Shows which hunk fails

# Regenerate patch if needed
cd /path/to/kernel/source
git format-patch -1 <commit-hash> -o /tmp/
cp /tmp/0001-*.patch intel/patches/intel/0042-new-version.patch
```

### Config Option Not Applied

**Error:** Config option not appearing in final config

**Possible causes:**
1. Config option depends on another option that's disabled
2. Config option name typo
3. Config file not in `intel/config/intel/` directory

**Debug:**
```bash
cd build/kernel

# Check if config exists in kernel
grep -r "CONFIG_YOUR_OPTION" .config

# Check dependencies
scripts/config --state CONFIG_YOUR_OPTION
scripts/config --dep CONFIG_YOUR_OPTION
```

### Build Fails After Adding Patch

**Check:**
1. Patch syntax errors
2. Compilation errors in patched code
3. Missing dependencies

```bash
# See detailed build log
tail -100 build/logs/build-full-*.log

# Or build manually in container
./docker-build.sh shell
cd build/kernel
dpkg-buildpackage -B -uc -us -j$(nproc)
```

---

## Reference

### Patch Numbering Scheme

Suggested numbering ranges:

- **0001-0009**: Platform initialization and core patches
- **0010-0019**: Camera/IPU drivers
- **0020-0029**: Graphics (DRM, i915, Xe)
- **0030-0039**: Networking (Ethernet, WiFi)
- **0040-0049**: Audio (SOF)
- **0050-0059**: Security features (SGX, TDX)
- **0060-0069**: Platform devices (LPSS, Thunderbolt)
- **0070-0079**: Power management
- **0080-0089**: Performance optimizations
- **0090-0099**: Bug fixes and backports

This is a suggestion, not a strict requirement. Adjust as needed.

### Config File Naming

Suggested naming:

- `camera.cfg` - Camera/IPU configuration
- `drm.cfg` - Graphics configuration
- `ethernet.cfg` - Ethernet drivers
- `wifi.cfg` - WiFi drivers
- `audio.cfg` - Audio configuration
- `security.cfg` - Security features
- `platform.cfg` - Platform devices
- `power.cfg` - Power management
- `perf.cfg` - Performance features

### Useful Commands

```bash
# List all patches
cat intel/patches/series

# Count patches
wc -l intel/patches/series

# List all config files
ls -1 intel/config/intel/*.cfg

# Search for specific config
grep -r "CONFIG_OPTION" intel/config/intel/

# Show patch details
head -20 intel/patches/intel/0042-patch.patch

# Find which config file defines an option
grep -r "CONFIG_IPU6" intel/config/intel/
```

---

## Additional Resources

- **Main README**: [README.md](../README.md) - Project overview
- **Intel Overlay**: [intel/README.md](README.md) - Detailed overlay documentation
- **Debian Packaging**: [debian/README.md](../debian/README.md) - Debian build guide
- **RPM Packaging**: [rpm/README.md](../rpm/README.md) - RPM build guide
- **Linux Kernel Patch Format**: https://www.kernel.org/doc/html/latest/process/submitting-patches.html
