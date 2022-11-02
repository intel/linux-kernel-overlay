#!/bin/bash -x
# Global configurations which are used to build kernel overlay

KVERSION=6
KPATCHLEVEL=1
KSUBLEVEL=0
KEXTRAVERSION=-rc3
KRTV=

KSRC_MIRROR=


KCFG_BASE_OS="base-os/hirsute.config-5.11.0-16-generic"
KCFG_FEATURES_DIR="features/"
KCFG_OVERLAY="overlay/overlay.cfg"

KSRC_REPO=https://github.com/torvalds/linux.git
