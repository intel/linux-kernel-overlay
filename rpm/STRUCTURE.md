# RPM Directory Structure

This document explains the Fedora-style flat directory structure used for kernel RPM packaging.

## Current Structure

```
rpm/
├── kernel.spec                          # Main RPM spec file (9.7K)
├── kernel-local                         # User customization file (empty by default)
│
├── patches -> ../common/patches         # Symlink for reference
├── patches.tar.gz                       # Patches archive (335 files, 799K)
├── kernel-x86_64.config                # Standard kernel config (24K)
├── kernel-x86_64-rt.config             # Real-time kernel config (25K)
│
├── scripts/                             # Build automation scripts
│   ├── prepare-sources.sh               # Main orchestration script
│   ├── generate-configs.sh              # Generate configs from common/config/*
│   ├── build.sh                         # Build RPM packages
│   ├── setup-fedora-sources.sh          # Download Fedora build scripts
│   └── update-version.sh                # Version management
│
├── README.md                            # Complete documentation (9.3K)
├── STRUCTURE.md                         # This file
└── .gitignore                           # Git ignore patterns

Generated files (not in git, created by prepare-sources.sh):
├── linux-6.18.20.tar.xz                # Kernel source tarball (will be downloaded)
├── mod-sign.sh                          # Fedora build scripts (will be downloaded)
├── mod-denylist.sh
└── filtermods.py
```

## Why Individual Patch Application?

**Previous approach**: Merge 332 patches into one 3.4M file
- ❌ Huge file, hard to review
- ❌ When patch fails, no indication which original patch caused it
- ❌ Difficult to debug and fix

**Current approach**: Apply patches individually from series file
- ✅ Patches applied one-by-one during build
- ✅ **Clear error messages**: "Failed to apply patch: intel/0123-feature.patch"
- ✅ Easy to identify and fix problematic patches
- ✅ Similar to Debian quilt approach
- ✅ 799KB tarball vs 3.4MB merged patch

### How Patches Are Applied

During `rpmbuild`, the spec file:
1. Extracts `linux-6.18.20.tar.xz`
2. Extracts `patches.tar.gz` → creates `patches/` directory
3. Reads `patches/series` line-by-line
4. Applies each patch with `patch -p1 -i patches/intel/NNNN-xxx.patch`
5. **If any patch fails**: Shows exact filename and stops

Example error output:
```
Applying: intel/0123-my-feature.patch
ERROR: Failed to apply patch: intel/0123-my-feature.patch
```

You immediately know which patch to fix!

## Debugging Patch Failures

When a patch fails:
```bash
# 1. Build shows exact patch that failed
./scripts/build.sh
# Output: ERROR: Failed to apply patch: intel/0123-my-feature.patch

# 2. Check the failing patch
cat common/patches/intel/0123-my-feature.patch

# 3. Test it manually
cd ~/rpmbuild/BUILD/linux-6.18.20
patch -p1 --dry-run < patches/intel/0123-my-feature.patch

# 4. Fix the patch in common/patches
vi common/patches/intel/0123-my-feature.patch

# 5. Regenerate patches tarball only
./scripts/prepare-sources.sh --skip-kernel --skip-configs --skip-scripts --force

# 6. Rebuild
./scripts/build.sh
```

## Advantages Over Merged Patch

| Aspect | Merged Patch | Individual Patches (Current) |
|--------|--------------|------------------------------|
| File size | 3.4M | 799KB |
| Error message | "patch failed at line 45623" | "Failed: intel/0123-feature.patch" |
| Debugging | Search huge file for context | Open specific patch file |
| Fix time | 10+ minutes | < 1 minute |
| Reusability | No | Yes (same patches for Debian) |

## References

- [Fedora Kernel Repo](https://src.fedoraproject.org/rpms/kernel)
- [Quilt Patch Management](https://www.linux-magazine.com/Issues/2019/227/Quilt)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
