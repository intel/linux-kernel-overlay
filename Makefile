# Makefile for Kernel Packaging System
# Supports both Debian (.deb) and RPM (.rpm) package builds

.PHONY: help deb rpm rpm-rt rpm-all all clean clean-deb clean-rpm status

# Default target
help:
	@echo "============================================================"
	@echo "Kernel Packaging System - Unified Build Interface"
	@echo "============================================================"
	@echo ""
	@echo "Targets:"
	@echo "  deb              Build Debian packages (full: kernel + tools)"
	@echo "  deb-minimal      Build Debian packages (minimal: kernel image only)"
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
	@echo "  deb-modules      Build Debian kernel module packages"
	@echo "  deb-minimal      Build kernel image only (fast, no tools)"
	@echo ""
	@echo "RPM Targets:"
	@echo "  rpm-prepare      Prepare RPM source files (first-time only)"
	@echo "  rpm-quick        Quick RPM build (binary only)"
	@echo "  rpm-update       Update RPM version info"
	@echo ""
	@echo "Examples:"
	@echo "  make deb                    # Build all Debian packages (kernel + tools)"
	@echo "  make deb-minimal            # Build kernel image only (faster)"
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
DEB_BUILD_FLAGS ?= -B -uc -us -j$(JOBS)
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
	@# Move all packages and source files to packages/deb/ directory
	@mkdir -p $(BUILD_PACKAGES_DEB_DIR)
	@echo "Moving packages to $(BUILD_PACKAGES_DEB_DIR)..."
	@mv -f $(CURDIR)/build/*.deb $(CURDIR)/build/*.ddeb $(CURDIR)/build/*.dsc $(CURDIR)/build/*.tar.* $(CURDIR)/build/*.changes $(CURDIR)/build/*.buildinfo $(BUILD_PACKAGES_DEB_DIR)/ 2>/dev/null || true
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
	@echo ""
	cd $(BUILD_DIR) && DEB_BUILD_PROFILES="$(DEB_BUILD_PROFILES) pkg.linux.notools" dpkg-buildpackage $(DEB_BUILD_FLAGS)
	@# Move all packages and source files to packages/deb/ directory
	@mkdir -p $(BUILD_PACKAGES_DEB_DIR)
	@echo "Moving packages to $(BUILD_PACKAGES_DEB_DIR)..."
	@mv -f $(CURDIR)/build/*.deb $(CURDIR)/build/*.ddeb $(CURDIR)/build/*.dsc $(CURDIR)/build/*.tar.* $(CURDIR)/build/*.changes $(CURDIR)/build/*.buildinfo $(BUILD_PACKAGES_DEB_DIR)/ 2>/dev/null || true
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
	@# Download or copy upstream source if not exists
	@if [ ! -f $(BUILD_CACHE_DIR)/linux_*.orig.tar.xz ]; then \
		SRC=$$(find rpm/ -maxdepth 1 -type f -name "linux-*.tar.xz" 2>/dev/null | head -1); \
		if [ -n "$$SRC" ] && [ -f "$$SRC" ]; then \
			echo "Found existing source in rpm/, copying to cache..."; \
			BASENAME=$$(basename -- "$$SRC"); \
			if ! echo "$$BASENAME" | grep -qE '^linux-[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?\.tar\.xz$$'; then \
				echo "Error: Invalid source filename format: $$BASENAME"; \
				echo "  Expected: linux-X.Y[.Z][-rcN].tar.xz"; \
				exit 1; \
			fi; \
			cp -f -- "$$SRC" $(BUILD_CACHE_DIR)/; \
			cd $(BUILD_CACHE_DIR) && \
			NEWNAME=$$(echo "$$BASENAME" | sed 's/^linux-/linux_/') && \
			mv -f -- "$$BASENAME" "$$NEWNAME" && \
			if ! echo "$$NEWNAME" | grep -q '.orig.tar.xz$$'; then \
				FINALNAME=$$(echo "$$NEWNAME" | sed 's/.tar.xz$$/.orig.tar.xz/'); \
				mv -f -- "$$NEWNAME" "$$FINALNAME"; \
			fi; \
			echo "Created: $$(find . -maxdepth 1 -type f -name 'linux_*.orig.tar.xz' -printf '%f\n' 2>/dev/null | head -1)"; \
		else \
			echo "Downloading upstream kernel source..."; \
			BASE_VERSION=$$(head -1 debian/changelog | sed -n 's/.*(\([0-9.]*\).*/\1/p'); \
			if [ -z "$$BASE_VERSION" ]; then \
				echo "Error: Failed to extract version from debian/changelog"; \
				exit 1; \
			fi; \
			if ! echo "$$BASE_VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$$'; then \
				echo "Error: Invalid version format in debian/changelog: $$BASE_VERSION"; \
				echo "  Expected format: X.Y[.Z][-rcN] (e.g., 6.8, 6.8.0, 6.8-rc1)"; \
				exit 1; \
			fi; \
			echo "Using base version: $$BASE_VERSION"; \
			uscan --download --rename --destdir $(BUILD_CACHE_DIR) --download-version=$$BASE_VERSION 2>/dev/null || \
			uscan --download --rename --destdir $(BUILD_CACHE_DIR) --download-current-version 2>/dev/null || true; \
			if ! ls $(BUILD_CACHE_DIR)/linux_*.orig.tar.xz >/dev/null 2>&1; then \
				echo "Error: Failed to download kernel source tarball"; \
				echo "  Tried version: $$BASE_VERSION"; \
				echo "  Please manually download to: $(BUILD_CACHE_DIR)/linux_$$BASE_VERSION.orig.tar.xz"; \
				echo "  Or place source in rpm/ directory as: linux-$$BASE_VERSION.tar.xz"; \
				exit 1; \
			fi; \
		fi; \
	else \
		echo "Source tarball already exists: $$(ls $(BUILD_CACHE_DIR)/linux_*.orig.tar.xz 2>/dev/null || echo 'none')"; \
	fi
	@# Extract source to build/orig/ if not exists
	@if [ ! -d $(CURDIR)/build/orig/linux-* ]; then \
		if ! ls $(BUILD_CACHE_DIR)/linux_*.orig.tar.xz >/dev/null 2>&1; then \
			echo "Error: Source tarball not found in $(BUILD_CACHE_DIR)"; \
			echo "  Run 'make deb-setup' failed to download source"; \
			exit 1; \
		fi; \
		echo "Extracting source to build/orig/..."; \
		mkdir -p $(CURDIR)/build/orig; \
		tar -C $(CURDIR)/build/orig -xaf $(BUILD_CACHE_DIR)/linux_*.orig.tar.xz; \
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
	@if [ ! -d "$(BUILD_DIR)" ]; then \
		echo "Debian build directory not found. Running deb-setup..."; \
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
