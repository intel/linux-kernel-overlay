#!/bin/bash

# Global configurations
KVERSION=5
KPATCHLEVEL=13
KSUBLEVEL=0
KEXTRAVERSION=-rc3

KSRC_REPO=https://github.com/torvalds/linux.git
KSRC_TAG=v5.13-rc3

DPKG_REPO=https://salsa.debian.org/kernel-team/linux.git
DPKG_TAG=1c443439e

KSRC_MIRROR=

# Local macros
CUR_DIR=$PWD
DPKG_DIR=$CUR_DIR/dpkg
DPKG_OVERLAY_DIR=$CUR_DIR/dpkg.overlay/
KSRC_DIR=$CUR_DIR/kernel
KSRC_OVERLAY_DIR=$CUR_DIR/kernel.overlay/

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

# Clone and apply the debian repository.
echo "Cloning the debian kernel package to $DPKG_DIR, tag: $DPKG_TAG"
git submodule update --init $DPKG_DIR
git submodule update --remote $DPKG_DIR
pushd $DPKG_DIR
rm * -rf && git reset --hard
git pull
git checkout $DPKG_TAG

# Update the debian overlay patches
echo "Appying the debian overlay patches (to $DPKG_DIR)"
git am $DPKG_OVERLAY_DIR/*.patch
git add debian/rules


# Update the kernel overlay patches
echo "Updating the Linux kernel overlay patches (to $KSRC_DIR)"
rm $DPKG_DIR/debian/patches/* -rf
cp $KSRC_OVERLAY_DIR/patches/* $DPKG_DIR/debian/patches/
git add debian/patches/

git commit -m "Auto applied overlay patches for debian & kernel"  

# Start build
debian/rules kernel

# debian/rules debian/control
fakeroot debian/rules source

fakeroot make -f debian/rules.gen binary-arch_amd64_none_amd64

popd


# fakeroot make -f debian/rules.gen binary-arch_amd64_none_amd64

