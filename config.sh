#!/bin/bash -x
# Global configurations which are used to build kernel overlay

# shellcheck disable=SC2034
KVERSION=7
KPATCHLEVEL=1
KSUBLEVEL=0
KEXTRAVERSION=-rc3
KRTV=

KSRC_MIRROR=


KCFG_BASE_OS=base-os/noble.config-6.8.0-31-generic
KCFG_FEATURES_DIR=features
KCFG_RT=rt/rt.cfg

KSRC_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux
