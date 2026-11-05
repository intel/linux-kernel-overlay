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

`docker-build.sh` uses the proxy from your host shell. Export it before running the script:

```bash
# Configure the proxy
export http_proxy=http://your-proxy:port
export https_proxy=http://your-proxy:port
export no_proxy=localhost,127.0.0.1     # Optional

# Build the image, then build packages (proxy settings are applied automatically)
./docker-build.sh --build-image
./docker-build.sh deb
```

The proxy is applied at two stages:

- **Image build** (`--build-image`): `http_proxy` and `https_proxy` are passed to `docker build`, so `apt-get` can install the build tools.
- **Package build** (`deb`, `rpm`, ...): each of `http_proxy`, `https_proxy`, `no_proxy`, `all_proxy` (and their uppercase forms) that is set on the host is passed into the container, overriding the value stored in the image. If the host sets only one case of a name (e.g. `HTTP_PROXY`), it is used for both cases. Variables not set on the host in either case are left alone, so the container keeps the image's value for them.

Changing the proxy on the host doesn't require rebuilding the image. At startup the script prints each proxy the container will use and where it comes from, for example:

```
[INFO] Container proxy: http_proxy=http://proxy.example.com:911 (from image)
[INFO] Container proxy: NO_PROXY=intel.com,10.0.0.0/8 (from host)
```

Credentials in the URL are masked. If downloads fail with network errors, check this output; a proxy shown as `(from image)` means the shell that runs `docker-build.sh` doesn't export it. This is common for CI jobs, whose environment often isn't loaded from the login profile, and under `sudo`, which drops it by default.

## Documentation

See the [top-level README](../README.md) for the complete build guide and troubleshooting.
