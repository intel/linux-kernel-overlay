#!/bin/bash -e

# Increase file descriptor limit for quilt patch application
# Large patch sets can hit the default system limit
# Best-effort: raise soft limit up to 65536, capped by hard limit
current_soft=$(ulimit -Sn 2>/dev/null || echo "unlimited")
current_hard=$(ulimit -Hn 2>/dev/null || echo "unlimited")
target=65536

# Handle "unlimited" or non-numeric soft limit - nothing to do
if [ "$current_soft" = "unlimited" ] || ! [[ "$current_soft" =~ ^[0-9]+$ ]]; then
    : # Soft limit already unlimited or invalid, skip adjustment
elif [ "$current_soft" -lt "$target" ]; then
    # Soft limit is numeric and below target, try to raise it
    if [ "$current_hard" = "unlimited" ]; then
        ulimit -Sn "$target" 2>/dev/null || true
    elif [[ "$current_hard" =~ ^[0-9]+$ ]] && [ "$current_hard" -ge "$target" ]; then
        ulimit -Sn "$target" 2>/dev/null || true
    elif [[ "$current_hard" =~ ^[0-9]+$ ]]; then
        ulimit -Sn "$current_hard" 2>/dev/null || true
    fi
fi

source config.sh

function usage()
{
	echo "usage: $0 -r {yes/no, yes if build realtime kernel. otherwise no.} -t { linux_kernel_tag } -b { build-id } -c { customized_kver_string }"
}

function setup()
{
	# Setup the kernel source code that need be built.
	# Safety check: ensure BUILD_DIR is set and not a critical path
	if [ -z "$BUILD_DIR" ]; then
		echo "Error: BUILD_DIR is not set" >&2
		exit 1
	fi
	if [ "$BUILD_DIR" = "/" ] || [ "$BUILD_DIR" = "$HOME" ] ||
	   [ "$BUILD_DIR" = "$cur_dir" ]; then
		echo "Error: BUILD_DIR points to a critical directory: $BUILD_DIR" >&2
		exit 1
	fi
	if [ -d "$BUILD_DIR" ]; then
		rm -rf "$BUILD_DIR"
	fi
	git clone --depth 1 --single-branch --branch "$KSRC_UPSTREAM_TAG" "$KSRC_REPO" "$BUILD_DIR"

	pushd "$BUILD_DIR"

	# Cleanup the build environment
	rm -f "$BUILD_DIR"/../*.deb

	# Update the kernel overlay patches
	echo "Applying the Linux kernel overlay patches (to $BUILD_DIR)"
	[ -d "./.pc" ] && rm ./.pc -rf
	git update-index --refresh
	git quiltimport --patches "$KSRC_OOT_PATCHES"/patches

	echo "Updating the kernel config"
	# Use kernel-config/merge.sh to handle config merging
	# Pass merge branch (default) and overlay variant (deb) explicitly
	if [ "$is_rt" = "yes"  ]; then
		"$cur_dir"/kernel-config/merge.sh -r -p "$BUILD_DIR" default deb

		# *** For RT kernel, add rt cmdlines to the boot options.
		# *** File 1. cmd-params: Before building, you can add the cmdline to this file.
		# *** After the kernel deb package is installed. cmd-params in /boot/;
		cp "$cur_dir"/cmd-params "$BUILD_DIR"
		cat <<- EOF > insert_script_code
	        cp cmd-params "\${pdir}/boot/cmd-params-\${KERNELRELEASE}"
EOF
		builddeb_path='scripts/package/builddeb'
		insert_line_num=$(grep -n 'cp System.map "${pdir}/boot/System.map' $builddeb_path| cut -f1 -d:)
	        if [ -n "$insert_line_num" ];then
			sed -i "${insert_line_num}r insert_script_code" $builddeb_path
		else
			echo "$0 Error: Not sure that the insertion point of the code segment"
			exit 1
		fi
		rm insert_script_code
	else
		"$cur_dir"/kernel-config/merge.sh -p "$BUILD_DIR" default deb
	fi

	popd
}

function build()
{
	pushd "$BUILD_DIR"

	echo "Building the .deb package"
	local pkgver
	local krelease
	local kver
	local reltag
	kver="$(make kernelversion)"
	reltag="${linux_kernel_tag#sandbox-}"
	reltag="${reltag,,}"
	# PKG NAME: linux-<image|headers>-<kernel_version>-<staging_tag>[+rt][+cve]
	# KDEB_PKGVERSION: <kernel_version>[~rcN]-<timestamp>-<build_id>
	krelease="${kver}-${reltag}"
	pkgver="${kver//-/\~}-${timestamp,,}-${build_id}"
	[ "$is_rt" = "yes" ] && krelease="${krelease}+rt"
	[[ "$customized_kver_string" = *cve* ]] && krelease="${krelease}+cve"
	make olddefconfig
	nice make -j"$(nproc)" bindeb-pkg \
		LOCALVERSION="" \
		KERNELRELEASE="${krelease}" \
		KDEB_PKGVERSION="${pkgver}" \
		KDEB_SOURCENAME="${reltag}"

	# Post-build action: move the config and deb package to cur_dir
	cp .config "$cur_dir"/kernel.config
	ls -lah ../*.deb

	count=$(find ../*.deb 2>/dev/null | wc -l)
	if [ "$count" != 0 ]; then
		mv ../*.deb "$cur_dir"/
	fi

	popd
}

build_id=0
is_rt=no
linux_kernel_tag=
customized_kver_string=

while getopts "r:t:b:c:h" opt; do
  case $opt in
    r)
      is_rt="$OPTARG"
      ;;
    t)
      linux_kernel_tag="$OPTARG"
      ;;
    b)
      build_id="$OPTARG"
      ;;
    h)
      usage
      exit 0
      ;;
    c)
      customized_kver_string="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

# Local macros
cur_dir=$PWD
KSRC_OOT_PATCHES=$cur_dir/kernel-patches/

# Avoid the illegal value of is_rt, and set customized_kver_string if it's empty.
if [ "$is_rt" == "yes" ]; then
	[ -z "$customized_kver_string" ] && customized_kver_string="rt"
elif [ "$is_rt" == "no" ]; then
	[ -z "$customized_kver_string" ] && customized_kver_string="nonrt"
else
	echo "Incorrect parameter for -r, it must be yes or no."
	exit 1
fi

# Possible tags: v5.14 v5.14.1 v5.14-rc7 v5.9.1-rt19 v4.19.127-rt55-rebase v5.15-rc5-rt10
if [ -n "${KEXTRAVERSION}" ]; then
	KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL$KEXTRAVERSION$KRTV
elif [ "${KSUBLEVEL}" = 0 ]; then
	KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL$KEXTRAVERSION$KRTV
else
	KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL.$KSUBLEVEL$KRTV
fi

BUILD_DIR=$cur_dir/build/linux-kernel-$KSRC_UPSTREAM_TAG

echo "Intel Linux kernel tag: $linux_kernel_tag, build ID: $build_id,  Upstream kernel: $KSRC_UPSTREAM_TAG, out-of-tree patches: $KSRC_OOT_PATCHES, Enable real-time kernel config: $is_rt"

timestamp=$(echo "$linux_kernel_tag"|awk -F'-' '{print $NF}')
if [ -z "$timestamp" ]; then
	timestamp='000'
fi

echo "customized_kver_string=${customized_kver_string}, timestamp=${timestamp}"

setup
build
