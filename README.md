Overview
-------------------------------------------------------------------------------
This is the IoTG Linux kernel overlay repository (Ubuntu). It includes the Out-Of-Tree(OOT) IoTG
Linux kernel patches, kernel config and other files. With them, user can build the Linux
kernel .deb packages.

Content
-------------------------------------------------------------------------------
This repository include the content which are used to build the debian binary 
packages, below are the detailed information. 

	├── build.sh  # Script to build the Debian package
	├── config.sh # the configurations of the overlay
	├── kernel-config  
	│   ├── base-os		# Ubuntu kernel config
	│   │   └── hirsute.config-5.11.0-16-generic
	│   ├── features 	# Intel kernel features configs
	│   │   └── features.cfg
	│   └── overlay
	│       └── overlay.cfg	# Overlay kernel config
	├── kernel-patches	# Intel Out-Of-Tree kernel patches.
	│   └── patches
	│       └── series
	└── README.md

Kernel configs
-------------------------------------------------------------------------------
In the kernel overlay, we maintain three-level kernel configurations. 

	- base-os(ubuntu), 
	- features (the .cfg file in kernel-config/features directory)
	- kernel-config/overlay/overlay.cfg

When build the debian package by build.sh, the features config overrite the 
base-os kernel config, and overlay.cfg overwrites both the features and base-os 
kernel config.  

The "overwrite" is operated by ./scripts/kconfig/merge_config.sh. 

How to build the iotg linux kernel overlay
-------------------------------------------------------------------------------
To build the debian package, just run the build.sh script, and it will generate 
the debian package in the current directory.

Depedency
-------------------------------------------------------------------------------
sudo apt-get install kernel-wedge

SUPPORT
-------------------------------------------------------------------------------
IOTG Linux Kernel Team
