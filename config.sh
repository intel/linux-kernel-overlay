#!/bin/bash -x
# Global configurations which are used to build kernel overlay

# shellcheck disable=SC2034
KVERSION=7
KPATCHLEVEL=0
KSUBLEVEL=0
KEXTRAVERSION=
KRTV=

KSRC_MIRROR=

# NOTE: Kernel config merging is now handled by kernel-config/merge.sh and kernel-config/conf.sh
# The merge branch and overlay variant (default, deb) are passed explicitly from build.sh
# To customize base/features/rt configs, edit kernel-config/conf.sh

KSRC_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux
