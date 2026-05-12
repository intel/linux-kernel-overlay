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

# Check if Dockerfile exists
if [ ! -f "./Dockerfile" ]; then
    echo "❌ Dockerfile not found"
    exit 1
fi
echo "✅ Dockerfile found"

echo ""
echo "=== All checks passed! ==="
echo ""
echo "Next steps:"
echo "  1. Build Docker image:  ./docker-build.sh --build-image"
echo "  2. Build Debian pkgs:   ./docker-build.sh deb"
echo "  3. Or open shell:       ./docker-build.sh shell"
echo ""
echo "For more information, see: DOCKER.md"
