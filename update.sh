#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Update the iotg-kernel.spec file based on iotg-next release
# the things that need be updated:
# 1. %global isrc 
# 2. %define pkgrelease  1
# 3. %define rpmversion  5.12.0
# 4. %define rcversion   rc1
# 5. %define embargoname 0513.iotg_next
# 6. %define specrelease %{?rcversion}2021.05.13_%{pkgrelease}%{?dist}
#
# 7. %global kernel_repo ssh://git@gitlab...
# 8. %global kernel_tag  iotg-next-v5.12-yocto-210427T103552Z
# 9. %global kernel_config ssh://git@gitlab...
# 10. %global kernel_config_tag aa1fdad0
# 11. %global kernel_config_file spr/spr-ee-kernel-config

set -e

KSRC_REPO=
KSRC_TAG=
BUILD_ID=
NOT_COMMIT=
ISRC=
KERNEL=
KVERSION=
KRC=
KDATE=
KDATE_MMDD=
KERNEL_FULL_VERSION=
SPEC_FILE="SPECS/iotg-kernel.spec"
BASE_OS_CFG_FILE="base-os/centos.config-4.18.0-348.el8.x86_64"
WORKDIR=$(dirname $(realpath $0))

usage() {
    cat <<-EOF
    
    usage: ${0##*/}  [OPTION]... [VALUE]...

    OPTIONS:
    -k <kernel-repo>  Remote repository of kernel source code.
    -t <kernel-tag>   Tag of the kernel repository.
    -n                Do not add changes to git commit.
    -h                Help.

EOF
}

if [[ $# == 0 ]]; then
  usage
  exit 1
fi

while getopts k:t:c:nh opt
do
    case "$opt" in
      k)  KSRC_REPO=$OPTARG;;
      t)  KSRC_TAG=$OPTARG;;
      c)  BASE_OS_CFG_FILE=$OPTARG;;
      n)  NOT_COMMIT=true;;
      h)  usage
          exit 0
          ;;
      *)  usage
          exit 1
          ;;
    esac
done

echo "######################   iotg-next   ######################"

if [ -e ${WORKDIR}/noupdate ]
then
    echo "*** noupdate *** file found."
    exit
fi

# Just one *.spec file per package
if [ ! -f ${WORKDIR}/${SPEC_FILE} ]; then
  echo "Failed. ${SPEC_FILE} no such file"
fi

parse_tag() {
    # tag example: iotg-next-v5.12-yocto-210427T103552Z
    KTAG=${1##*/}
    KERNEL=$(echo $KTAG | awk -F'-v' '{print $1}')
    _KV=$(echo $KTAG | awk -F'-v' '{print $2}')
    KVERSION=$(echo $_KV | awk -F'-' '{print $1}')
    KRC=$(echo $_KV | awk -F'-' '{print $2}')
    KDATE=$(echo $_KV | awk -F'-' '{print $NF}')
    KDATE_MMDD=${KDATE:2:4}
    ISRC=1
    KERNEL_FULL_VERSION="v${KVERSION}-${KRC}"
    KERNEL=${KERNEL/-/_} # need iotg_next, '-' have special meaning in .spec file
    if [ "${KRC:0:2}" != "rc" ]; then
      ISRC=0
      KRC="norc"
      KERNEL_FULL_VERSION="v${KVERSION}"
    fi

    # Add minor version number to $KVERSION
    if [ $(echo $KVERSION | awk -F'.' '{print NF}') == "2" ]; then
    	KVERSION=${KVERSION}.0
    fi

    echo "Get the KERNEL=${KERNEL}, KVERSION=${KVERSION}, KRC=${KRC}, ISRC=${ISRC},
          KDATE=${KDATE}, KDATE_MMDD=${KDATE_MMDD}"
}

parse_tag $KSRC_TAG

# Set the rpmversion plus .0
sed -i "/define rpmversion/c %define rpmversion  ${KVERSION}" ${SPEC_FILE}
# Set the rc version
sed -i "/define rcversion/c %define rcversion   ${KRC}." ${SPEC_FILE}
# Set isrc
sed -i "/global isrc/c %global isrc ${ISRC}" ${SPEC_FILE}
# Set embargo name
sed -i "/define embargoname/c %define embargoname ${KDATE_MMDD}.${KERNEL}" ${SPEC_FILE}
# Set spec release
sed -i "/define specrelease/c %define specrelease %{?rcversion}${KDATE}_%{pkgrelease}%{?dist}" ${SPEC_FILE}

# Set the kernel src
sed -i "/global kernel_src_repo/c %global kernel_src_repo ${KSRC_REPO}" ${SPEC_FILE}
sed -i "/global kernel_src_tag/c %global kernel_src_tag ${KSRC_TAG}" ${SPEC_FILE}

# Set the kernel configurations of the base operating system.
sed -i "/define base_os_cfg_file/c %define base_os_cfg_file ${BASE_OS_CFG_FILE}" ${SPEC_FILE}

if [ "$NOT_COMMIT" = true ] ; then
    exit 0
fi

# Update package if there is a change on git repo
if ! git -C ${WORKDIR} diff --no-ext-diff --quiet ${SPEC_FILE}
then
    git  -C ${WORKDIR} commit -a -m "Autoupdate to ${KSRC_TAG}"
    echo "No updates"
fi
