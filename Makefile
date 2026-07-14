# Makefile for Kernel Packaging System
# Supports both Debian (.deb) and RPM (.rpm) package builds

.PHONY: help deb deb-config deb-nonrt deb-rt rpm rpm-rt rpm-all all clean clean-deb clean-rpm status

# Default target
help:
	@echo "============================================================"
	@echo "Kernel Packaging System - Unified Build Interface"
	@echo "============================================================"
	@echo ""
	@echo "Targets:"
	@echo "  deb              Build Debian packages (full: kernel + tools, all flavours)"
	@echo "  deb-minimal      Build Debian packages (minimal: kernel image only)"
	@echo "  deb-nonrt        Build non-RT flavour only (full: kernel + tools)"
	@echo "  deb-rt           Build RT flavour only (minimal: kernel image, no tools)"
	@echo "  rpm              Build RPM packages (standard kernel)"
	@echo "  rpm-rt           Build RPM packages (RT kernel)"
	@echo "  rpm-all          Build RPM packages (standard + RT)"
	@echo "  all              Build both Debian and RPM packages"
	@echo "  clean            Clean all build artifacts"
	@echo "  clean-deb        Clean Debian build artifacts only"
	@echo "  clean-rpm        Clean RPM build artifacts only"
	@echo "  status           Show current build status"
	@echo "  verify-deb-packages  Verify Debian kernel package consistency"
	@echo "  verify-rpm-packages  Verify RPM kernel package consistency"
	@echo "  verify-packages      Verify all packages (DEB + RPM)"
	@echo ""
	@echo "Debian Targets:"
	@echo "  deb-setup        Setup Debian build (first-time only)"
	@echo "  deb-config       Override source name / version / kernel release (after deb-setup)"
	@echo "  deb-modules      Build Debian kernel module packages"
	@echo "  deb-minimal      Build kernel image only (fast, no tools)"
	@echo "  deb-nonrt        Build only the non-RT (amd64) flavour, full tools"
	@echo "  deb-rt           Build only the RT (rt-amd64) flavour, image only"
	@echo ""
	@echo "RPM Targets:"
	@echo "  rpm-prepare      Prepare RPM source files (first-time only)"
	@echo "  rpm-quick        Quick RPM build (binary only)"
	@echo "  rpm-update       Update RPM version info"
	@echo ""
	@echo "Examples:"
	@echo "  make deb                    # Build all Debian packages (kernel + tools)"
	@echo "  make deb-minimal            # Build kernel image only (faster)"
	@echo "  make deb-config SOURCENAME=linux-intel-6.18 PKGVERSION=6.18.0-mainline+linux+260623t022223z KERNELRELEASE=-intel"
	@echo "  make deb-nonrt              # Build only the non-RT flavour (after deb-config)"
	@echo "  make deb-rt                 # Build only the RT flavour (after deb-config)"
	@echo "  make rpm                    # Build RPM packages (standard only)"
	@echo "  make rpm-rt                 # Build RPM packages (RT only)"
	@echo "  make rpm-all                # Build RPM packages (standard + RT)"
	@echo "  make all                    # Build both"
	@echo "  make JOBS=8 deb             # Build with 8 parallel jobs"
	@echo ""
	@echo "For more details:"
	@echo "  - Debian: see debian/README.md or README.md"
	@echo "  - RPM:    see rpm/README.md"
	@echo "============================================================"

# Configuration
JOBS ?= $(shell nproc)
# -d skips dpkg-buildpackage's build-dependency check. The generated
# debian/control Build-Depends on synthetic packages (gcc-N-for-host,
# libwrap0-dev) that don't exist in the Ubuntu archive and are only
# provided as contentless equivs stubs in the Docker image. Those stubs
# have no effect on the actual compile (the real compiler is gcc-N via
# c_compiler/CC), so we skip the check instead of requiring the stubs.
DEB_BUILD_FLAGS ?= -b -uc -us -d -j$(JOBS)
DEB_BUILD_FLAGS_MINIMAL ?= -B -uc -us -d -j$(JOBS)
DEB_BUILD_PROFILES ?=
RPM_BUILD_FLAGS ?=
BUILD_DIR ?= $(CURDIR)/build/kernel
BUILD_PACKAGES_DIR ?= $(CURDIR)/build/packages
BUILD_PACKAGES_DEB_DIR ?= $(CURDIR)/build/packages/deb
BUILD_PACKAGES_RPM_DIR ?= $(CURDIR)/build/packages/rpm
BUILD_LOGS_DIR ?= $(CURDIR)/build/logs
BUILD_CACHE_DIR ?= $(CURDIR)/build/cache

# ============================================================
# Debian Package Targets
# ============================================================

deb:
	@if [ ! -d "$(BUILD_DIR)" ]; then \
		echo "Error: Build directory not found. Run 'make deb-setup' first."; \
		exit 1; \
	fi
	@echo "======================================================================"
	@echo "Building Debian packages (full: kernel image + tools + headers)..."
	@echo "======================================================================"
	cd $(BUILD_DIR) && DEB_BUILD_PROFILES="$(DEB_BUILD_PROFILES)" dpkg-buildpackage $(DEB_BUILD_FLAGS)
	@# Move all packages and source files to packages/deb/ directory (excluding .ddeb debug packages)
	@mkdir -p $(BUILD_PACKAGES_DEB_DIR)
	@echo "Moving packages to $(BUILD_PACKAGES_DEB_DIR)..."
	@find $(CURDIR)/build -maxdepth 1 -name "*.deb" ! -name "*.ddeb" -exec mv -f {} $(BUILD_PACKAGES_DEB_DIR)/ \; 2>/dev/null || true
	@mv -f $(CURDIR)/build/*.dsc $(CURDIR)/build/*.tar.* $(CURDIR)/build/*.changes $(CURDIR)/build/*.buildinfo $(BUILD_PACKAGES_DEB_DIR)/ 2>/dev/null || true
	@echo "Debug symbol packages (.ddeb) excluded"
	@echo ""
	@echo "Debian packages built successfully!"
	@echo "Packages are in: $(BUILD_PACKAGES_DEB_DIR)"
	@$(MAKE) verify-deb-packages

deb-minimal:
	@if [ ! -d "$(BUILD_DIR)" ]; then \
		echo "Error: Build directory not found. Run 'make deb-setup' first."; \
		exit 1; \
	fi
	@echo "======================================================================"
	@echo "Building Debian packages (minimal: kernel image only, no tools)..."
	@echo "======================================================================"
	@echo "This build will skip:"
	@echo "  - linux-kbuild packages (kernel build tools)"
	@echo "  - linux-perf packages (perf profiling tools)"
	@echo "  - linux-cpupower packages (CPU frequency tools)"
	@echo "  - other kernel tools"
	@echo "  - source packages (.dsc, .tar.xz)"
	@echo "  - arch:all packages (linux-doc, linux-source)"
	@echo ""
	cd $(BUILD_DIR) && DEB_BUILD_PROFILES="$(DEB_BUILD_PROFILES) pkg.linux.notools" dpkg-buildpackage $(DEB_BUILD_FLAGS_MINIMAL)
	@# Move all packages and source files to packages/deb/ directory (excluding .ddeb debug packages)
	@mkdir -p $(BUILD_PACKAGES_DEB_DIR)
	@echo "Moving packages to $(BUILD_PACKAGES_DEB_DIR)..."
	@find $(CURDIR)/build -maxdepth 1 -name "*.deb" ! -name "*.ddeb" -exec mv -f {} $(BUILD_PACKAGES_DEB_DIR)/ \; 2>/dev/null || true
	@mv -f $(CURDIR)/build/*.dsc $(CURDIR)/build/*.tar.* $(CURDIR)/build/*.changes $(CURDIR)/build/*.buildinfo $(BUILD_PACKAGES_DEB_DIR)/ 2>/dev/null || true
	@echo "Debug symbol packages (.ddeb) excluded"
	@echo ""
	@echo "Debian packages (minimal) built successfully!"
	@echo "Packages are in: $(BUILD_PACKAGES_DEB_DIR)"
	@$(MAKE) verify-deb-packages

deb-setup:
	@echo "======================================================================"
	@echo "Setting up Debian build environment..."
	@echo "======================================================================"
	@# Create build directories
	@mkdir -p $(BUILD_DIR) $(BUILD_PACKAGES_DEB_DIR) $(BUILD_LOGS_DIR) $(BUILD_CACHE_DIR)
	@# Extract source package name and version from changelog
	@SOURCE_PKG=$$(dpkg-parsechangelog -l debian/changelog --show-field Source 2>/dev/null || echo "linux"); \
	if ! echo "$$SOURCE_PKG" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9.+_-]*$$'; then \
		echo "Error: Invalid source package name: $$SOURCE_PKG"; \
		echo "  Source package names must start with alphanumeric and contain only: a-z A-Z 0-9 . + _ -"; \
		exit 1; \
	fi; \
	FULL_VERSION=$$(dpkg-parsechangelog -l debian/changelog --show-field Version 2>/dev/null); \
	BASE_VERSION=$$(echo "$$FULL_VERSION" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?)-.*$$/\1/'); \
	EXPECTED_TARBALL="$${SOURCE_PKG}_$${FULL_VERSION}.orig.tar.xz"; \
	if echo "$$EXPECTED_TARBALL" | grep -qE '\.\./|^/'; then \
		echo "Error: Invalid tarball name contains path traversal: $$EXPECTED_TARBALL"; \
		exit 1; \
	fi; \
	echo "Expected source tarball: $$EXPECTED_TARBALL"
	@# Download or copy upstream source if not exists
	@SOURCE_PKG=$$(dpkg-parsechangelog -l debian/changelog --show-field Source 2>/dev/null || echo "linux"); \
	if ! echo "$$SOURCE_PKG" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9.+_-]*$$'; then \
		echo "Error: Invalid source package name: $$SOURCE_PKG"; \
		exit 1; \
	fi; \
	FULL_VERSION=$$(dpkg-parsechangelog -l debian/changelog --show-field Version 2>/dev/null); \
	BASE_VERSION=$$(echo "$$FULL_VERSION" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?)-.*$$/\1/'); \
	if [ -z "$$BASE_VERSION" ]; then \
		echo "Error: Failed to extract version from debian/changelog"; \
		exit 1; \
	fi; \
	if ! echo "$$BASE_VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$$'; then \
		echo "Error: Invalid version format in debian/changelog: $$BASE_VERSION"; \
		echo "  Expected format: X.Y[.Z][-rcN] (e.g., 6.8, 6.8.0, 6.8-rc1)"; \
		exit 1; \
	fi; \
	EXPECTED_TARBALL="$${SOURCE_PKG}_$${FULL_VERSION}.orig.tar.xz"; \
	if echo "$$EXPECTED_TARBALL" | grep -qE '\.\./|^/'; then \
		echo "Error: Invalid tarball name contains path traversal: $$EXPECTED_TARBALL"; \
		exit 1; \
	fi; \
	if [ ! -f $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL ]; then \
		SRC=$$(find rpm/ -maxdepth 1 -type f -name "linux-*.tar.xz" 2>/dev/null | head -1); \
		if [ -n "$$SRC" ] && [ -f "$$SRC" ]; then \
			echo "Found existing source in rpm/, copying to cache..."; \
			BASENAME=$$(basename -- "$$SRC"); \
			if ! echo "$$BASENAME" | grep -qE '^linux-[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?\.tar\.xz$$'; then \
				echo "Error: Invalid source filename format: $$BASENAME"; \
				echo "  Expected: linux-X.Y[.Z][-rcN].tar.xz"; \
				exit 1; \
			fi; \
			cp -f -- "$$SRC" $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL; \
			echo "Created: $$EXPECTED_TARBALL"; \
		else \
			echo "Downloading upstream kernel source..."; \
			UPSTREAM_VERSION=$$(echo "$$BASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+)\.0(-rc[0-9]+)?$$/\1\2/'); \
			echo "Using base version: $$BASE_VERSION (upstream: $$UPSTREAM_VERSION)"; \
			uscan --download --rename --destdir $(BUILD_CACHE_DIR) --download-version=$$UPSTREAM_VERSION 2>/dev/null || \
			uscan --download --rename --destdir $(BUILD_CACHE_DIR) --download-current-version 2>/dev/null || true; \
			if [ ! -f $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL ]; then \
				DOWNLOADED=$$(find $(BUILD_CACHE_DIR) -maxdepth 1 -type f -name "$${SOURCE_PKG}_*.orig.tar.*" ! -name "$$EXPECTED_TARBALL" 2>/dev/null | sort -V | tail -1); \
				if [ -n "$$DOWNLOADED" ] && [ -f "$$DOWNLOADED" ]; then \
					echo "Renaming downloaded tarball to $$EXPECTED_TARBALL"; \
					echo "  Source: $$(basename $$DOWNLOADED)"; \
					mv "$$DOWNLOADED" $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL; \
				else \
					echo "Error: Failed to download kernel source tarball"; \
					echo "  Tried version: $$BASE_VERSION (upstream: $$UPSTREAM_VERSION)"; \
					echo "  Expected file: $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL"; \
					echo "  Downloaded files in cache:"; \
					ls -la $(BUILD_CACHE_DIR)/$${SOURCE_PKG}_*.orig.tar.* 2>/dev/null || echo "    (none)"; \
					echo "  Or place source in rpm/ directory as: linux-$$BASE_VERSION.tar.xz"; \
					exit 1; \
				fi; \
			fi; \
		fi; \
	else \
		echo "Source tarball already exists: $$EXPECTED_TARBALL"; \
	fi
	@# Extract source to build/orig/ if not exists
	@SOURCE_PKG=$$(dpkg-parsechangelog -l debian/changelog --show-field Source 2>/dev/null || echo "linux"); \
	if ! echo "$$SOURCE_PKG" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9.+_-]*$$'; then \
		echo "Error: Invalid source package name: $$SOURCE_PKG"; \
		exit 1; \
	fi; \
	FULL_VERSION=$$(dpkg-parsechangelog -l debian/changelog --show-field Version 2>/dev/null); \
	BASE_VERSION=$$(echo "$$FULL_VERSION" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?)-.*$$/\1/'); \
	EXPECTED_TARBALL="$${SOURCE_PKG}_$${FULL_VERSION}.orig.tar.xz"; \
	if echo "$$EXPECTED_TARBALL" | grep -qE '\.\./|^/'; then \
		echo "Error: Invalid tarball name contains path traversal: $$EXPECTED_TARBALL"; \
		exit 1; \
	fi; \
	if [ ! -d $(CURDIR)/build/orig/linux-* ]; then \
		if [ ! -f $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL ]; then \
			echo "Error: Source tarball not found: $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL"; \
			echo "  Run 'make deb-setup' failed to download source"; \
			exit 1; \
		fi; \
		echo "Extracting source to build/orig/..."; \
		mkdir -p $(CURDIR)/build/orig; \
		tar -C $(CURDIR)/build/orig -xaf $(BUILD_CACHE_DIR)/$$EXPECTED_TARBALL; \
	else \
		echo "Source already extracted: $$(ls -d $(CURDIR)/build/orig/linux-* 2>/dev/null)"; \
	fi
	@# Create build directory by copying source
	@SRC_DIR=$$(ls -d $(CURDIR)/build/orig/linux-* 2>/dev/null | head -1); \
	if [ -z "$$SRC_DIR" ]; then \
		echo "Error: Source directory not found in build/orig/"; \
		exit 1; \
	fi; \
	echo "Creating build directory: $(BUILD_DIR)..."; \
	rm -rf $(BUILD_DIR); \
	rsync -a --exclude='.git' "$$SRC_DIR/" $(BUILD_DIR)/
	@# Copy debian directory to build directory (dereference symlinks with -L)
	@echo "Copying debian/ configuration to build directory..."
	@rsync -aL --exclude='.git' --delete debian/ $(BUILD_DIR)/debian/
	@# Auto-detect GCC version based on Ubuntu version
	@echo "Detecting GCC version for current Ubuntu..."
	@GCC_VER=$$(bash debian/bin/detect-gcc-version.sh 2>/dev/null || echo "14"); \
	echo "Detected GCC version: gcc-$$GCC_VER"; \
	sed -i "s|c_compiler = 'gcc-[0-9]*'|c_compiler = 'gcc-$$GCC_VER'|g" $(BUILD_DIR)/debian/config/defines.toml; \
	echo "Updated c_compiler in defines.toml to: gcc-$$GCC_VER"
	@# Auto-generate localversion and abi_suffix from changelog
	@echo "Extracting version suffix from debian/changelog..."
	@SUFFIX=$$(head -1 debian/changelog | sed -n 's/.*(\([^)]*\)).*/\1/p' | tr '[:upper:]' '[:lower:]' | sed 's/^[0-9.]*//'); \
	if [ -n "$$SUFFIX" ]; then \
		echo "$$SUFFIX" > $(BUILD_DIR)/localversion; \
		echo "Created localversion file with: $$SUFFIX"; \
		sed -i "s|abi_suffix = '.*'|abi_suffix = '$$SUFFIX'|g" $(BUILD_DIR)/debian/config/defines.toml; \
		echo "Updated abi_suffix in defines.toml to: $$SUFFIX"; \
	fi
	@# Apply patches
	@echo "Applying patches..."
	@cd $(BUILD_DIR) && \
	if ! QUILT_PATCHES='$(CURDIR)/debian/patches' QUILT_PC=.pc quilt push --quiltrc - -a --fuzz=2; then \
		echo ""; \
		echo "Error: Failed to apply patches"; \
		echo "  Patches directory: $(CURDIR)/debian/patches"; \
		echo "  Series file: $(CURDIR)/debian/patches/series"; \
		echo ""; \
		echo "To debug:"; \
		echo "  cd $(BUILD_DIR)"; \
		echo "  QUILT_PATCHES='$(CURDIR)/debian/patches' quilt push -v"; \
		echo ""; \
		exit 1; \
	fi
	@# Generate control file
	@echo "Generating debian/control..."
	@cd $(BUILD_DIR) && $(MAKE) -f debian/rules debian/control || true
	@echo ""
	@echo "Setup completed!"
	@echo "  Build directory: $(BUILD_DIR)"
	@echo "  Packages directory: $(BUILD_PACKAGES_DEB_DIR)"
	@echo "  Logs directory: $(BUILD_LOGS_DIR)"
	@echo "  Cache directory: $(BUILD_CACHE_DIR)"

# ------------------------------------------------------------
# deb-config: customize source name / package version / kernel
# release suffix in the build tree AFTER deb-setup.
#
# Purely additive: it only patches the generated tree in
# $(BUILD_DIR) (git-ignored) and never alters deb-setup/deb or
# any tracked file. All three parameters are optional; unset ones
# keep whatever deb-setup derived from debian/changelog.
#
# NOTE: run this AFTER 'make deb-setup' and BEFORE 'make deb'.
#       Re-running deb-setup rebuilds the tree and drops these
#       overrides, so re-run deb-config afterwards.
#
# Usage:
#   make deb-config SOURCENAME=linux-intel-6.18 \
#                   PKGVERSION=6.18.0-mainline+preprod+linux+260623t022223z \
#                   KERNELRELEASE=-intel
#
#   SOURCENAME    KDEB_SOURCENAME. Source package name; drives the
#                 binary package prefix (linux<suffix>-image-*, ...),
#                 so it MUST start with 'linux'.
#   PKGVERSION    KDEB_PKGVERSION. Full .deb version <kernelver>-<revision>,
#                 e.g. 6.18.0-mainline+preprod+linux+260623t022223z.
#   KERNELRELEASE uname -r suffix appended after the numeric kernel
#                 version (localversion + abi_suffix), e.g. -intel.
# ------------------------------------------------------------
deb-config:
	@if [ ! -f "$(BUILD_DIR)/debian/changelog" ]; then \
		echo "Error: Build tree not found at $(BUILD_DIR)."; \
		echo "  Run 'make deb-setup' first, then 'make deb-config ...'."; \
		exit 1; \
	fi
	@if [ -z "$(SOURCENAME)" ] && [ -z "$(PKGVERSION)" ] && [ -z "$(KERNELRELEASE)" ]; then \
		echo "Nothing to do: set at least one of SOURCENAME=, PKGVERSION=, KERNELRELEASE="; \
		echo ""; \
		echo "Examples:"; \
		echo "  make deb-config SOURCENAME=linux-intel-6.18"; \
		echo "  make deb-config PKGVERSION=6.18.0-mainline+preprod+linux+260623t022223z"; \
		echo "  make deb-config KERNELRELEASE=-intel"; \
		exit 1; \
	fi
	@echo "======================================================================"
	@echo "Customizing Debian build tree: $(BUILD_DIR)"
	@echo "======================================================================"
	@# --- SOURCENAME (KDEB_SOURCENAME): source package name -> binary name prefix
	@if [ -n "$(SOURCENAME)" ]; then \
		if ! echo "$(SOURCENAME)" | grep -qE '^linux[a-zA-Z0-9.+_-]*$$'; then \
			echo "Error: Invalid SOURCENAME '$(SOURCENAME)'"; \
			echo "  Must start with 'linux' and use only: a-z A-Z 0-9 . + _ -"; \
			echo "  (binary names are derived as linux<suffix>-*, so the 'linux' prefix is required)"; \
			exit 1; \
		fi; \
		sed -i "1s/^[^ ]* (/$(SOURCENAME) (/" $(BUILD_DIR)/debian/changelog; \
		echo "  SOURCENAME     -> $(SOURCENAME)  (binaries: $(SOURCENAME)-image-*, ...)"; \
	fi
	@# --- PKGVERSION (KDEB_PKGVERSION): full .deb package version
	@if [ -n "$(PKGVERSION)" ]; then \
		if ! echo "$(PKGVERSION)" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?(~[A-Za-z0-9.+~]+)?-[A-Za-z0-9+.~]+$$'; then \
			echo "Error: Invalid PKGVERSION '$(PKGVERSION)'"; \
			echo "  Expected <kernelver>-<revision>, e.g. 6.18.0-mainline+preprod+linux+260623t022223z"; \
			echo "    - kernelver must start with X.Y (optionally .Z, -rcN, ~mod)"; \
			echo "    - revision (after the last '-') may use only [A-Za-z0-9+.~]"; \
			exit 1; \
		fi; \
		sed -i "1s/([^)]*)/($(PKGVERSION))/" $(BUILD_DIR)/debian/changelog; \
		echo "  PKGVERSION     -> $(PKGVERSION)"; \
	fi
	@# --- KERNELRELEASE: uname -r suffix (localversion + abi_suffix)
	@if [ -n "$(KERNELRELEASE)" ]; then \
		if ! echo "$(KERNELRELEASE)" | grep -qE '^[a-zA-Z0-9.+_~-]+$$'; then \
			echo "Error: Invalid KERNELRELEASE suffix '$(KERNELRELEASE)'"; \
			echo "  Allowed characters: a-z A-Z 0-9 . + _ ~ -"; \
			exit 1; \
		fi; \
		case "$(KERNELRELEASE)" in \
			-*|+*|~*) ;; \
			*) echo "  Warning: KERNELRELEASE '$(KERNELRELEASE)' has no leading separator (- + ~);"; \
			   echo "           uname -r will read as <version>$(KERNELRELEASE) with no delimiter." ;; \
		esac; \
		case "$(KERNELRELEASE)" in \
			*[0-9]t[0-9]*z*) ;; \
			*) echo "  Warning: KERNELRELEASE '$(KERNELRELEASE)' carries no build timestamp;"; \
			   echo "           the ABI serial (.N) is disabled, so repeated builds of the same"; \
			   echo "           version may produce colliding module directories." ;; \
		esac; \
		echo "$(KERNELRELEASE)" > $(BUILD_DIR)/localversion; \
		sed -i "s|abi_suffix = '.*'|abi_suffix = '$(KERNELRELEASE)'|g" $(BUILD_DIR)/debian/config/defines.toml; \
		echo "  KERNELRELEASE  -> <version>$(KERNELRELEASE)  (localversion + abi_suffix)"; \
	fi
	@echo ""
	@echo "Regenerating debian/control..."
	@# Use 'debian/control-real', NOT 'debian/control': the latter regenerates
	@# the file and then exits 1 ON PURPOSE (see control-real-fail in debian/rules),
	@# which is why deb-setup calls it with '|| true'. control-real regenerates
	@# control AND refreshes control.md5sum with a truthful exit code, so a real
	@# gencontrol failure is still caught and a later 'make deb' won't re-trigger
	@# the intentional-fail gate. Output is left visible for genuine errors.
	@cd $(BUILD_DIR) && $(MAKE) -f debian/rules debian/control-real || \
		{ echo "Error: gencontrol failed; check the SOURCENAME/PKGVERSION/KERNELRELEASE values above."; exit 1; }
	@echo ""
	@echo "Customization applied. Current changelog header:"
	@head -1 $(BUILD_DIR)/debian/changelog | sed 's/^/  /'
	@echo ""
	@echo "Next: make deb   (or 'make deb-minimal')"

# ------------------------------------------------------------
# deb-nonrt / deb-rt: build a single kernel flavour.
#
# The tree defines two real flavours in
# debian/config/amd64/defines.toml: 'amd64' (non-RT, default) and
# 'rt-amd64' (adds config.rt). A plain 'make deb' builds BOTH. These
# targets trim defines.toml to keep only one flavour, regenerate
# debian/control, then run the normal build:
#
#   deb-nonrt -> keep 'amd64',    then 'make deb'          (full: + tools)
#   deb-rt    -> keep 'rt-amd64', then 'make deb-minimal'  (image only)
#
# Like deb-config, this only patches the git-ignored build tree and
# never touches tracked files. Run AFTER deb-setup (and deb-config, if
# used); re-running deb-setup rebuilds the tree and drops the trim.
# ------------------------------------------------------------
deb-nonrt:
	@$(MAKE) --no-print-directory _deb-select-flavour FLAVOUR=amd64 FLAVOUR_DESC="non-RT (standard)"
	@$(MAKE) --no-print-directory deb

deb-rt:
	@$(MAKE) --no-print-directory _deb-select-flavour FLAVOUR=rt-amd64 FLAVOUR_DESC="RT (PREEMPT_RT)"
	@$(MAKE) --no-print-directory deb-minimal

# Internal: keep only the flavour named by $(FLAVOUR) in the build
# tree's amd64/defines.toml and regenerate debian/control. Not meant
# to be called directly.
_deb-select-flavour:
	@if [ ! -f "$(BUILD_DIR)/debian/config/amd64/defines.toml" ]; then \
		echo "Error: Build tree not found at $(BUILD_DIR)."; \
		echo "  Run 'make deb-setup' first, then 'make deb-nonrt' / 'make deb-rt'."; \
		exit 1; \
	fi
	@if ! grep -q "name = '$(FLAVOUR)'" $(BUILD_DIR)/debian/config/amd64/defines.toml; then \
		echo "Error: flavour '$(FLAVOUR)' not found in amd64/defines.toml"; \
		exit 1; \
	fi
	@echo "======================================================================"
	@echo "Selecting single build flavour: $(FLAVOUR)  [$(FLAVOUR_DESC)]"
	@echo "======================================================================"
	@# Drop every [[flavour]] block except the one named $(FLAVOUR). A block runs
	@# from '[[flavour]]' up to the next '[[...]]' (the following flavour or the
	@# '[[featureset]]' section); single-bracket [flavour.*] subtables stay inside
	@# it. The name is read from the 'name = '\''...'\''' line via sub() so no
	@# literal quote needs embedding in the awk program.
	@awk -v keep='$(FLAVOUR)' 'function flush(){ if(inflav && k) printf "%s", buf; buf=""; k=0 } /^\[\[flavour\]\]/{ flush(); inflav=1; buf=$$0"\n"; next } inflav && /^\[\[/{ flush(); inflav=0; print; next } inflav{ buf=buf $$0"\n"; if($$0 ~ /^name = /){ v=$$0; sub(/^name = ./,"",v); sub(/.$$/,"",v); if(v==keep) k=1 } next } { print } END{ flush() }' $(BUILD_DIR)/debian/config/amd64/defines.toml > $(BUILD_DIR)/debian/config/amd64/defines.toml.tmp && mv $(BUILD_DIR)/debian/config/amd64/defines.toml.tmp $(BUILD_DIR)/debian/config/amd64/defines.toml
	@echo "  Flavours now in defines.toml:"
	@grep -E "^name = '(amd64|rt-amd64|test)'" $(BUILD_DIR)/debian/config/amd64/defines.toml | sed "s/^/    /"
	@echo ""
	@echo "Regenerating debian/control..."
	@# Same rationale as deb-config: use control-real (truthful exit code) rather
	@# than the intentional-fail 'control' target.
	@cd $(BUILD_DIR) && $(MAKE) -f debian/rules debian/control-real || \
		{ echo "Error: gencontrol failed after selecting flavour '$(FLAVOUR)'."; exit 1; }
	@echo ""

deb-modules:
	@echo "======================================================================"
	@echo "Building Debian kernel module packages..."
	@echo "======================================================================"
	@echo "Available module packaging scripts:"
	@ls -1 debian/bin/create-module-package.sh 2>/dev/null || echo "  (none found)"
	@echo ""
	@echo "See debian/MODULE_PACKAGING.md for instructions"

# ============================================================
# RPM Package Targets
# ============================================================
# Note: RPM kernel version is automatically extracted from debian/changelog

rpm-prepare:
	@echo "======================================================================"
	@echo "Preparing RPM source files..."
	@echo "======================================================================"
	@KVER=$$(head -1 debian/changelog | sed -n 's/.*(\([^)]*\)).*/\1/p' | tr '[:upper:]' '[:lower:]' | cut -d- -f1); \
	if [ -z "$$KVER" ]; then \
		echo "Error: Failed to extract version from debian/changelog"; \
		exit 1; \
	fi; \
	if ! echo "$$KVER" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$$'; then \
		echo "Error: Invalid kernel version format: $$KVER"; \
		echo "  Expected format: X.Y[.Z][-rcN] (e.g., 6.8, 6.8.0, 6.8-rc1)"; \
		exit 1; \
	fi; \
	echo "Kernel Version: $$KVER (from debian/changelog)"; \
	echo ""; \
	cd rpm && ./scripts/prepare-sources.sh --version $$KVER; \
	echo ""; \
	echo "RPM sources prepared!"; \
	echo "  - linux-$$KVER.tar.xz"
	@echo "  - patches.tar.gz (332 patches)"
	@echo "  - kernel-x86_64.config"
	@echo "  - kernel-x86_64-rt.config"
	@echo ""
	@echo "Next: make rpm"

rpm:
	@echo "======================================================================"
	@echo "Building RPM packages..."
	@echo "======================================================================"
	@# Extract version from debian/changelog (convert to lowercase)
	@FULL_VERSION=$$(head -1 debian/changelog | sed -n 's/.*(\([^)]*\)).*/\1/p' | tr '[:upper:]' '[:lower:]'); \
	echo "Version from changelog: $$FULL_VERSION"
	@# Check if source files exist
	@if [ ! -f rpm/linux-*.tar.xz ]; then \
		echo "Error: Source files not found."; \
		echo "Run 'make rpm-prepare' first."; \
		exit 1; \
	fi
	cd rpm && ./scripts/build.sh --jobs $(JOBS) $(RPM_BUILD_FLAGS)
	@# Move packages to packages/rpm/ directory
	@mkdir -p $(BUILD_PACKAGES_RPM_DIR)
	@echo "Moving RPM packages to $(BUILD_PACKAGES_RPM_DIR)..."
	@find ~/rpmbuild/RPMS/ -name "*.rpm" -type f -exec mv -f {} $(BUILD_PACKAGES_RPM_DIR)/ \; 2>/dev/null || true
	@find ~/rpmbuild/SRPMS/ -name "*.rpm" -type f -exec mv -f {} $(BUILD_PACKAGES_RPM_DIR)/ \; 2>/dev/null || true
	@echo ""
	@echo "RPM packages built successfully!"
	@echo "Packages are in: $(BUILD_PACKAGES_RPM_DIR)"
	@# Show generated package names
	@echo ""
	@echo "Generated packages:"
	@ls -1 $(BUILD_PACKAGES_RPM_DIR)/*.rpm 2>/dev/null | xargs -n1 basename | sed 's/^/  /' || true
	@$(MAKE) verify-rpm-packages

rpm-rt:
	@echo "======================================================================"
	@echo "Building RPM packages (RT kernel)..."
	@echo "======================================================================"
	@# Extract version from debian/changelog (convert to lowercase)
	@FULL_VERSION=$$(head -1 debian/changelog | sed -n 's/.*(\([^)]*\)).*/\1/p' | tr '[:upper:]' '[:lower:]'); \
	echo "Version from changelog: $$FULL_VERSION"
	@# Check if source files exist
	@if [ ! -f rpm/linux-*.tar.xz ]; then \
		echo "Error: Source files not found."; \
		echo "Run 'make rpm-prepare' first."; \
		exit 1; \
	fi
	@# Check if RT config exists
	@if [ ! -f rpm/kernel-x86_64-rt.config ]; then \
		echo "Error: RT config not found: rpm/kernel-x86_64-rt.config"; \
		echo "Run 'make rpm-prepare' to generate configs."; \
		exit 1; \
	fi
	cd rpm && ./scripts/build.sh --jobs $(JOBS) --define "with_rt 1" $(RPM_BUILD_FLAGS)
	@# Move packages to packages/rpm/ directory
	@mkdir -p $(BUILD_PACKAGES_RPM_DIR)
	@echo "Moving RPM packages to $(BUILD_PACKAGES_RPM_DIR)..."
	@find ~/rpmbuild/RPMS/ -name "*.rpm" -type f -exec mv -f {} $(BUILD_PACKAGES_RPM_DIR)/ \; 2>/dev/null || true
	@find ~/rpmbuild/SRPMS/ -name "*.rpm" -type f -exec mv -f {} $(BUILD_PACKAGES_RPM_DIR)/ \; 2>/dev/null || true
	@echo ""
	@echo "RPM packages (RT kernel) built successfully!"
	@echo "Packages are in: $(BUILD_PACKAGES_RPM_DIR)"
	@# Show generated package names
	@echo ""
	@echo "Generated packages:"
	@ls -1 $(BUILD_PACKAGES_RPM_DIR)/kernel-rt*.rpm 2>/dev/null | xargs -n1 basename | sed 's/^/  /' || true
	@$(MAKE) verify-rpm-packages

rpm-all:
	@echo "======================================================================"
	@echo "Building all RPM packages (standard + RT)..."
	@echo "======================================================================"
	@# Check if source files exist
	@if [ ! -f rpm/linux-*.tar.xz ]; then \
		echo "Error: Source files not found."; \
		echo "Run 'make rpm-prepare' first."; \
		exit 1; \
	fi
	@echo ""
	@echo "[1/2] Building standard kernel packages..."
	@echo ""
	@$(MAKE) rpm
	@echo ""
	@echo "[2/2] Building RT kernel packages..."
	@echo ""
	@$(MAKE) rpm-rt
	@echo ""
	@echo "======================================================================"
	@echo "All RPM packages built successfully!"
	@echo "======================================================================"
	@echo "Standard kernel: kernel-*"
	@echo "RT kernel:       kernel-rt-*"
	@echo "Packages are in: $(BUILD_PACKAGES_RPM_DIR)"
	@echo ""
	@ls -1 $(BUILD_PACKAGES_RPM_DIR)/*.rpm 2>/dev/null | xargs -n1 basename | sed 's/^/  /' || true

rpm-quick:
	@echo "======================================================================"
	@echo "Quick RPM build (binary packages only)..."
	@echo "======================================================================"
	cd rpm && ./scripts/build.sh --skip-prep --jobs $(JOBS)

rpm-update:
	@echo "======================================================================"
	@echo "Updating RPM version information..."
	@echo "======================================================================"
	@echo "Usage: make rpm-update VERSION=6.8.0 RELEASE=1"
	@echo ""
	@if [ -z "$(VERSION)" ] || [ -z "$(RELEASE)" ]; then \
		echo "Error: VERSION and RELEASE are required"; \
		echo "Example: make rpm-update VERSION=6.8.0 RELEASE=1"; \
		exit 1; \
	fi
	cd rpm && ./scripts/update-version.sh -v $(VERSION) -r $(RELEASE)

# ============================================================
# Combined Targets
# ============================================================

all:
	@echo "======================================================================"
	@echo "Building all packages (Debian + RPM standard + RPM RT)..."
	@echo "======================================================================"
	@# Check and setup Debian build if needed
	@if [ ! -f "$(BUILD_DIR)/Makefile" ]; then \
		echo "Debian build directory not found or incomplete. Running deb-setup..."; \
		$(MAKE) deb-setup; \
	fi
	@# Check and setup RPM build if needed
	@if [ ! -f rpm/linux-*.tar.xz ]; then \
		echo "RPM source files not found. Running rpm-prepare..."; \
		$(MAKE) rpm-prepare; \
	fi
	@# Build all packages
	$(MAKE) deb
	$(MAKE) rpm-all
	@echo ""
	@echo "======================================================================"
	@echo "All packages built successfully!"
	@echo "======================================================================"
	@echo "Debian packages: $(BUILD_PACKAGES_DEB_DIR)"
	@echo "RPM packages:    $(BUILD_PACKAGES_RPM_DIR)"
	@echo "  - kernel-* (standard)"
	@echo "  - kernel-rt-* (RT)"

# ============================================================
# Clean Targets
# ============================================================

clean: clean-deb clean-rpm
	@echo "All build artifacts cleaned."

clean-deb:
	@echo "Cleaning Debian build artifacts..."
	-rm -rf $(CURDIR)/build
	@echo "Debian artifacts cleaned."

clean-rpm:
	@echo "Cleaning RPM build artifacts..."
	-rm -rf ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SRPMS}/*kernel*
	@echo "RPM artifacts cleaned."

# ============================================================
# Status and Info
# ============================================================

status:
	@echo "======================================================================"
	@echo "Build Environment Status"
	@echo "======================================================================"
	@echo ""
	@echo "Git Branch:"
	@git branch --show-current
	@echo ""
	@echo "Git Status:"
	@git status --short
	@echo ""
	@echo "Debian Packages ($(BUILD_PACKAGES_DEB_DIR)):"
	@ls -lh $(BUILD_PACKAGES_DEB_DIR)/*.deb 2>/dev/null | tail -5 || echo "  (none found)"
	@echo ""
	@echo "RPM Packages ($(BUILD_PACKAGES_RPM_DIR)):"
	@ls -lh $(BUILD_PACKAGES_RPM_DIR)/*.rpm 2>/dev/null | tail -5 || echo "  (none found)"
	@echo ""
	@echo "Parallel Jobs: $(JOBS)"
	@echo "======================================================================"

# ============================================================
# Package Verification
# ============================================================

verify-deb-packages:
	@echo ""
	@echo "======================================================================"
	@echo "Verifying Debian package consistency..."
	@echo "======================================================================"
	@FAILED=0; \
	for binary in $(BUILD_PACKAGES_DEB_DIR)/linux-binary-*.deb; do \
		if [ -f "$$binary" ]; then \
			modules=$$(echo $$binary | sed 's/linux-binary-/linux-modules-/'); \
			if [ -f "$$modules" ]; then \
				echo ""; \
				if ! $(CURDIR)/scripts/verify-kernel-package.sh "$$binary" "$$modules"; then \
					FAILED=1; \
				fi; \
			else \
				echo "⚠️  Warning: No matching modules package for $$(basename $$binary)"; \
			fi; \
		fi; \
	done; \
	if [ $$FAILED -eq 1 ]; then \
		echo ""; \
		echo "❌ Package verification FAILED!"; \
		echo "   Fix required before deployment."; \
		echo ""; \
		exit 1; \
	else \
		echo ""; \
		echo "✅ All packages verified successfully!"; \
		echo ""; \
	fi

verify-rpm-packages:
	@echo ""
	@echo "======================================================================"
	@echo "Verifying RPM package consistency..."
	@echo "======================================================================"
	@FAILED=0; \
	OLD_SPEC=0; \
	for rpm in $(BUILD_PACKAGES_RPM_DIR)/kernel-[0-9]*.x86_64.rpm $(BUILD_PACKAGES_RPM_DIR)/kernel-rt-[0-9]*.x86_64.rpm; do \
		if [ -f "$$rpm" ]; then \
			echo ""; \
			if $(CURDIR)/scripts/verify-kernel-package-rpm.sh "$$rpm"; then \
				continue; \
			else \
				EXIT_CODE=$$?; \
				if [ $$EXIT_CODE -eq 2 ]; then \
					OLD_SPEC=1; \
				else \
					FAILED=1; \
				fi; \
			fi; \
		fi; \
	done; \
	echo ""; \
	if [ $$FAILED -eq 1 ]; then \
		echo "❌ Package verification FAILED!"; \
		echo "   Fix required before deployment."; \
		echo ""; \
		exit 1; \
	elif [ $$OLD_SPEC -eq 1 ]; then \
		echo "⚠️  Package(s) need to be rebuilt with updated spec file"; \
		echo "   Run: make clean-rpm && make rpm"; \
		echo ""; \
		exit 0; \
	else \
		echo "✅ All packages verified successfully!"; \
		echo ""; \
	fi

verify-packages: verify-deb-packages verify-rpm-packages
	@echo "======================================================================"
	@echo "✅ All packages (DEB + RPM) verified successfully!"
	@echo "======================================================================"

.PHONY: verify-deb-packages verify-rpm-packages verify-packages
