# Docker Build Environment

A Docker-based build environment for Intel kernel packages, supporting both Debian (`.deb`) and RPM (`.rpm`) formats.

## Files

- **[Dockerfile.ubuntu24.04](Dockerfile.ubuntu24.04)** - Ubuntu 24.04 image for Debian and RPM builds
- **[Dockerfile.ubuntu26.04](Dockerfile.ubuntu26.04)** - Ubuntu 26.04 image for Debian and RPM builds (default)
- **[.dockerignore](.dockerignore)** - Files to exclude from the Docker build context
- **[test-docker.sh](test-docker.sh)** - Script to test the Docker environment

## Quick Start

Build or remove the Docker image:

```bash
# Ubuntu 26.04 (default)
./docker-build.sh --build-image

# Or Ubuntu 24.04
./docker-build.sh --build-image --dockerfile Dockerfile.ubuntu24.04

# Remove existing Docker image(s)
./docker-build.sh --clean
```

## Docker Images

### Build Images

#### `intel-kernel-builder:ubuntu24.04`

- **Base**: Ubuntu 24.04 LTS (Noble Numbat)
- **Compiler**: GCC 14
- **Tools**: dpkg-buildpackage, debhelper, quilt
- **Size**: ~3-4 GB
- **Status**: ✅ Fully tested

#### `intel-kernel-builder:ubuntu26.04` (default)

- **Base**: Ubuntu 26.04 LTS
- **Compiler**: GCC 15
- **Tools**: dpkg-buildpackage, debhelper, quilt
- **Size**: ~3-4 GB
- **Status**: ✅ Fully tested

## Behind a Proxy

Set the proxy environment variables before building images:

```bash
# Configure the proxy
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port

# Build the image (proxy settings are applied automatically)
./docker-build.sh --build-image
```

The build script automatically forwards the proxy settings to the Docker build.

## Documentation

See the [top-level README](../README.md) for the complete build guide and troubleshooting.
