#!/bin/bash -x
# Global configurations which are used to build kernel overlay

KVERSION=6
KPATCHLEVEL=19
KSUBLEVEL=0
KEXTRAVERSION=-rc3
KRTV=

KSRC_MIRROR=


KCFG_BASE_OS=overlay/base-os/noble.config-6.8.0-31-generic
KCFG_FEATURES_DIR=overlay/features
KCFG_OVERLAY=overlay/overlay/overlay.cfg

KSRC_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux
