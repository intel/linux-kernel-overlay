iotg-kernel-overlay
-------------------------------------------------------------------------------
This is the IoTG Linux kernel overlay.  

Files
-------------------------------------------------------------------------------
iotg-kernel.spec 
x509.genkey: Used to create the public key which are used to verify the signed kernel & modules.


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

