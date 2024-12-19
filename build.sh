#!/bin/bash -ex

# Import overlay configurations
source config.sh

function usage()
{
	echo "Four paramaters: is-rt(yes/no), linux kernel tag, build id and customized_kvesion_string"
	echo "usage: $0 -r {is-rt} -t { linux_kernel_tag } -b { build-id } -c { customized_kver_string }"
}

function setup()
{
	# Setup the kernel source code that need be built.
	if [ -d "$BUILD_DIR" ]; then rm -Rf $BUILD_DIR; fi
	git clone --depth 1 --single-branch --branch $KSRC_UPSTREAM_TAG $KSRC_REPO $BUILD_DIR

	pushd $BUILD_DIR

	# Cleanup the build environment
	rm -f $BUILD_DIR/../*.deb

	# Update the kernel overlay patches
	echo "Applying the Linux kernel overlay patches (to $BUILD_DIR)"
	[ -d "./.pc" ] && rm ./.pc -rf
	[ -d "./patches" ] && rm ./patches -rf
	cp $KSRC_OOT_PATCHES/patches  $BUILD_DIR -r

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
	cp $KCFG_BASE_OS $BUILD_DIR/.config
	for cfg_file in $KCFG_FEATURES_DIR/*.cfg; do
		if [[ "$cfg_file" == *rt.cfg ]]; then
			if [ "$is_rt" = "yes"  ]; then
				echo merging $cfg_file
				./scripts/kconfig/merge_config.sh -m .config $cfg_file
			fi
		else
			echo merging $cfg_file
			./scripts/kconfig/merge_config.sh -m .config $cfg_file
		fi
	done
	./scripts/kconfig/merge_config.sh -m .config $KCFG_OVERLAY

	# *** For RT kernel, we need to add some cmdlines to the boot options
	# *** File 1. cmd-params: Before building, you can add the cmdline to this file.
	# *** After the kernel deb package is installed. cmd-params in /boot/;
	if [ "$is_rt" = "yes"  ]; then
		cp $cur_dir/cmd-params $BUILD_DIR
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
	pushd $BUILD_DIR

	echo "Building the .deb package"
	make olddefconfig
	KERNELRELEASE=`make kernelversion`-${customized_kver_string}-${timestamp,,}
	# KDEB_PKTVERSION has to start with digit, then we removed the first character (v) from KSRC_UPSTREAM_TAG
	nice make -j`nproc` bindeb-pkg LOCALVERSION= KDEB_PKGVERSION=${KSRC_UPSTREAM_TAG:1}-$build_id KERNELRELEASE=`make kernelversion`-${customized_kver_string}-${timestamp,,} KDEB_SOURCENAME=linux-${KERNELRELEASE}

	# Post-build action: move the config and deb package to cur_dir
	cp .config $cur_dir/kernel.config
	ls -lah ../*.deb

	count=`ls -1 ../*.deb 2>/dev/null | wc -l`
	if [ $count != 0 ]; then
		mv ../*.deb $cur_dir/
	fi

	popd
}

build_id=0
is_rt=no
linux_kernel_tag=
customized_kver_string=

while getopts "r:t:b:c:" opt; do
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
BINARY_DIR=$cur_dir/binary


# Possible tags: v5.14 v5.14.1 v5.14-rc7 v5.9.1-rt19 v4.19.127-rt55-rebase v5.15-rc5-rt10
if [ -n "${KEXTRAVERSION}" ]; then
	KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL$KEXTRAVERSION$KRTV
elif [ ${KSUBLEVEL} = 0 ]; then
	KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL$KEXTRAVERSION$KRTV
else
	KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL.$KSUBLEVEL$KRTV
fi

BUILD_DIR=$cur_dir/build/linux-kernel-$KSRC_UPSTREAM_TAG

echo "Intel Linux kernel tag: $linux_kernel_tag, build ID: $build_id,  Upstream kernel: $KSRC_UPSTREAM_TAG, out-of-tree patches: $KSRC_OOT_PATCHES, Enable real-time kernel config: $is_build_rt"

timestamp=`echo $linux_kernel_tag|awk -F'-' '{print $NF}'`
if [ -z $timestamp ]; then
	timestamp='000'
fi

echo "customized_kver_string=${customized_kver_string}, timestamp=${timestamp}"

setup
build
