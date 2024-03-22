#!/bin/bash -x
# Global configurations which are used to build kernel overlay

KVERSION=6
KPATCHLEVEL=1
KSUBLEVEL=80
KEXTRAVERSION=
KRTV=

KSRC_MIRROR=


KCFG_BASE_OS="base-os/jammy.config-5.15.0-46-generic"
KCFG_FEATURES_DIR="features/"
KCFG_OVERLAY="overlay/overlay.cfg"

KSRC_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/
