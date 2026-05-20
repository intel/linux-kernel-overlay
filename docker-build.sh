#!/bin/bash
# Docker-based kernel build script for Intel kernel packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="intel-kernel-builder"
CONTAINER_NAME="kernel-build-$$"
FORCE_SETUP=false
DOCKERFILE="Dockerfile.ubuntu26.04"
IMAGE_TAG="ubuntu26.04"  # Will be auto-detected from DOCKERFILE
BUILD_MODE="full"  # full or minimal
BUILD_DIR="${SCRIPT_DIR}/build"
PACKAGES_DIR="${BUILD_DIR}/packages"
PACKAGES_DEB_DIR="${PACKAGES_DIR}/deb"
PACKAGES_RPM_DIR="${PACKAGES_DIR}/rpm"
LOG_DIR="${BUILD_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

show_usage() {
    cat <<EOF
Intel Kernel Docker Build Script

Usage: $0 [OPTIONS] [COMMAND]

OPTIONS:
    -b, --build-image     Build Docker image (Ubuntu with Deb + RPM support)
    -c, --clean           Remove Docker image
    --clean-logs          Remove all build logs
    -f, --force-setup     Force re-run setup (re-download source)
    --dockerfile FILE     Specify Dockerfile to use (default: Dockerfile.ubuntu24.04)
    --mode MODE           Build mode: minimal or full (default: full)
    -h, --help            Show this help message

COMMANDS:
    shell                Open interactive shell in container
    deb                  Build Debian packages
    deb-minimal          Build Debian packages (minimal: kernel image only)
    rpm                  Build RPM packages (both standard and RT)
    rpm-prepare          Prepare RPM source files
    all                  Build both Debian and RPM packages

EXAMPLES:
    # Build Docker image (supports both Deb and RPM)
    $0 --build-image
    $0 --build-image --dockerfile Dockerfile.ubuntu26.04  # Use Ubuntu 26.04

    # Build packages
    $0 deb               # Build Debian packages (full: kernel + tools)
    $0 deb --mode minimal    # Build kernel image only (faster, no tools)
    $0 deb-minimal       # Same as above
    $0 rpm-prepare       # Prepare RPM sources
    $0 rpm               # Build RPM packages (standard + RT)
    $0 all               # Build both

    # Open shell
    $0 shell             # Interactive shell in container

BUILD MODES (for Debian packages):
    full     - Build kernel image + tools + headers (default)
    minimal  - Build kernel image only (faster, no linux-kbuild/perf/cpupower)

LOGS:
    Build logs are saved to: build/logs/
    - setup-YYYYMMDD-HHMMSS.log   (setup phase)
    - build-YYYYMMDD-HHMMSS.log   (Debian build)
    - rpm-YYYYMMDD-HHMMSS.log     (RPM build)

OUTPUT:
    Debian packages: packages/deb/
    RPM packages:    packages/rpm/

EOF
}

build_image() {
    cd "$SCRIPT_DIR/docker"

    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE" ]; then
        print_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi

    # Auto-detect IMAGE_TAG from Dockerfile name
    # Dockerfile.ubuntu24.04 -> ubuntu24.04
    # Dockerfile.ubuntu26.04 -> ubuntu26.04
    if [[ "$DOCKERFILE" =~ Dockerfile\.(.+)$ ]]; then
        IMAGE_TAG="${BASH_REMATCH[1]}"
        print_info "Auto-detected image tag from Dockerfile: $IMAGE_TAG"
    fi

    # Build with proxy settings from environment if available
    BUILD_ARGS=""
    if [ -n "$http_proxy" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg http_proxy=$http_proxy"
        print_info "Using http_proxy: $http_proxy"
    fi
    if [ -n "$https_proxy" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg https_proxy=$https_proxy"
        print_info "Using https_proxy: $https_proxy"
    fi

    print_info "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
    print_info "  Dockerfile: $DOCKERFILE"
    print_info "  Support: Debian (.deb) + RPM (.rpm) packages"
    docker build $BUILD_ARGS -f "$DOCKERFILE" -t "${IMAGE_NAME}:${IMAGE_TAG}" .
    print_info "Docker image built successfully!"
}

clean_image() {
    print_info "Removing all Docker images for project: ${IMAGE_NAME}"

    # Get all tags for this image
    local images=$(docker images "${IMAGE_NAME}" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)

    if [ -z "$images" ]; then
        print_warn "No images found for ${IMAGE_NAME}"
        return 0
    fi

    # Remove each image
    local removed=0
    local failed=0
    while IFS= read -r image; do
        if [ -n "$image" ]; then
            print_info "  Removing: $image"
            if docker rmi "$image" 2>/dev/null; then
                removed=$((removed + 1))
            else
                print_warn "  Failed to remove: $image"
                failed=$((failed + 1))
            fi
        fi
    done <<< "$images"

    print_info "Summary: $removed image(s) removed, $failed failed"
}

clean_logs() {
    if [ -d "$LOG_DIR" ]; then
        print_info "Cleaning build logs from: $LOG_DIR"
        rm -rf "$LOG_DIR"
        print_info "Logs cleaned."
    else
        print_warn "No log directory found"
    fi
}

run_container() {
    local cmd="$1"

    print_info "Starting container: ${CONTAINER_NAME}"

    docker run --rm -it \
        --name "${CONTAINER_NAME}" \
        --user "$(id -u):$(id -g)" \
        -v "${SCRIPT_DIR}:/build/debian-kernel" \
        -w /build/debian-kernel \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        bash -c "${cmd}"
}

check_image_exists() {
    if ! docker images "${IMAGE_NAME}:${IMAGE_TAG}" | grep -q "${IMAGE_TAG}"; then
        print_error "Docker image not found: ${IMAGE_NAME}:${IMAGE_TAG}"
        print_info "Please build the image first: $0 --build-image"
        exit 1
    fi
}

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# First pass: parse option-setting arguments (--dockerfile, -f, --mode)
ORIGINAL_ARGS=("$@")
for ((i=0; i<${#ORIGINAL_ARGS[@]}; i++)); do
    case "${ORIGINAL_ARGS[i]}" in
        --dockerfile)
            DOCKERFILE="${ORIGINAL_ARGS[i+1]}"
            # Auto-detect IMAGE_TAG from Dockerfile name
            # Dockerfile.ubuntu24.04 -> ubuntu24.04
            # Dockerfile.ubuntu26.04 -> ubuntu26.04
            if [[ "$DOCKERFILE" =~ Dockerfile\.(.+)$ ]]; then
                IMAGE_TAG="${BASH_REMATCH[1]}"
                print_info "Using Dockerfile: $DOCKERFILE (image tag: $IMAGE_TAG)"
            fi
            ;;
        -f|--force-setup)
            FORCE_SETUP=true
            ;;
        --mode)
            BUILD_MODE="${ORIGINAL_ARGS[i+1]}"
            if [[ "$BUILD_MODE" != "minimal" && "$BUILD_MODE" != "full" ]]; then
                print_error "Invalid build mode: $BUILD_MODE (must be 'minimal' or 'full')"
                exit 1
            fi
            ;;
    esac
done

# Second pass: execute commands
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build-image)
            build_image
            exit 0
            ;;
        -c|--clean)
            clean_image
            exit 0
            ;;
        --clean-logs)
            clean_logs
            exit 0
            ;;
        -f|--force-setup)
            shift
            continue
            ;;
        --dockerfile)
            if [ -z "$2" ]; then
                print_error "Error: --dockerfile requires a filename argument"
                exit 1
            fi
            shift 2
            continue
            ;;
        --mode)
            if [ -z "$2" ]; then
                print_error "Error: --mode requires an argument (minimal or full)"
                exit 1
            fi
            shift 2
            continue
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        shell)
            check_image_exists
            print_info "Opening interactive shell..."
            print_info "Tip: Use 'make help' to see available build targets"
            run_container "/bin/bash"
            exit 0
            ;;
        deb|deb-minimal)
            check_image_exists
            START_TIME=$(date +%s)

            # Determine build mode
            if [ "$1" = "deb-minimal" ]; then
                BUILD_MODE="minimal"
            fi

            if [ "$BUILD_MODE" = "minimal" ]; then
                print_info "Building Debian packages (minimal mode: kernel image only)..."
                MAKE_TARGET="deb-minimal"
            else
                print_info "Building Debian packages (full mode: kernel + tools + headers)..."
                MAKE_TARGET="deb"
            fi

            # Create log directory
            mkdir -p "$LOG_DIR"
            SETUP_LOG="$LOG_DIR/setup-${TIMESTAMP}.log"
            BUILD_LOG="$LOG_DIR/build-${BUILD_MODE}-${TIMESTAMP}.log"

            # Check if source needs to be prepared (run on host, not in container)
            if [ "$FORCE_SETUP" = true ]; then
                print_info "Step 1/2: Force setup (--force-setup) - running on host..."
                print_info "Setup log: $SETUP_LOG"
                cd "$SCRIPT_DIR"
                make deb-setup 2>&1 | tee "$SETUP_LOG" || exit 1
            elif [ ! -d "$BUILD_DIR/kernel" ] || [ ! -f "$BUILD_DIR/kernel/Makefile" ]; then
                print_info "Step 1/2: First-time setup (download source, apply patches) - running on host..."
                print_info "Setup log: $SETUP_LOG"
                cd "$SCRIPT_DIR"
                make deb-setup 2>&1 | tee "$SETUP_LOG" || exit 1
            else
                print_info "Step 1/2: Build directory exists, skipping setup..."
            fi

            print_info "Step 2/2: Building packages in container (mode: $BUILD_MODE)..."
            print_info "Build log: $BUILD_LOG"

            if [ "$BUILD_MODE" = "minimal" ]; then
                print_info "Minimal build will skip: linux-kbuild, linux-perf, linux-cpupower, and other tools"
            fi

            run_container "cd /build/debian-kernel && make $MAKE_TARGET 2>&1" | tee "$BUILD_LOG"

            BUILD_STATUS=${PIPESTATUS[0]}
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))

            if [ $BUILD_STATUS -eq 0 ]; then
                # Move packages to packages/deb/
                mkdir -p "$PACKAGES_DEB_DIR"
                print_info "Moving packages to $PACKAGES_DEB_DIR..."
                mv -f "$BUILD_DIR"/*.deb "$BUILD_DIR"/*.ddeb "$BUILD_DIR"/*.dsc "$BUILD_DIR"/*.tar.* "$BUILD_DIR"/*.changes "$BUILD_DIR"/*.buildinfo "$PACKAGES_DEB_DIR"/ 2>/dev/null || true

                print_info "Build completed successfully!"
                print_info "Build mode: $BUILD_MODE"
                print_info "Packages: $PACKAGES_DEB_DIR/"
                print_info "Logs: $LOG_DIR/"
                print_info "Build time: $(format_duration $DURATION)"
            else
                print_error "Build failed with exit code: $BUILD_STATUS"
                print_error "Check log file: $BUILD_LOG"
                print_error "Build time: $(format_duration $DURATION)"
                exit $BUILD_STATUS
            fi
            exit 0
            ;;
        rpm-prepare)
            print_info "Preparing RPM source files..."
            cd "$SCRIPT_DIR"
            make rpm-prepare
            print_info "Setup completed!"
            print_info "You can now build RPM packages: $0 rpm"
            exit 0
            ;;
        rpm)
            check_image_exists
            START_TIME=$(date +%s)
            print_info "Building RPM packages (standard + RT)..."

            mkdir -p "$LOG_DIR"
            SETUP_LOG="$LOG_DIR/setup-${TIMESTAMP}.log"
            RPM_LOG="$LOG_DIR/rpm-${TIMESTAMP}.log"

            # Check if source files exist, run rpm-prepare if needed
            if [ ! -f "$SCRIPT_DIR/rpm/linux-"*.tar.xz ]; then
                print_info "Step 1/2: RPM source files not found. Running rpm-prepare..."
                print_info "Setup log: $SETUP_LOG"
                cd "$SCRIPT_DIR"
                make rpm-prepare 2>&1 | tee "$SETUP_LOG" || exit 1
            else
                print_info "Step 1/2: RPM source files exist, skipping setup..."
            fi

            print_info "Step 2/2: Building RPM packages (standard + RT)..."
            print_info "Build log: $RPM_LOG"

            run_container "cd /build/debian-kernel && make rpm-all 2>&1" | tee "$RPM_LOG"

            BUILD_STATUS=${PIPESTATUS[0]}
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))

            if [ $BUILD_STATUS -eq 0 ]; then
                print_info "All RPM packages built successfully!"
                print_info "  Standard kernel: kernel-*"
                print_info "  RT kernel:       kernel-rt-*"
                print_info "Packages: $PACKAGES_RPM_DIR/"
                print_info "Logs: $LOG_DIR/"
                print_info "Total build time: $(format_duration $DURATION)"
            else
                print_error "RPM build failed with exit code: $BUILD_STATUS"
                print_error "Check log file: $RPM_LOG"
                print_error "Total build time: $(format_duration $DURATION)"
                exit $BUILD_STATUS
            fi
            exit 0
            ;;
        all)
            check_image_exists
            START_TIME=$(date +%s)
            print_info "Building all packages (Debian + RPM)..."

            mkdir -p "$LOG_DIR"
            SETUP_LOG="$LOG_DIR/setup-${TIMESTAMP}.log"
            ALL_LOG="$LOG_DIR/all-${TIMESTAMP}.log"

            # Check if Debian source needs to be prepared (run on host, not in container)
            if [ "$FORCE_SETUP" = true ]; then
                print_info "Step 1/3: Force setup (--force-setup) - Debian setup on host..."
                print_info "Setup log: $SETUP_LOG"
                cd "$SCRIPT_DIR"
                make deb-setup 2>&1 | tee "$SETUP_LOG" || exit 1
            elif [ ! -d "$BUILD_DIR/kernel" ]; then
                print_info "Step 1/3: Debian setup (download source, apply patches) - running on host..."
                print_info "Setup log: $SETUP_LOG"
                cd "$SCRIPT_DIR"
                make deb-setup 2>&1 | tee "$SETUP_LOG" || exit 1
            else
                print_info "Step 1/3: Debian build directory exists, skipping setup..."
            fi

            # Check if RPM source files exist (run on host, not in container)
            if [ ! -f "$SCRIPT_DIR/rpm/linux-"*.tar.xz ]; then
                print_info "Step 2/3: RPM setup (prepare source files) - running on host..."
                cd "$SCRIPT_DIR"
                make rpm-prepare 2>&1 | tee -a "$SETUP_LOG" || exit 1
            else
                print_info "Step 2/3: RPM source files exist, skipping setup..."
            fi

            print_info "Step 3/3: Building all packages in container..."
            print_info "Build log: $ALL_LOG"

            run_container "make all 2>&1" | tee "$ALL_LOG"

            BUILD_STATUS=${PIPESTATUS[0]}
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))

            if [ $BUILD_STATUS -eq 0 ]; then
                print_info "All packages built successfully!"
                print_info "Debian packages: $PACKAGES_DEB_DIR/"
                print_info "RPM packages: $PACKAGES_RPM_DIR/"
                print_info "Logs: $LOG_DIR/"
                print_info "Total build time: $(format_duration $DURATION)"
            else
                print_error "Build failed with exit code: $BUILD_STATUS"
                print_error "Check log file: $ALL_LOG"
                print_error "Total build time: $(format_duration $DURATION)"
                exit $BUILD_STATUS
            fi
            exit 0
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
done
