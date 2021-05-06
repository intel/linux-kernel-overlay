#!/usr/bin/env bash
set -e

# How to run:  ./build_ikt_kernel_rpm.sh

RPMBUILD_TOPDIR=~/rpmbuild
PASSWORD=YOUR_PASSWORD  # change /bin/sh -> bash needed the sudo permission

# Set the default value of the jenkins build options
SPEC_REPO_DEF='ssh://git@gitlab.devtools.intel.com:29418/baolizha/iotg-kernel-overlay.git'
KERNEL_REPO_DEF='ssh://git@gitlab.devtools.intel.com:29418/linux-kernel-integration/iotg-next.git'
KERNEL_TAG_DEF=${KERNEL_TAG:='iotg-next-v5.11-yocto-210223T032442Z'}
KERNEL_CONFIG_REPO_DEF='ssh://git@gitlab.devtools.intel.com:29418/linux-kernel-integration/kernel-config.git'
KERNEL_CONFIG_TAG_DEF=${KERNEL_CONFIG_TAG:='aa1fdad0'}
EMBARGONAME=$(date +"%m%d").iotg_next
FULLDATE=$(date +"%Y.%m.%d")

# used the default value if jenkins job not set these options
SPEC_REPO=${SPEC_REPO:=${SPEC_REPO_DEF}}
KERNEL_REPO=${KERNEL_REPO:=${KERNEL_REPO_DEF}}
KERNEL_TAG=${KERNEL_TAG:=${KERNEL_TAG_DEF}}
KERNEL_CONFIG_REPO=${KERNEL_CONFIG_REPO:=${KERNEL_CONFIG_REPO_DEF}}
KERNEL_CONFIG_TAG=${KERNEL_CONFIG_TAG:=${KERNEL_CONFIG_TAG_DEF}}
BUILD_ID=${BUILD_ID:='0'}  # BUILD_ID is jenkins job a environment variable


loginfo() {
    echo $(date +"%Y-%m-%d %H:%M:%S >> ")$1
}

# Step1. check if bash is installed
bash_version=$(bash --version || exit 1)
bash_name=$(echo $bash_version | head -n 1 | awk -F',' '{print $1}')
echo $bash_name
if [ "$bash_name" != 'GNU bash' ]; then
  exit 1
fi
# change /bin/sh -> /bin/bash
SHELL=$(ls -l /bin/sh | awk -F'> ' '{print $NF}')
echo $SHELL
if [ "${SHELL}" != "bash" ]; then
  pushd /bin
  loginfo 'change /bin/sh -> /bin/bash'
  echo ${PASSWORD} | sudo -S rm sh
  echo ${PASSWORD} | sudo -S ln -s bash sh
  loginfo $(ls -l /bin/sh)
  popd
fi

# Step2. Clone the kernel source code to get kernel version
loginfo 'Clone the kernel source code and get the kernel version'
kernel_repo_dir=${KERNEL_REPO##*/}
if [[ -d $kernel_repo_dir ]]; then
  pushd $kernel_repo_dir
  git fetch --all
  popd
else
  git clone -b ${KERNEL_TAG} ${KERNEL_REPO} $kernel_repo_dir
fi

pushd $kernel_repo_dir
EXTRAVERSION=$(cat Makefile | grep EXTRAVERSION | head -n 1 | awk -F'= ' "{print $NF}")
if [[ $EXTRAVERSION == *rt* ]]; then
  rc=$(echo $EXTRAVERSION | sed 's/-//')
  isrc=1
else
  rc='norc'
  isrc=0
fi
if [[ -n $EXTRAVERSION ]]; then
  kernel_verison=$(make kernelversion| sed "s/${EXTRAVERSION}//")
else
  kernel_verison=$(make kernelversion)
fi
loginfo "Get the kernel_verision=${kernel_verison} rc=${rc} isrc=${isrc}"
popd

# Step3. check rpmbuild workdir
loginfo 'checking the rpmbuild workdir'
WORKDIRS=(BUILD BUILDROOT RPMS SOURCES SPECS SRPMS)
for dir in ${WORKDIRS[@]}; do
    if [ ! -d "${RPMBUILD_TOPDIR}/${dir}" ]; then
        loginfo "Create the directory ${RPMBUILD_TOPDIR}/${dir}"
        mkdir -p ${RPMBUILD_TOPDIR}/${dir}
    fi
done

# Step4. clone the kernel.spec file and other source file
loginfo 'Clone the kernel.spec file and other source file.'
spec_repo_dir=${SPEC_REPO##*/}
if [[ -d $spec_repo_dir ]]; then
  cd $spec_repo_dir
  git fetch --all
  cd ..
else
  git clone ${SPEC_REPO} $spec_repo_dir
fi

cp ${spec_repo_dir}/* ${RPMBUILD_TOPDIR}/SOURCES
cp ${spec_repo_dir}/iotg-kernel-base.spec ${RPMBUILD_TOPDIR}/SPECS

# define macro
loginfo 'Set the macro in the iotg-kernel.spec file'
pushd ${RPMBUILD_TOPDIR}/SPECS/
  cp iotg-kernel-base.spec iotg-kernel.spec
  sed -i "s/TAG-global-isrc/${isrc}/" iotg-kernel.spec
  sed -i "s/TAG-define-pkgrelease/${BUILD_ID}/" iotg-kernel.spec
  sed -i "s/TAG-define-rpmversion/${kernel_verison}/" iotg-kernel.spec
  sed -i "s/TAG-define-rcversion/${rc}/" iotg-kernel.spec
  sed -i "s/TAG-define-embargoname/${EMBARGONAME}/" iotg-kernel.spec
  sed -i "s/TAG-DATE/${FULLDATE}/" iotg-kernel.spec
  sed -i "s#TAG-global-kernel_repo#'${KERNEL_REPO}'#" iotg-kernel.spec
  sed -i "s/TAG-global-kernel_tag/${KERNEL_TAG}/" iotg-kernel.spec
  sed -i "s#TAG-global-config_repo#${KERNEL_CONFIG_REPO}#" iotg-kernel.spec
  sed -i "s/TAG-global-config_tag/${KERNEL_CONFIG_TAG}/" iotg-kernel.spec
popd

# run rpmbuild
rpmbuild -ba ${RPMBUILD_TOPDIR}/SPECS/iotg-kernel.spec --nodeps --verbose
