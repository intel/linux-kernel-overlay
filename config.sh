#!/bin/bash -x
# Global configurations which are used to build kernel overlay

KVERSION=6
KPATCHLEVEL=18
KSUBLEVEL=0
KEXTRAVERSION=
KRTV=

KSRC_MIRROR=


KCFG_BASE_OS="base-os/noble.config-6.8.0-31-generic"
KCFG_FEATURES_DIR="features/"
KCFG_RT="rt/rt.cfg"

KSRC_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux
