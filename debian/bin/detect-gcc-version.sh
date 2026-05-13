#!/bin/bash
# Detect GCC version based on Ubuntu version

set -e

# Detect Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION="${VERSION_ID}"
else
    # Default to 24.04 if cannot detect
    UBUNTU_VERSION="24.04"
fi

# Map Ubuntu version to GCC version
case "$UBUNTU_VERSION" in
    24.04|24.10)
        GCC_VERSION="14"
        ;;
    26.04)
        GCC_VERSION="15"
        ;;
    *)
        # Default to gcc-14
        GCC_VERSION="14"
        ;;
esac

echo "$GCC_VERSION"
