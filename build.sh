#!/bin/bash -x

# Global configurations
KVERSION=5
KPATCHLEVEL=13
KSUBLEVEL=0
KEXTRAVERSION=

KSRC_REPO=https://github.com/torvalds/linux.git

KSRC_TAG=v$KVERSION.$KPATCHLEVEL$KEXTRAVERSION

KSRC_MIRROR=

# Local macros
CUR_DIR=$PWD
DEBIAN_DIR=$CUR_DIR/debian
KSRC_DIR=$CUR_DIR/kernel
KSRC_OVERLAY_DIR=$CUR_DIR/kernel.overlay/

kernel_tag=$1
build_id=$2

if [ -z $build_id ]; then
	build_id=0
fi

if [[ $kernel_tag =~ .*?lts-v.*?Z$ ]]; then
        kernel_p='lts'
elif [[ $kernel_tag =~ .*?mainline-tracking-.*?Z$ ]]; then
        kernel_p='mainline-tracking'
elif [[ $kernel_tag =~ .*?iotg-next-v.*?Z$ ]]; then
        kernel_p='iotg-next'
else
        kernel_p='none'
fi

timestamp=`echo $kernel_tag|awk -F'-' '{print $NF}'`
if [ -z $timestamp ]; then
	timestamp='no_timestamp'
fi

echo "kernel_p=${kernel_p}, timestamp=${timestamp}"

# Clone and apply the debian repository.
echo "Clone the Linux kernel repository to $KSRC_DIR, tag: $KSRC_TAG"
if [ -z "${KSRC_MIRROR}" ] ; then
	echo "kernel mirror is not defined, cloning the code from Linux community..."
	git submodule update --init $KSRC_DIR
	git submodule update --remote $KSRC_DIR
	pushd $KSRC_DIR
	git clean -df
	git reset --hard
	git fetch --tags --verbose
	git checkout $KSRC_TAG
	popd
else
	echo "Use the kernel mirror at $KSRC_MIRROR"
	rsync --delete --exclude .svk --exclude .svn --exclude .git --link-dest=$KSRC_MIRROR -a $KSRC_MIRROR $KSRC_DIR
fi

# Update the kernel overlay patches
echo "Applying the Linux kernel overlay patches (to $KSRC_DIR)"
rm $KSRC_DIR/.pc -rf
rm $KSRC_DIR/patches -rf
cp $KSRC_OVERLAY_DIR/patches  $KSRC_DIR -r

pushd $KSRC_DIR
quilt push -a
res=$(quilt unapplied 2>&1 | head -n1 | awk -F',' '{print $1}')
if [ "$res" = "File series fully applied" ]; then
	echo "##### Patch file series fully applied."
else
	echo "##### The patches has not been fully applied: ${res}."
	exit 1
fi

echo "Updating the kernel config"
cp $CUR_DIR/overlay.config $KSRC_DIR/.config
make olddefconfig

echo "Building the .deb package"
#nice make -j`nproc` bindeb-pkg  LOCALVERSION= KDEB_PKGVERSION=$build_id KERNELRELEASE=`make kernelversion`-${kernel_p}-${timestamp,,}
KERNELRELEASE=`make kernelversion`-${kernel_p}-${timestamp,,}
nice make -j`nproc` bindeb-pkg  LOCALVERSION= KDEB_PKGVERSION=$build_id KERNELRELEASE=`make kernelversion`-${kernel_p}-${timestamp,,} KDEB_SOURCENAME=linux-${KERNELRELEASE}
cp .config $CUR_DIR/kernel.config
popd

ls -lah *.deb

