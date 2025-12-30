#!/bin/bash -e

source config.sh

function usage()
{
	echo "usage: $0 -r {yes/no, yes if build realtime kernel. otherwise no.} -t { linux_kernel_tag } -b { build-id } -c { customized_kver_string }"
}

function setup()
{
	# Setup the kernel source code that need be built.
	if [ -d "$BUILD_DIR" ]; then rm -Rf "$BUILD_DIR"; fi
	git clone --depth 1 --single-branch --branch $KSRC_UPSTREAM_TAG $KSRC_REPO $BUILD_DIR

	pushd "$BUILD_DIR"

	# Cleanup the build environment
	rm -f "$BUILD_DIR"/../*.deb

	# Update the kernel overlay patches
	echo "Applying the Linux kernel overlay patches (to $BUILD_DIR)"
	[ -d "./.pc" ] && rm ./.pc -rf
	[ -d "./patches" ] && rm ./patches -rf
	cp "$KSRC_OOT_PATCHES"/patches "$BUILD_DIR" -r

	quilt push -a
	res=$(quilt unapplied 2>&1 | head -n1 | awk -F',' '{print $1}')
	if [ "$res" = "File series fully applied" ]; then
		echo "##### Patch file series fully applied."

	elif [ "$res" = 'No patches in series' ]; then
		echo "##### No patches in series, continue to build."
	else
		echo "##### The patches has not been fully applied: ${res}."
		exit 1
	fi

	echo "Updating the kernel config"
	cp "$KCFG_BASE_OS" "$BUILD_DIR"/.config
	for cfg_file in "$KCFG_FEATURES_DIR"/*.cfg; do
		if [[ "$cfg_file" == *rt.cfg ]]; then
			if [ "$is_rt" = "yes"  ]; then
				echo merging "$cfg_file"
				./scripts/kconfig/merge_config.sh -m .config "$cfg_file"
			fi
		else
			echo merging "$cfg_file"
			./scripts/kconfig/merge_config.sh -m .config "$cfg_file"
		fi
	done
	./scripts/kconfig/merge_config.sh -m .config "$KCFG_OVERLAY"

	# *** For RT kernel, we need to add some cmdlines to the boot options
	# *** File 1. cmd-params: Before building, you can add the cmdline to this file.
	# *** After the kernel deb package is installed. cmd-params in /boot/;
	if [ "$is_rt" = "yes"  ]; then
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
	fi
	# *** For RT kernel --end

	popd
}

function build()
{
	pushd "$BUILD_DIR"

	echo "Building the .deb package"
	local pkgver
	local localver
	local krelease
	case "$customized_kver_string" in
		mainline*)
			localver="-mlt"
			;;
		iotg-next*)
			localver="-next"
			;;
		lts*)
			localver="-lts"
			;;
	esac
	# KERNELRELEASE: <version>.<patchlevel>
	krelease="${KVERSION}.${KPATCHLEVEL}"
	# PKG NAME: linux-<image|headers>-<kernelrelease><localversion>
	# KDEB_PKGVERSION: <kernel_version>[~rcN]-<timestamp>~<lts|mlt|next>[+cve]
	pkgver="$(make kernelversion | sed 's/-/~/g')"
	pkgver="${pkgver}-${timestamp,,}${localver/-/\~}"
	[[ "$customized_kver_string" == *cve* ]] && pkgver="${pkgver}+cve"
	make olddefconfig
	scripts/config --undefine LOCALVERSION
	nice make -j"$(nproc)" bindeb-pkg \
		LOCALVERSION="${localver}" \
		KERNELRELEASE="${krelease}" \
		KDEB_PKGVERSION="${pkgver}" \
		KDEB_SOURCENAME="${linux_kernel_tag,,}"

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
KCFG_BASE_OS=$cur_dir/kernel-config/$KCFG_BASE_OS
KCFG_FEATURES_DIR=$cur_dir/kernel-config/$KCFG_FEATURES_DIR
KCFG_OVERLAY=$cur_dir/kernel-config/$KCFG_OVERLAY

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
