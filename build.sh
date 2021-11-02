#!/bin/bash -x

# Import overlay configurations
source config.sh

iotg_kernel_tag=$1
build_id=$2
customized_kver_string=$3

if [ -z $build_id ]; then
	build_id=0
fi

# Local macros
CUR_DIR=$PWD

# Possible tags: v5.14 v5.14.1 v5.14-rc7 v5.9.1-rt19 v4.19.127-rt55-rebase v5.15-rc5-rt10
if [ -z "${KEXTRAVERSION}" ]; then
        KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL.$KSUBLEVEL$KRTV
else
        KSRC_UPSTREAM_TAG=v$KVERSION.$KPATCHLEVEL$KEXTRAVERSION$KRTV
fi

KSRC_OOT_PATCHES=$CUR_DIR/kernel-patches/
KCFG_BASE_OS=$CUR_DIR/kernel-config/$KCFG_BASE_OS
KCFG_FEATURES_DIR=$CUR_DIR/kernel-config/$KCFG_FEATURES_DIR
KCFG_OVERLAY=$CUR_DIR/kernel-config/$KCFG_OVERLAY

BUILD_DIR=$CUR_DIR/build/linux-kernel-$KSRC_UPSTREAM_TAG
BINARY_DIR=$CUR_DIR/binary

echo "IoTG Kernel tag: $iotg_kernel_tag, build ID: $build_id,  Upstream kernel: $KSRC_UPSTREAM_TAG, out-of-tree patches: $KSRC_OOT_PATCHES"

timestamp=`echo $iotg_kernel_tag|awk -F'-' '{print $NF}'`
if [ -z $timestamp ]; then
	timestamp='000'
fi

echo "customized_kver_string=${customized_kver_string}, timestamp=${timestamp}"

# Setup the kernel source code that need be built.
if [ -d "${BUILD_DIR}" ] && [ -f "$BUILD_DIR/.git/config" ] ; then

	pushd $BUILD_DIR
	git reset --hard
	git clean -df
	git fetch --all
	git fetch --tags --verbose
	git checkout $KSRC_UPSTREAM_TAG
	popd

elif [ -z "${KSRC_MIRROR}" ] ; then

	echo "Mirror is not defined, clone the Linux kernel repository from community to $BUILD_DIR, tag: $KSRC_UPSTREAM_TAG"
	git clone $KSRC_REPO $BUILD_DIR
	pushd $BUILD_DIR
	git fetch --tags --verbose
	git checkout $KSRC_UPSTREAM_TAG
	popd
else

	echo "Use the kernel mirror at $KSRC_MIRROR"
	[ -d $BUILD_DIR ] && mkdir $BUILD_DIR -p
	rsync --delete --exclude .svk --exclude .svn --exclude .git --link-dest=$KSRC_MIRROR -a $KSRC_MIRROR $BUILD_DIR
	pushd $BUILD_DIR
	git status
	git fetch --tags --verbose
	git checkout $KSRC_UPSTREAM_TAG
	popd
fi

# Remove the existing debian packages if there are..
pushd $BUILD_DIR
rm $BUILD_DIR/../*.deb

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
	echo $cfg_file
	./scripts/kconfig/merge_config.sh -m .config $cfg_file
done
./scripts/kconfig/merge_config.sh -m .config $KCFG_OVERLAY

# *** For RT kernel, we need to add some cmdlines to the boot options
# *** File 1. cmd-params: Before building, you can add the cmdline to this file.
# *** After the kernel deb package is installed. cmd-params in /boot/;
if [ $KRTV ] ; then
	cp $CUR_DIR/cmd-params $BUILD_DIR
	cat <<- EOF > insert_script_code
	cp cmd-params "\$tmpdir/boot/cmd-params-\$version"
EOF
	builddeb_path='scripts/package/builddeb'
	insert_line_num=$(grep -n 'cp System.map "$tmpdir/boot/System.map' $builddeb_path| cut -f1 -d:)
	if [ -n "$insert_line_num" ];then
		sed -i "${insert_line_num}r insert_script_code" $builddeb_path
	else
		echo "$0 Error: Not sure that the insertion point of the code segment"
		exit 1
	fi
	rm insert_script_code
fi
# *** For RT kernel --end

# Build the Debian packages.
echo "Building the .deb package"
make olddefconfig
KERNELRELEASE=`make kernelversion`-${customized_kver_string}-${timestamp,,}
# KDEB_PKTVERSION has to start with digit, then we removed the first character (v) from KSRC_UPSTREAM_TAG
nice make -j`nproc` bindeb-pkg LOCALVERSION= KDEB_PKGVERSION=${KSRC_UPSTREAM_TAG:1}-$build_id KERNELRELEASE=`make kernelversion`-${customized_kver_string}-${timestamp,,} KDEB_SOURCENAME=linux-${KERNELRELEASE}

# Post-build action: move the config and deb package to CUR_DIR
cp .config $CUR_DIR/kernel.config
ls -lah ../*.deb

count=`ls -1 ../*.deb 2>/dev/null | wc -l`
if [ $count != 0 ]; then
	mv ../*.deb $CUR_DIR/
fi

popd
