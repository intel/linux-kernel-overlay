# Overview
This is the Linux kernel overlay repository to support the Intel products.
And it is expected to help users generate the binary kernel image quickly.

# What is in the repository

## The kernel patch
In the `kernel-patches` directory, there are the Linux kernel patches which have
not been upstreamed to the Linux kernel community. We use the `quilt` tool to manage
them and they can be applied to the community kernel automatically.

## kernel configs
In the `kernel-config` directory, there are three-level kernel configurations:

- `base-os` (Ubuntu)
- `features` (the .cfg files in `kernel-config/features` directory)
- `rt/rt.cfg`

The `rt.cfg` overwrites the features configs (.cfg), and then they also
overwrite the `base-os` kernel config.

Configuration merging is handled by `kernel-config/merge.sh`, which reads
its settings from `kernel-config/conf.sh`:
- `BASE_PATH` in `conf.sh` specifies the base OS config file
- `KCONF_PATHS` in `conf.sh` specifies directories and files to merge
- For directory entries (type `dir`), merge.sh automatically includes **all** `.cfg`
  files in that directory (except `rt.cfg`)
- To change the feature set: add/remove `.cfg` files in `kernel-config/features/`,
  or modify `features_dir` in `conf.sh` to point to a different directory

## cmd-params
The `cmd-params` file has the kernel command line which is ONLY for the preempt-rt
kernel.

## shell scripts
`build.sh` is provided to compile the kernel image. Normally users only need to run
it in Ubuntu OS to get the .deb image. In `config.sh`, there is the kernel version
information for this release. The `kernel-config/conf.sh` contains the base
configuration paths and feature config selections, while `kernel-config/merge.sh`
handles the actual config merging.

# Prerequisites

## System Requirements
- Ubuntu OS (tested on Ubuntu Noble 24.04)
- Sufficient disk space (~20GB recommended for kernel source and build artifacts)
- Multi-core CPU recommended for parallel compilation

## Required Packages
Install the following packages before building:

```bash
sudo apt-get update
sudo apt-get install -y git build-essential bc bison flex libssl-dev \
    libelf-dev libncurses-dev dwarves debhelper quilt
```

Package descriptions:
- **git**: Required for cloning kernel source from upstream
- **build-essential**: GCC compiler and basic build tools
- **bc**: Calculator for kernel build scripts
- **bison, flex**: Parser generators for kernel configuration
- **libssl-dev**: SSL library for kernel crypto and module signing
- **libelf-dev**: ELF library for building kernel with BTF support
- **libncurses-dev**: For menuconfig (if needed)
- **dwarves**: Provides pahole for BTF generation
- **debhelper**: Required for Debian package creation (bindeb-pkg)
- **quilt**: Required for applying kernel patches

## Git Configuration

Before running the build script, configure your Git user identity. This is required
because the build process clones kernel source repositories and Git needs to know
your identity for any potential commits or operations.

Configure Git globally (applies to all repositories on your system):

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Or configure only for this repository (omit --global):

```bash
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

To verify your configuration:

```bash
git config user.name
git config user.email
```

Without this configuration, you may encounter errors like:

```
fatal: unable to auto-detect email address (got 'user@hostname.(none)')
```

# How it works
Run the `build.sh` script, and it will generate the Debian package.

Usage:

```bash
./build.sh -r {yes/no, yes if build realtime kernel. otherwise no.}
           -t { linux_kernel_tag }
           -b { build-id }
           -c { customized_kver_string }
```

Build non-RT kernel:

```bash
./build.sh -r no
```

Build RT kernel:

```bash
./build.sh -r yes
```

Note: the default value of `-r` is `no`. This means `./build.sh` (without `-r`) will
generate the non-RT binary kernel.

The `-c` parameter is used for internal tracking. If the value contains "cve", it will
append `+cve` to the kernel release string. For example:

```bash
./build.sh -c cve-2024-1234
# Results in KERNELRELEASE with +cve suffix
```

The `-t` and `-b` parameters can be used to add tag and build-id information into the name string
of the binary kernel image.

We normally use the following commands to build the non-RT and RT .deb images:

```bash
./build.sh -r no  -t 20250501 -b 1
./build.sh -r yes -t 20250501 -b 2
```

# Troubleshooting

## File Descriptor Limit
The build process applies a large number of kernel patches using quilt, which may
hit the default system file descriptor limit. The build script will automatically
attempt to raise the soft limit to 65536 (capped by the hard limit) on a
best-effort basis without failing the build.

If you encounter "Too many open files" errors, you can manually increase the limit:

```bash
# Check current limit
ulimit -n

# Temporarily increase for current shell session
ulimit -n 65536

# Permanently increase for current user (recommended - add to /etc/security/limits.conf)
echo "$(whoami) soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "$(whoami) hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# OR apply to all users (use with caution on multi-user systems)
# echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
# echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
```

After modifying limits.conf, log out and log back in for changes to take effect.

# Notes
This should only be used for platform feature evaluation and not for production
or deployment with commercial Linux distribution.

# Support
baoli.zhang@intel.com
