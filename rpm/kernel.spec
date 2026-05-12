# Kernel RPM spec file
# Based on Fedora kernel packaging with simplifications for mainline kernel builds
#
# To build:
#   rpmbuild -ba kernel.spec

# Disable debug package generation (uncomment if you want debug packages)
%define debug_package %{nil}

# Build options
# Set to 0 to skip building kernel-tools (perf, cpupower, etc.)
%define with_tools 1

# RT kernel build option
# Set to 1 to build RT kernel (uses kernel-x86_64-rt.config)
%{!?with_rt: %define with_rt 0}

# Package version information
# Version can be passed at build time with --define 'full_version 6.18.20-intel+260417t093242z'
# Otherwise defaults to basic version
%{!?full_version: %define full_version 6.18.20-intel+unknown}
%define kernel_version %(echo %{full_version} | cut -d- -f1)
%define version_suffix %(echo %{full_version} | cut -d- -f2-)

# Package release uses the full version suffix (e.g., intel+260417t093242z)
%define pkg_release %{version_suffix}%{?dist}

# Kernel build release string (used for uname -r and module paths)
# This is the full version string that will appear in uname -r
# Format: 6.18.20-intel+260417t093242z
%define buildid %{full_version}

# Architecture
%define _target_cpu x86_64

# Define standard RPM directory macros for compatibility
%{!?_unitdir: %define _unitdir /usr/lib/systemd/system}
%{!?_libexecdir: %define _libexecdir /usr/libexec}
%{!?_datadir: %define _datadir /usr/share}
%{!?_sysconfdir: %define _sysconfdir /etc}

Summary: The Linux kernel (mainline with custom patches)
%if %{with_rt}
Name: kernel-rt
%else
Name: kernel
%endif
Version: %{kernel_version}
Release: %{pkg_release}
License: GPL-2.0
URL: https://www.kernel.org/
Vendor: Custom Build

# Sources
Source0: linux-%{kernel_version}.tar.xz
%if %{with_rt}
Source1: kernel-x86_64-rt.config
%else
Source1: kernel-x86_64.config
%endif
Source2: kernel-local
Source3: patches.tar.gz

# Build scripts from Fedora
Source10: mod-sign.sh
Source11: mod-denylist.sh
Source12: filtermods.py

# Build dependencies
BuildRequires: gcc make binutils
BuildRequires: bc bison flex
BuildRequires: elfutils-devel openssl-devel
BuildRequires: ncurses-devel
BuildRequires: kmod xz rsync
BuildRequires: perl-interpreter perl-generators
BuildRequires: python3

# For kernel-tools
BuildRequires: asciidoc xmlto
BuildRequires: audit-libs-devel
BuildRequires: binutils-devel
BuildRequires: libcap-devel
BuildRequires: numactl-devel
BuildRequires: slang-devel
BuildRequires: zlib-devel

%description
The Linux kernel package contains the Linux kernel (vmlinuz), the core of your
Linux operating system. This is a mainline kernel build with custom patches.
%if %{with_rt}
This is the PREEMPT_RT real-time kernel variant.
%endif

%package devel
Summary: Development files for the kernel
Requires: %{name} = %{version}-%{release}
Provides: kernel-devel = %{version}-%{release}
Provides: kernel-devel-uname-r = %{version}-%{release}.%{_target_cpu}

%description devel
This package provides kernel headers and makefiles sufficient to build modules
against the kernel package.

%if %{with_tools}
%package tools
Summary: Kernel tools including perf, turbostat, and others
Requires: %{name} = %{version}-%{release}

%description tools
This package contains various tools for the Linux kernel:
- perf: Performance analysis tool
- turbostat: CPU frequency and power state monitoring
- x86_energy_perf_policy: x86 processor power policy tool
- tmon: Thermal monitoring and testing tool
- cpupower: CPU power management tools

%package tools-libs
Summary: Libraries for kernel tools

%description tools-libs
This package contains libraries for kernel tools.

%package tools-devel
Summary: Development files for kernel tools libraries
Requires: %{name}-tools-libs = %{version}-%{release}

%description tools-devel
This package contains development files for kernel tools libraries.
%endif

# ======================================================================
# Prep section: Extract and patch
# ======================================================================
%prep
echo "======================================================================"
echo "Prep: Extracting and patching kernel sources"
echo "======================================================================"

# Extract kernel tarball and patches using quilt-style application
# This will:
# 1. Extract linux tarball
# 2. Extract patches.tar.gz (contains patches/ dir with series file)
# 3. Apply patches one-by-one according to series file
# 4. Show which patch failed if any error occurs
%autosetup -N -n linux-%{kernel_version}

# Extract patches
tar xf %{SOURCE3}

# Apply patches using series file
echo "Applying patches from series file..."
if [ -f patches/series ]; then
    while IFS= read -r patch_line || [ -n "$patch_line" ]; do
        # Skip empty lines and comments
        [[ -z "$patch_line" ]] && continue
        [[ "$patch_line" =~ ^[[:space:]]*# ]] && continue

        # Extract patch filename (first field)
        patch_file=$(echo "$patch_line" | awk '{print $1}')

        if [ -f "patches/$patch_file" ]; then
            echo "  Applying: $patch_file"
            patch -p1 -i "patches/$patch_file" || {
                echo "ERROR: Failed to apply patch: $patch_file"
                exit 1
            }
        else
            echo "WARNING: Patch not found: $patch_file"
        fi
    done < patches/series
    echo "All patches applied successfully!"
else
    echo "ERROR: patches/series not found"
    exit 1
fi

# Copy config file
cp %{SOURCE1} .config

# Append kernel-local customizations if present
if [ -s %{SOURCE2} ]; then
    echo "Appending kernel-local customizations..."
    cat %{SOURCE2} >> .config
fi

# Run olddefconfig to process the config
echo "Processing kernel configuration..."
make ARCH=%{_target_cpu} olddefconfig

# Note: LOCALVERSION is set during make (not via localversion file)
# to avoid double-appending the suffix
echo "Kernel will be built with version: %{buildid}"

# ======================================================================
# Build section
# ======================================================================
%build
echo "======================================================================"
echo "Build: Compiling kernel"
echo "======================================================================"
echo "Kernel version string: %{buildid}"

# Set C include path for Ubuntu/Debian multiarch compatibility
# This is needed for perf tools to find gnu/libc-version.h
export C_INCLUDE_PATH=/usr/include/x86_64-linux-gnu:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/include/x86_64-linux-gnu:$CPLUS_INCLUDE_PATH

# Build the kernel
# Use KERNELRELEASE to ensure consistent version string
make ARCH=%{_target_cpu} LOCALVERSION="-%{version_suffix}" %{?_smp_mflags} all

%if %{with_tools}
# Build kernel tools (perf, turbostat, etc.)
echo "Building kernel tools..."
# Add multiarch include path for Ubuntu/Debian compatibility
# Force feature-glibc to be detected (we know Ubuntu has glibc)
%global perf_make \
  make -s CFLAGS="${RPM_OPT_FLAGS} -I/usr/include/x86_64-linux-gnu" EXTRA_CFLAGS="${RPM_OPT_FLAGS} -I/usr/include/x86_64-linux-gnu" feature-glibc=1 %{?cross_opts} -C tools/perf V=1 NO_PERF_READ_VDSO32=1 NO_PERF_READ_VDSOX32=1 WERROR=0 NO_LIBUNWIND=1 HAVE_CPLUS_DEMANGLE=1 NO_GTK2=1 NO_STRLCPY=1 NO_BIONIC=1 LIBTRACEEVENT_DYNAMIC=1 prefix=%{_prefix} lib=%{_lib}

%{perf_make} all

# Build other tools
make -s -C tools/power/cpupower CPUFREQ_BENCH=false
make -s -C tools/power/x86/x86_energy_perf_policy
make -s -C tools/power/x86/turbostat
make -s -C tools/thermal/tmon
%else
echo "Skipping kernel tools build (with_tools=0)"
%endif

# ======================================================================
# Install section
# ======================================================================
%install
echo "======================================================================"
echo "Install: Installing kernel and modules"
echo "======================================================================"
echo "Installing kernel version: %{buildid}"

mkdir -p %{buildroot}/boot
mkdir -p %{buildroot}/lib/modules/%{buildid}
mkdir -p %{buildroot}%{_prefix}

# Install kernel image
cp -v arch/x86/boot/bzImage %{buildroot}/boot/vmlinuz-%{buildid}
cp -v System.map %{buildroot}/boot/System.map-%{buildid}
cp -v .config %{buildroot}/boot/config-%{buildid}

# Install modules with correct version string
make ARCH=%{_target_cpu} LOCALVERSION="-%{version_suffix}" INSTALL_MOD_PATH=%{buildroot} modules_install

# Verify module installation path
echo "Checking installed module path..."
ls -ld %{buildroot}/lib/modules/%{buildid} || echo "ERROR: Module path mismatch!"

# Install kernel development files
mkdir -p %{buildroot}/usr/src/kernels/%{buildid}

# Copy essential files for module building
cp -v Makefile %{buildroot}/usr/src/kernels/%{buildid}/
cp -v .config %{buildroot}/usr/src/kernels/%{buildid}/
cp -v Module.symvers %{buildroot}/usr/src/kernels/%{buildid}/

# Copy headers and scripts
rsync -av --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
    include/ %{buildroot}/usr/src/kernels/%{buildid}/include/
rsync -av --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
    scripts/ %{buildroot}/usr/src/kernels/%{buildid}/scripts/

# Copy arch-specific files
mkdir -p %{buildroot}/usr/src/kernels/%{buildid}/arch/x86
rsync -av --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
    arch/x86/include/ %{buildroot}/usr/src/kernels/%{buildid}/arch/x86/include/
rsync -av --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
    arch/x86/kernel/asm-offsets.s %{buildroot}/usr/src/kernels/%{buildid}/arch/x86/kernel/ || true

%if %{with_tools}
# Install kernel tools
echo "Installing kernel tools..."
%{perf_make} DESTDIR=%{buildroot} install install-python_ext

# Install cpupower
make -C tools/power/cpupower DESTDIR=%{buildroot} libdir=%{_libdir} mandir=%{_mandir} CPUFREQ_BENCH=false install
chmod 0755 %{buildroot}%{_libdir}/libcpupower.so*
mkdir -p %{buildroot}%{_unitdir}

# Install x86_energy_perf_policy and turbostat
make -C tools/power/x86/x86_energy_perf_policy DESTDIR=%{buildroot} install
make -C tools/power/x86/turbostat DESTDIR=%{buildroot} install

# Install tmon
make -C tools/thermal/tmon INSTALL_ROOT=%{buildroot} install
%else
echo "Skipping kernel tools installation (with_tools=0)"
%endif

# ======================================================================
# Files section
# ======================================================================
%files
/boot/vmlinuz-%{buildid}
/boot/System.map-%{buildid}
/boot/config-%{buildid}
/lib/modules/%{buildid}

%files devel
/usr/src/kernels/%{buildid}

%if %{with_tools}
%files tools
%defattr(-,root,root)
%{_bindir}/perf
%{_bindir}/trace
%{_bindir}/cpupower
%{_bindir}/x86_energy_perf_policy
%{_bindir}/turbostat
%{_bindir}/tmon
%{_libexecdir}/perf-core
%{_mandir}/man1/perf*
%{_mandir}/man1/cpupower*
%{_mandir}/man8/x86_energy_perf_policy*
%{_mandir}/man8/turbostat*
%{_sysconfdir}/cpupower-service.conf
%{_sysconfdir}/bash_completion.d/perf
%{_libexecdir}/cpupower
%{_unitdir}/cpupower.service
%{_datadir}/bash-completion/completions/cpupower
%{_datadir}/locale/*/LC_MESSAGES/cpupower.mo
%{_datadir}/doc/perf-tip/tips.txt
/usr/local/lib/python3.12/dist-packages/perf-0.1.egg-info
/usr/local/lib/python3.12/dist-packages/perf.cpython-312-x86_64-linux-gnu.so

%files tools-libs
%defattr(-,root,root)
%{_libdir}/libcpupower.so.*

%files tools-devel
%defattr(-,root,root)
%{_libdir}/libcpupower.so
%{_includedir}/cpufreq.h
%{_includedir}/cpuidle.h
%{_includedir}/powercap.h
%{_includedir}/perf/perf_dlfilter.h
%endif

# ======================================================================
# Changelog
# ======================================================================
%changelog
* %(date "+%a %b %d %Y") Kernel Builder <builder@localhost> - %{kernel_version}-%{kernel_release}
- Custom kernel build based on mainline %{kernel_version}
- Applied custom patches from common/patches
- Built with configuration from common/config
