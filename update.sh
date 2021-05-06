#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -e

UPSTREAM_URL=https://emb-overlay-koji.ostc.intel.com/tarball/kernel-next/
KOJI_CLIENT_CRT="${HOME}/.koji/client.crt"
CURL_ARGS="--http1.1"
ISRC=1

KERNEL_JSON_URL=https://www.kernel.org/releases.json

echo "######################   kernel-next   ######################"

MY_PATH=$(dirname $(realpath $0))

if [ -e ${MY_PATH}/noupdate ]
then
    echo "*** noupdate *** file found."
    exit
fi

# Get kernel json file
KJSON=$(mktemp)
if ! curl --fail --silent -o ${KJSON} ${KERNEL_JSON_URL}
then
    echo "Fail to download kernel json"
    rm ${KJSON}
    exit 1
fi

KFULL_VERSION=$(jq -r '.releases[] | select(.moniker=="mainline").version' ${KJSON})

# we do not need more the json file
rm ${KJSON}

KVERSION=${KFULL_VERSION%-*}
KRC=".${KFULL_VERSION#*-}"

# Check if the kernel is not a RC
if [ ".${KVERSION}" == "${KRC}" ]
then
    KRC=""
    ISRC=0
fi

# Just one *.spec file per package
SPEC_FILE=$(ls ${MY_PATH}/*.spec)

parse_tag ()
{
    KVERSION=$2
    KRC="${3}."
    KDATE="$4.$5.$6"
    KDATE_MMDD="$5$6"
    if  [ "${KRC:0:2}" != "rc" ]
    then
        KRC="norc"
        KDATE="$3.$4.$5"
        KDATE_MMDD="$4$5"
    fi
}

if [ -e ${KOJI_CLIENT_CRT} ]
then
    CURL_ARGS+=" --cert ${KOJI_CLIENT_CRT}"
fi

if [ ${ISRC} -eq 1 ]
then
    TARBALL=$(curl --silent ${CURL_ARGS} ${UPSTREAM_URL} | grep intel \
            | cut -f 2 -d \" | sort --sort=version | tail -n 1)
else
    TARBALL=$(curl --silent ${CURL_ARGS} ${UPSTREAM_URL} | grep intel \
            | cut -f 2 -d \" | grep -v rc | sort --sort=version | tail -n 1)
fi

TAG=${TARBALL%*.tar.gz}
KVERSION=""
KRC=""
KDATE=""
KDATE_MMDD=""

# parse tag replacing "-" with "<space>"
parse_tag ${TAG//-/\ }

# Be sure we are at latest commit
git  -C ${MY_PATH} pull

if grep --quiet "${KDATE}" ${SPEC_FILE}
then
    echo "No updates on date"
    exit
fi

# Set the pkrelease
sed -i "/define pkgrelease/c %define pkgrelease  1" ${SPEC_FILE}
# Set the rpmversion plus .0
sed -i "/define rpmversion/c %define rpmversion  ${KVERSION}.0" ${SPEC_FILE}
# Set the rc version
sed -i "/define rcversion/c %define rcversion   ${KRC}" ${SPEC_FILE}
# Set isrc
sed -i "/global isrc/c %global isrc ${ISRC}" ${SPEC_FILE}
# Set embargo name
sed -i "/define embargoname/c %define embargoname ${KDATE_MMDD}.intel_next" ${SPEC_FILE}
# Set spec release
sed -i "/define specrelease/c %define specrelease %{?rcversion}${KDATE}_%{pkgrelease}%{?dist}" ${SPEC_FILE}
# Set the Source0
sed -i "/Source0:/c Source0: ${UPSTREAM_URL}${TARBALL}" ${SPEC_FILE}

# Update package if there is a change on git repo
if ! git -C ${MY_PATH} diff --no-ext-diff --quiet
then
    CURL_OPTS=${CURL_ARGS} make -C ${MY_PATH} generateupstream
    git  -C ${MY_PATH} commit -a -m "autoupdate to ${TAG}"
    if test -t 1 -a -t 2
    then
        make -C ${MY_PATH} koji-nowait
    else
        # This code runs on Jenkins
        make -C ${MY_PATH} koji
    fi
else
    echo "No updates"
fi
