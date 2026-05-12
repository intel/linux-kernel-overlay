#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Generate kernel .config files for RPM build
# Uses debian/config/amd64/defines.toml to define merge order

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPM_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$RPM_DIR")"
DEBIAN_CONFIG="$PROJECT_ROOT/debian/config"
COMMON_CONFIG="$PROJECT_ROOT/common/config"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat <<EOF
Generate Kernel Config Files for RPM Build

Usage: $0 [OPTIONS]

OPTIONS:
    -o, --output-dir DIR    Output directory (default: $RPM_DIR)
    -a, --arch ARCH         Architecture (default: x86_64)
    -f, --flavour FLAVOUR   Flavour to generate (default: all)
                            Options: amd64, rt-amd64, test, all
    -h, --help              Show this help message

DESCRIPTION:
    Generates complete .config files by merging:
      1. Base config (rpm/kernel-x86_64-base.config)
      2. Config fragments from common/config/

    The merge order is defined in debian/config/amd64/defines.toml
    to ensure consistency between Debian and RPM builds.

OUTPUT FILES:
    rpm/kernel-x86_64.config        # amd64 flavour
    rpm/kernel-x86_64-rt.config     # rt-amd64 flavour
    rpm/kernel-x86_64-test.config   # test flavour

EXAMPLES:
    # Generate all configs
    $0

    # Generate only standard config
    $0 --flavour amd64

    # Generate for specific output directory
    $0 --output-dir /tmp/configs

REQUIREMENTS:
    - rpm/kernel-x86_64-base.config must exist
    - python3 (for TOML parsing)

EOF
}

# Default values
OUTPUT_DIR="$RPM_DIR"
ARCH="x86_64"
FLAVOUR="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -f|--flavour)
            FLAVOUR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "======================================================================"
echo "Generate Kernel Config Files"
echo "======================================================================"
echo "Architecture:     $ARCH"
echo "Flavour:          $FLAVOUR"
echo "Debian Config:    $DEBIAN_CONFIG"
echo "Common Config:    $COMMON_CONFIG"
echo "Output Directory: $OUTPUT_DIR"
echo "======================================================================"
echo ""

# Check dependencies
if ! command -v python3 &> /dev/null; then
    print_error "python3 is required for TOML parsing"
    exit 1
fi

# Check if defines.toml exists
DEFINES_TOML="$DEBIAN_CONFIG/amd64/defines.toml"
if [ ! -f "$DEFINES_TOML" ]; then
    print_error "defines.toml not found: $DEFINES_TOML"
    exit 1
fi

# Check if base config exists
BASE_CONFIG="$RPM_DIR/kernel-${ARCH}-base.config"
if [ ! -f "$BASE_CONFIG" ]; then
    print_error "Base config not found: $BASE_CONFIG"
    echo ""
    echo "Please create a base config first:"
    echo "  # Option 1: From Fedora"
    echo "  cp fedora-kernel/kernel-x86_64-fedora.config rpm/kernel-x86_64-base.config"
    echo ""
    echo "  # Option 2: From current kernel"
    echo "  cp /boot/config-\$(uname -r) rpm/kernel-x86_64-base.config"
    echo ""
    exit 1
fi

# Python script to parse TOML and extract config lists
read -r -d '' PYTHON_SCRIPT << 'PYTHON_EOF' || true
import sys
import re

def parse_toml_simple(file_path):
    """Simple TOML parser for our specific use case"""
    flavours = []
    current_flavour = None
    in_config = False

    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()

            # Start of new flavour
            if line == '[[flavour]]':
                if current_flavour and current_flavour['config']:
                    flavours.append(current_flavour)
                current_flavour = {'name': None, 'config': []}
                in_config = False
                continue

            # Flavour name
            if current_flavour and line.startswith('name = '):
                name = line.split('=', 1)[1].strip().strip("'\"")
                current_flavour['name'] = name
                continue

            # Start of config array
            if current_flavour and line == 'config = [':
                in_config = True
                continue

            # End of config array
            if in_config and line == ']':
                in_config = False
                continue

            # Config entry
            if in_config and line.startswith("'"):
                config = line.strip("',")
                current_flavour['config'].append(config)

    # Add last flavour
    if current_flavour and current_flavour['config']:
        flavours.append(current_flavour)

    return flavours

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)

    toml_file = sys.argv[1]
    flavours = parse_toml_simple(toml_file)

    for flavour in flavours:
        print(f"FLAVOUR:{flavour['name']}")
        for cfg in flavour['config']:
            print(f"CONFIG:{cfg}")
        print("END")
PYTHON_EOF

# Parse defines.toml
TOML_OUTPUT=$(python3 -c "$PYTHON_SCRIPT" "$DEFINES_TOML")

# Function to generate config for a flavour
generate_flavour_config() {
    local flavour_name=$1
    local output_suffix=$2

    print_info "Generating config for flavour: $flavour_name"

    # Extract config list for this flavour
    local config_list=()
    local in_flavour=false

    while IFS= read -r line; do
        if [[ "$line" == "FLAVOUR:$flavour_name" ]]; then
            in_flavour=true
        elif [[ "$line" == "END" ]]; then
            in_flavour=false
        elif [[ "$in_flavour" == true && "$line" == CONFIG:* ]]; then
            cfg="${line#CONFIG:}"
            config_list+=("$cfg")
        fi
    done <<< "$TOML_OUTPUT"

    if [ ${#config_list[@]} -eq 0 ]; then
        print_error "No config found for flavour: $flavour_name"
        return 1
    fi

    print_info "  Found ${#config_list[@]} config fragments"

    # Output file
    local output_file="$OUTPUT_DIR/kernel-${ARCH}${output_suffix}.config"
    local temp_file=$(mktemp)

    # Start with base config
    print_info "  Base: $(basename "$BASE_CONFIG") ($(wc -l < "$BASE_CONFIG") lines)"
    cp "$BASE_CONFIG" "$temp_file"

    # Append each config fragment in order
    for cfg in "${config_list[@]}"; do
        # Construct full path
        local cfg_path=""

        # Check in common/config first
        if [ -f "$COMMON_CONFIG/$cfg" ]; then
            cfg_path="$COMMON_CONFIG/$cfg"
        # Then check debian/config
        elif [ -f "$DEBIAN_CONFIG/$cfg" ]; then
            cfg_path="$DEBIAN_CONFIG/$cfg"
        else
            print_warn "    Config not found: $cfg"
            continue
        fi

        print_info "    + $(basename "$cfg")"

        # Append to temp file
        echo "" >> "$temp_file"
        echo "# ============================================================" >> "$temp_file"
        echo "# From: $cfg" >> "$temp_file"
        echo "# ============================================================" >> "$temp_file"
        cat "$cfg_path" >> "$temp_file"
    done

    # Move to final location
    mv "$temp_file" "$output_file"

    print_info "  Generated: $(basename "$output_file") ($(wc -l < "$output_file") lines)"

    return 0
}

# Generate configs based on flavour selection
if [ "$FLAVOUR" == "all" ]; then
    # Generate all flavours found in TOML
    FLAVOURS=$(echo "$TOML_OUTPUT" | grep "^FLAVOUR:" | cut -d: -f2)

    for f in $FLAVOURS; do
        case "$f" in
            amd64)
                generate_flavour_config "amd64" ""
                ;;
            rt-amd64)
                generate_flavour_config "rt-amd64" "-rt"
                ;;
            test)
                generate_flavour_config "test" "-test"
                ;;
            *)
                print_warn "Skipping unknown flavour: $f"
                ;;
        esac
        echo ""
    done
else
    # Generate specific flavour
    case "$FLAVOUR" in
        amd64)
            generate_flavour_config "amd64" ""
            ;;
        rt-amd64)
            generate_flavour_config "rt-amd64" "-rt"
            ;;
        test)
            generate_flavour_config "test" "-test"
            ;;
        *)
            print_error "Unknown flavour: $FLAVOUR"
            print_error "Valid options: amd64, rt-amd64, test, all"
            exit 1
            ;;
    esac
fi

echo ""
print_info "======================================================================"
print_info "Config generation completed!"
print_info "======================================================================"
print_info ""
print_info "Generated configs:"
ls -lh "$OUTPUT_DIR"/kernel-*.config | grep -v base | awk '{print "  " $9 " (" $5 ")"}'
print_info ""
print_info "Note: These configs will be processed by 'make olddefconfig' during build"
print_info "      to ensure all options are set consistently with the kernel version."
print_info ""
