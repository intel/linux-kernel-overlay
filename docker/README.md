# Docker Build Environment

Docker-based build environment for Intel kernel packages, supporting both Debian (.deb) and RPM (.rpm) formats.

## Files

- **[Dockerfile.ubuntu24.04](Dockerfile.ubuntu24.04)** - Ubuntu 24.04 image for Debian builds (default)
- **[Dockerfile.ubuntu26.04](Dockerfile.ubuntu26.04)** - Ubuntu 26.04 image for Debian builds
- **[Dockerfile.fedora](Dockerfile.fedora)** - Fedora Rawhide image for RPM builds
- **[.dockerignore](.dockerignore)** - Files to exclude from Docker build context
- **[test-docker.sh](test-docker.sh)** - Script to test Docker environment

## Quick Start

### Debian Packages

```bash
# 1. Build Docker image (first time only, Ubuntu 24.04 by default)
./docker-build.sh --build-image

# Or use Ubuntu 26.04
./docker-build.sh --build-image --dockerfile Dockerfile.ubuntu26.04

# 2. Build packages
./docker-build.sh deb
```

**Output**: `build/packages/deb/*.deb`

### RPM Packages

```bash
# 1. Build Docker image (first time only)
./docker-build.sh --build-image rpm

# 2. Setup Fedora sources (first time only)
./docker-build.sh rpm-setup

# 3. Build packages
./docker-build.sh rpm
```

**Output**: `~/rpmbuild/RPMS/` (inside container)

## Docker Images

### Debian Images

#### `intel-kernel-builder:ubuntu24.04` (default)

- **Base**: Ubuntu 24.04 LTS (Noble Numbat)
- **Compiler**: GCC 14
- **Tools**: dpkg-buildpackage, debhelper, quilt
- **Size**: ~3-4 GB
- **Status**: ✅ Fully tested

#### `intel-kernel-builder:ubuntu26.04`

- **Base**: Ubuntu 26.04 LTS
- **Compiler**: GCC 15
- **Tools**: dpkg-buildpackage, debhelper, quilt
- **Size**: ~3-4 GB
- **Status**: 🚧 Experimental (Ubuntu 26.04 not yet released)

### RPM Image: `intel-kernel-builder-rpm:fedora-rawhide`

- **Base**: Fedora Rawhide (latest development)
- **Compiler**: GCC (latest in Fedora)
- **Tools**: rpmbuild, rpmdevtools
- **Size**: ~2-3 GB
- **Status**: 🚧 In progress

## Behind a Proxy

Set proxy environment variables before building images:

```bash
# Set proxy
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port

# Build images (proxy settings auto-applied)
./docker-build.sh --build-image
```

The build script automatically passes proxy settings to Docker build.

## Documentation

See [README.md](../README.md) for complete build guide and troubleshooting.
