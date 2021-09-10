WARNING
-------------------------------------------------------------------------------
This repository includes the intel embargoed Linux kernel source code and confidential
information, Pls. following related intel policy when you distribute it.

Overview
-------------------------------------------------------------------------------
This is the IoTG Linux kernel overlay repository (Ubuntu, RT). It includes the Out-Of-Tree(OOT) IoTG
Linux kernel patches, kernel config and other files. With them, user can build the Linux
kernel .deb packages.

Content
-------------------------------------------------------------------------------
This repository include the content which are used to build the debian binary 
packages, below are the detailed information. 

	.
	├── build.sh			# Script to trigger the build
	├── debian
	│   └── changelog	        # Linux kernel changelog
	├── kernel			# Linux kernel source code as submodue
	├── kernel.overlay		
	│   └── patches	        	# Linux OOT kernel patches
	├── overlay.config		# Linux kernel config
	└── README.md			# Readme file

How to build the iotg linux kernel overlay
-------------------------------------------------------------------------------
To build the debian package, just run the build.sh script, and it will generate the debian
package in the current directory.

Depedency
-------------------------------------------------------------------------------
sudo apt-get install kernel-wedge

SUPPORT
-------------------------------------------------------------------------------
IOTG Linux Kernel Team
