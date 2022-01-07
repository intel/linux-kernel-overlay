#!/bin/bash -x
# Global configurations which are used to build kernel overlay

KVERSION=5
KPATCHLEVEL=10
KSUBLEVEL=90
KEXTRAVERSION=
KRTV=-rt60

KSRC_MIRROR=


KCFG_BASE_OS="base-os/hirsute.config-5.11.0-16-generic"
KCFG_FEATURES_DIR="features/"
KCFG_OVERLAY="overlay/overlay.cfg"

KSRC_REPO=https://kernel.googlesource.com/pub/scm/linux/kernel/git/rt/linux-stable-rt.git
