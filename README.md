
WARNING:
-------------------------------------------------------------------------------
THIS REPOSITORY INCLUDES THE INTEL EMBARGOED LINUX KERNEL PATCHES AND CONFIDENTIAL
CONFIDENTIAL INFORMATION, PLS. FOLLOWING INTEL POLICIES WHEN YOU DISTRUBUTING IT. 


Overview
-------------------------------------------------------------------------------
This is the IoTG Linux kernel overlay. it include the Out-Of-Tree(OOT) IoTG 
Linux kernel patches and related kernel configuratoins. With it, user can build
the Linux kernel RPM packages.

Content
-------------------------------------------------------------------------------
This repository has source files (certificate file, kernel config, scripts) and 
spec file (iotg-kernel.spec) which are used to build RPM packages. 

Below are the explannation of each files.

.
├── README.md				# Readme file
├── SOURCES	
│   ├── centos-ca-secureboot.der	# CA Certificate for secure boot
│   ├── centossecureboot001.crt		# Key for security boot
│   ├── cpupower.config			# kernel config for cpupower
│   ├── cpupower.service		# cpupower service file
│   ├── generate_bls_conf.sh		# Script for creating boot entry 
│   ├── Makefile			# A simple make file
│   ├── mod-sign.sh		   	# Script for signing kernel modules	
│   ├── overlay.config			# Linux kernel configuration 
│   ├── parallel_xz.sh			# Script for compressing (xz) files	
│   ├── process_configs.sh		# Script for processing kernel config
│   └── x509.genkey		        # Key generation configuration file	
├── SPECS
│   └── iotg-kernel.spec		# SPEC files for building RPM packages
├── update-build-id.sh			# For updating pkgrelease in SPEC file 
└── update.sh				# For updating kernel info in SPEC file


How to build the iotg linux kernel overlay
-------------------------------------------------------------------------------
After clone this repository, you can find it has below file structure.

	.
	├── README.md
	├── SOURCES
	├── SPECS
	├── update-build-id.sh
	└── update.sh

RPM has the similar folder structure as below. 

	./rpmbuild/
	├── BUILD
	├── BUILDROOT
	├── RPMS
	├── SOURCES
	├── SPECS
	└── SRPMS

Pls. copy the files in SOURCES/* into the RPM SOURCES direcotry. And also copy the 
files in SPECS into the RPM SPECS directory. After that. Pls. run below command.

	rpmbuild -ba ./iotg-kernel.spec --nodeps --verbose

This command will build the Linux kernel RPM packages based on the iotg-kernel.spec.
And save the the RPM packages in RPMS directory. 

Normally we prefer you can build it in CentOS environment. Pls. follow below steps if 
you want to do it in Ubuntu. 

Adapt to Ubuntu OS
-------------------------------------------------------------------------------
1. The default shell is /usr/bin/dash, while not /usr/bin/bash. which lead to the failure of pushd/popd command. Pls. change it to /usr/bin/bash.

2. Some dependencies need be install, below are part of the components...

   sudo apt install libpci-dev
   
   sudo apt install libdwarf \ 
		    libunwind-dev \
		    libbfd-dev \ 
		    libnuma-dev \
		    libperl-dev \
		    libpython3.8-dev   
   		    libdw-dev \
		    lzma-dev \
                    lzma \
                    libzstd-dev \
                    gettext \
                    asciidoc

Useful tips
-------------------------------------------------------------------------------
Expand the macros in spec file:
	rpmspec --parse <spec file name>  > parsed-iotg-kernel.spec

Build RPM package:
	rpmbuild -ba ./iotg-kernel.spec --nodeps --verbose

Show what RPM macros are defined on my system:
	rpm --showrc

Install RPM package in RHEL/CentOS:
	rpm -i <RPM package>

Extract RPM package: 
	rpm2cpio <RPM package> | cpio -idmv


SUPPORT
-------------------------------------------------------------------------------
IOTG Linux Kernel Team
