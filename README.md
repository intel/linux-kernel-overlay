iotg-kernel-overlay
-------------------------------------------------------------------------------
This is the IoTG Linux kernel overlay. it include the Out-Of-Tree(OOT) IoTG 
Linux kernel patches and related kernel configuratoins. With it, user can build
the Linux kernel RPM packages.

How to build the iotg linux kernel overlay
-------------------------------------------------------------------------------
After clone this repository, you can find it has below file structure.
	.
	├── README.md
	├── SOURCES
	│   ├── centos-ca-secureboot.der
	│   ├── centossecureboot001.crt
	│   ├── cpupower.config
	│   ├── cpupower.service
	│   ├── generate_bls_conf.sh
	│   ├── iotg-kernel.spec
	│   ├── Makefile
	│   ├── mod-sign.sh
	│   ├── overlay.config
	│   ├── parallel_xz.sh
	│   ├── process_configs.sh
	│   ├── securebootca.cer
	│   ├── secureboot.cer
	│   └── x509.genkey
	├── SPECS
	│   └── iotg-kernel.spec
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

Then you can get the RPM packages in RPMS directory. 

Normally we prefer you can build it in CentOS environment. Pls. follow below steps if 
you want to do it in Ubuntu. 

Files
-------------------------------------------------------------------------------
iotg-kernel.spec 
x509.genkey: Used to create the public key which are used to verify the signed kernel & modules.
...

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

Reference
-------------------------------------------------------------------------------
https://www.cnblogs.com/michael-xiang/p/10480809.html

https://docs.fedoraproject.org/en-US/Fedora_Draft_Documentation/0.1/html/RPM_Guide/ch10s04.html

https://rpm-packaging-guide.github.io/#_references

SUPPORT
-------------------------------------------------------------------------------
IOTG Linux Kernel Team
