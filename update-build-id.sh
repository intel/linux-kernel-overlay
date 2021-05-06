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

BUILD_ID=
SPEC_FILE="SPECS/iotg-kernel.spec"
WORKDIR=$(dirname $(realpath $0))

usage() {
    cat <<-EOF
    
    usage: ${0##*/}  [OPTION]... [VALUE]...

    OPTIONS:
    -b <build-id>     ID of this build.
    -h                Help.

EOF
}

if [[ $# == 0 ]]; then
  usage
  exit 1
fi

while getopts k:t:b:nh opt
do
    case "$opt" in
      b)  BUILD_ID=$OPTARG;;
      h)  usage
          exit 0
          ;;
      *)  usage
          exit 1
          ;;
    esac
done

echo "######################   iotg-next   ######################"
echo Set build id \(pkgrelease\) to $BUILD_ID


# Just one *.spec file per package
if [ ! -f ${WORKDIR}/${SPEC_FILE} ]; then
  echo "Failed. ${SPEC_FILE} no such file"
fi

# Set the pkrelease
sed -i "/define pkgrelease/c %define pkgrelease  ${BUILD_ID}" ${SPEC_FILE}

