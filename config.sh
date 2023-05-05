#!/bin/bash -x
# Global configurations which are used to build kernel overlay

KVERSION=6
KPATCHLEVEL=1
KSUBLEVEL=26
KEXTRAVERSION=
KRTV=-rt8

KSRC_MIRROR=


KCFG_BASE_OS="base-os/hirsute.config-5.11.0-16-generic"
KCFG_FEATURES_DIR="features/"
KCFG_OVERLAY="overlay/overlay.cfg"

KSRC_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/rt/linux-stable-rt.git
