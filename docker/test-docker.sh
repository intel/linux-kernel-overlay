#!/bin/bash
# Quick test script for Docker build environment

set -e

echo "=== Docker Build Environment Test ==="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    echo "   Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi
echo "✅ Docker is installed"

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running"
    echo "   Please start Docker first"
    exit 1
fi
echo "✅ Docker daemon is running"

# Check disk space
available=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$available" -lt 20 ]; then
    echo "⚠️  Low disk space: ${available}GB (recommended: 20GB+)"
else
    echo "✅ Sufficient disk space: ${available}GB"
fi

# Check if docker-build.sh exists
if [ ! -f "./docker-build.sh" ]; then
    echo "❌ docker-build.sh not found"
    exit 1
fi
echo "✅ docker-build.sh found"

# Check if Dockerfiles exist
if [ ! -f "./Dockerfile.ubuntu24.04" ]; then
    echo "❌ Dockerfile.ubuntu24.04 not found"
    exit 1
fi
echo "✅ Dockerfile.ubuntu24.04 found"

if [ -f "./Dockerfile.ubuntu26.04" ]; then
    echo "✅ Dockerfile.ubuntu26.04 found"
else
    echo "ℹ️  Dockerfile.ubuntu26.04 not found (optional)"
fi

echo ""
echo "=== All checks passed! ==="
echo ""
echo "Next steps:"
echo "  1. Build Docker image:  ./docker-build.sh --build-image"
echo "     (Ubuntu 24.04):      ./docker-build.sh --build-image"
echo "     (Ubuntu 26.04):      ./docker-build.sh --build-image --dockerfile Dockerfile.ubuntu26.04"
echo "  2. Build Debian pkgs:   ./docker-build.sh deb"
echo "  3. Or open shell:       ./docker-build.sh shell"
echo ""
echo "For more information, see: docker/README.md"
