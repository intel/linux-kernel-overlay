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
# Optional deb-config overrides (deb/deb-minimal only). Default to any env var
# of the same name, else empty. Empty => no deb-config step (original behavior).
SOURCENAME="${SOURCENAME:-}"
PKGVERSION="${PKGVERSION:-}"
KERNELRELEASE="${KERNELRELEASE:-}"
# Optional base kernel config selector (deb*/deb-source), passed to
# 'make deb-setup'. Empty => keep the tracked debian/config/config symlink
# (default base). Recognised values: noble | resolute.
BASE_CONFIG="${BASE_CONFIG:-}"
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
Intel Kernel Docker Build Script (Pure Docker - Zero Host Dependencies)

Usage: $0 [OPTIONS] [COMMAND]

OPTIONS:
    -b, --build-image     Build Docker image (Ubuntu with Deb + RPM support)
    -c, --clean           Remove Docker image
    --clean-logs          Remove all build logs
    -f, --force-setup     Force re-run setup (clean build directory and re-extract source)
    --dockerfile FILE     Specify Dockerfile to use (default: Dockerfile.ubuntu26.04)
    --mode MODE           Build mode: minimal or full (default: full)
    --base-config NAME    (deb*/deb-source/all) Base kernel config: noble or resolute
                          (default: whatever debian/config/config points to;
                           for 'all' it applies only when deb-setup actually runs)
    --source-name NAME    (deb*/deb-source) Override source package name; must start with 'linux'
    --pkg-version VER     (deb*/deb-source) Override .deb package version (<kernelver>-<revision>)
    --kernel-release SFX  (deb*/deb-source) Override uname -r suffix (localversion + abi_suffix)
    -h, --help            Show this help message

COMMANDS:
    shell                Open interactive shell in container
    deb                  Build Debian packages (setup + build, all flavours; also source + combined .changes)
    deb-minimal          Build Debian packages (minimal: kernel image only)
    deb-nonrt            Build only the non-RT flavour (full: kernel + tools; also source + combined .changes)
    deb-rt               Build only the RT flavour (minimal: kernel image, no tools)
    deb-source           Build source package (.dsc + tarball) for 'apt source'
    rpm                  Build RPM packages (prepare + build standard + RT)
    rpm-prepare          Prepare RPM source files only
    all                  Build both Debian and RPM packages

EXAMPLES:
    # Build Docker image (supports both Deb and RPM)
    $0 --build-image
    $0 --build-image --dockerfile Dockerfile.ubuntu24.04  # Use Ubuntu 24.04

    # Build packages (all phases run in container)
    $0 deb               # Build Debian packages (full: kernel + tools)
    $0 deb --mode minimal    # Build kernel image only (faster, no tools)
    $0 deb-minimal       # Same as above

    # Choose the base kernel config (default is the tracked symlink target)
    $0 deb --base-config noble       # Use config.noble-6.8.0-31-generic as base
    $0 deb --base-config resolute    # Use config.resolute-7.0.0-14-generic as base

    # Build with customized source name / version / kernel release (deb only)
    $0 deb --source-name linux-intel-6.18 \\
           --pkg-version 6.18.0-mainline+preprod+linux+260623t022223z \\
           --kernel-release -intel
    # (any subset works; omitted ones keep the values derived from debian/changelog)

    # Build non-RT and RT as separately-named source packages (deb only)
    $0 deb-nonrt --source-name linux-intel-6.18 \\
                 --pkg-version 6.18.0-mainline+preprod+linux+260623t022223z \\
                 --kernel-release -intel
    $0 deb-rt    --source-name linux-intel-6.18rt \\
                 --pkg-version 6.18.0-mainline+preprod+linux+260623t022223z \\
                 --kernel-release -intel

    # Build a source package consumable by 'apt source' (deb only)
    $0 deb-source --source-name linux-intel-6.18 \\
                  --pkg-version 6.18.0-mainline+preprod+linux+260623t022223z
    $0 rpm               # Build RPM packages (standard + RT)
    $0 all               # Build both

    # Force clean build
    $0 --force-setup deb # Clean build/kernel/ and rebuild

    # Open shell
    $0 shell             # Interactive shell in container

BUILD MODES (for Debian packages):
    full     - Build kernel image + tools + headers (default)
    minimal  - Build kernel image only (faster, no linux-kbuild/perf/cpupower)

CACHING:
    - Kernel source is cached in build/cache/ (downloaded once)
    - Build artifacts in build/ persist between runs for faster rebuilds
    - Use --force-setup to force clean extraction

LOGS:
    Build logs are saved to: build/logs/
    - build-full-YYYYMMDD-HHMMSS.log   (Debian full build)
    - build-minimal-YYYYMMDD-HHMMSS.log (Debian minimal build)
    - build-nonrt-YYYYMMDD-HHMMSS.log  (Debian non-RT flavour build)
    - build-rt-YYYYMMDD-HHMMSS.log     (Debian RT flavour build)
    - build-source-YYYYMMDD-HHMMSS.log (Debian source package build)
    - rpm-YYYYMMDD-HHMMSS.log          (RPM build)
    - all-YYYYMMDD-HHMMSS.log          (All packages build)

OUTPUT:
    Debian packages: build/packages/deb/
    RPM packages:    build/packages/rpm/

HOST REQUIREMENTS:
    - Docker only (no make, quilt, python3-tomli, or other build tools needed)

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

    # Detect if running in interactive terminal (TTY)
    # Use -it for interactive shells, -i only for CI/Jenkins
    local docker_flags="--rm"
    if [ -t 0 ] && [ -t 1 ]; then
        # Interactive terminal detected
        docker_flags="$docker_flags -it"
    else
        # Non-interactive (CI/Jenkins) - use -i only to keep stdin open
        docker_flags="$docker_flags -i"
    fi

    # The container runs as the host uid:gid, which has no /etc/passwd entry
    # in the image, so $HOME defaults to '/' (not writable). Bind-mount a
    # host directory as HOME so rpmbuild (~/rpmbuild) and other tools have
    # writable, disk-backed storage. tmpfs would OOM on kernel builds (~10GB).
    local rpmhome="${BUILD_DIR}/rpmhome"
    mkdir -p "${rpmhome}"

    docker run $docker_flags \
        --name "${CONTAINER_NAME}" \
        --user "$(id -u):$(id -g)" \
        -v "${SCRIPT_DIR}:/build/debian-kernel" \
        -v "${rpmhome}:/home/build-user" \
        -e HOME="/home/build-user" \
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
        --base-config)
            BASE_CONFIG="${ORIGINAL_ARGS[i+1]}"
            if ! ls "$SCRIPT_DIR"/intel/config/amd64/base/config."$BASE_CONFIG"-* >/dev/null 2>&1; then
                print_error "Invalid base config: $BASE_CONFIG (no intel/config/amd64/base/config.$BASE_CONFIG-* found)"
                print_info "Available: $(ls "$SCRIPT_DIR"/intel/config/amd64/base/ 2>/dev/null | sed 's/^config\.//; s/-.*//' | sort -u | tr '\n' ' ')"
                exit 1
            fi
            ;;
        --source-name)
            SOURCENAME="${ORIGINAL_ARGS[i+1]}"
            ;;
        --pkg-version)
            PKGVERSION="${ORIGINAL_ARGS[i+1]}"
            ;;
        --kernel-release)
            KERNELRELEASE="${ORIGINAL_ARGS[i+1]}"
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
        --source-name|--pkg-version|--kernel-release|--base-config)
            if [ -z "$2" ]; then
                print_error "Error: $1 requires a value"
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
        deb|deb-minimal|deb-nonrt|deb-rt|deb-source)
            check_image_exists
            START_TIME=$(date +%s)

            # Map command (and --mode for plain 'deb') to a Make target and a
            # BUILD_MODE label (used only for the log filename). deb-nonrt/deb-rt
            # select a single flavour in the Makefile; deb-rt is inherently
            # image-only, so --mode is ignored for it. deb-source builds only the
            # .dsc + source tarball (no compilation), for 'apt source'.
            case "$1" in
                deb-minimal)
                    BUILD_MODE="minimal"; MAKE_TARGET="deb-minimal"
                    print_info "Building Debian packages (minimal: kernel image only)..." ;;
                deb-nonrt)
                    BUILD_MODE="nonrt"; MAKE_TARGET="deb-nonrt"
                    print_info "Building Debian packages (non-RT flavour only, full: kernel + tools; also source + combined .changes)..." ;;
                deb-rt)
                    BUILD_MODE="rt"; MAKE_TARGET="deb-rt"
                    print_info "Building Debian packages (RT flavour only, minimal: kernel image, no tools)..." ;;
                deb-source)
                    BUILD_MODE="source"; MAKE_TARGET="deb-source"
                    print_info "Building Debian source package (.dsc + tarball for 'apt source')..." ;;
                *)  # plain 'deb': honour --mode (default full)
                    if [ "$BUILD_MODE" = "minimal" ]; then
                        MAKE_TARGET="deb-minimal"
                        print_info "Building Debian packages (minimal mode: kernel image only)..."
                    else
                        BUILD_MODE="full"; MAKE_TARGET="deb"
                        print_info "Building Debian packages (full mode: kernel + tools + headers; also source + combined .changes)..."
                    fi ;;
            esac

            # Create log directory
            mkdir -p "$LOG_DIR"
            BUILD_LOG="$LOG_DIR/build-${BUILD_MODE}-${TIMESTAMP}.log"

            print_info "Building packages in container (mode: $BUILD_MODE)..."
            print_info "Build log: $BUILD_LOG"

            if [ "$MAKE_TARGET" = "deb-minimal" ] || [ "$1" = "deb-rt" ]; then
                print_info "This build will skip: linux-kbuild, linux-perf, linux-cpupower, and other tools"
            fi

            # Assemble optional deb-config step. Each override is added only when
            # non-empty; if all three are empty, DEB_CONFIG_CMD stays empty and the
            # container command is identical to the original deb-setup + build.
            # Values are single-quoted so they survive the container's bash -c.
            CFG_ARGS=""
            [ -n "$SOURCENAME" ] && CFG_ARGS="$CFG_ARGS SOURCENAME='$SOURCENAME'"
            [ -n "$PKGVERSION" ] && CFG_ARGS="$CFG_ARGS PKGVERSION='$PKGVERSION'"
            [ -n "$KERNELRELEASE" ] && CFG_ARGS="$CFG_ARGS KERNELRELEASE='$KERNELRELEASE'"
            DEB_CONFIG_CMD=""
            if [ -n "$CFG_ARGS" ]; then
                DEB_CONFIG_CMD="make deb-config$CFG_ARGS && "
                print_info "Applying deb-config overrides:$CFG_ARGS"
            fi

            # Optional base-config selector passed to 'make deb-setup'. Empty =>
            # keep the tracked debian/config/config symlink (default base).
            SETUP_ARGS=""
            if [ -n "$BASE_CONFIG" ]; then
                SETUP_ARGS=" BASE_CONFIG='$BASE_CONFIG'"
                print_info "Using base kernel config: $BASE_CONFIG"
            fi

            # Build container command
            if [ "$FORCE_SETUP" = true ]; then
                print_info "Force setup enabled: will clean and re-extract source"
                CONTAINER_CMD="rm -rf /build/debian-kernel/build/kernel && make deb-setup$SETUP_ARGS && ${DEB_CONFIG_CMD}make $MAKE_TARGET"
            else
                CONTAINER_CMD="make deb-setup$SETUP_ARGS && ${DEB_CONFIG_CMD}make $MAKE_TARGET"
            fi

            run_container "cd /build/debian-kernel && $CONTAINER_CMD 2>&1" | tee "$BUILD_LOG"

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
            check_image_exists
            print_info "Preparing RPM source files in container..."

            mkdir -p "$LOG_DIR"
            SETUP_LOG="$LOG_DIR/rpm-prepare-${TIMESTAMP}.log"

            run_container "cd /build/debian-kernel && make rpm-prepare 2>&1" | tee "$SETUP_LOG"

            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                print_info "RPM source preparation completed!"
                print_info "You can now build RPM packages: $0 rpm"
            else
                print_error "RPM source preparation failed"
                exit 1
            fi
            exit 0
            ;;
        rpm)
            check_image_exists
            START_TIME=$(date +%s)
            print_info "Building RPM packages (standard + RT)..."

            mkdir -p "$LOG_DIR"
            RPM_LOG="$LOG_DIR/rpm-${TIMESTAMP}.log"

            print_info "Building RPM packages in container..."
            print_info "Build log: $RPM_LOG"

            # Build container command with automatic rpm-prepare if needed
            CONTAINER_CMD="make rpm-prepare && make rpm-all"

            run_container "cd /build/debian-kernel && $CONTAINER_CMD 2>&1" | tee "$RPM_LOG"

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
            ALL_LOG="$LOG_DIR/all-${TIMESTAMP}.log"

            print_info "Building all packages in container..."
            print_info "Build log: $ALL_LOG"

            # Optional base-config selector. Passed to 'make all' as a
            # command-line variable, which make forwards to the deb-setup it
            # runs. NOTE: 'all' only re-runs deb-setup when the build tree is
            # missing, so BASE_CONFIG takes effect on a fresh tree or with
            # --force-setup (which removes it); an existing tree is untouched.
            ALL_ARGS=""
            if [ -n "$BASE_CONFIG" ]; then
                ALL_ARGS=" BASE_CONFIG='$BASE_CONFIG'"
                print_info "Using base kernel config: $BASE_CONFIG"
            fi

            # Build container command
            if [ "$FORCE_SETUP" = true ]; then
                print_info "Force setup enabled: will clean and re-extract source"
                CONTAINER_CMD="rm -rf /build/debian-kernel/build/kernel && make all$ALL_ARGS"
            else
                CONTAINER_CMD="make all$ALL_ARGS"
            fi

            run_container "cd /build/debian-kernel && $CONTAINER_CMD 2>&1" | tee "$ALL_LOG"

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
