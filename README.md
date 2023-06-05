WARNING
-------------------------------------------------------------------------------
This repository includes the intel Linux kernel source code.

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


GPG Signed Releases
-------------------

i) Check if a release tag is GPG-signed or not

if a tag is not signed, when you run ‘git tag -v <tag>’ command, you get the result as:

$ git tag -v lts-v4.19.272-android_t-230316T041640Z
object 7150c8b4efa2baf0bef3a3da3850d29715c6fcbb
type commit
tag lts-v4.19.272-android_t-230316T041640Z
tagger sys_oak sys_oak@intel.com 1679296599 -0700

release Kernel 4.19 for android T Dessert
error: no signature found

You can see ‘error: no signature found’ if the tag is not signed

If the tag is signed - please follow the below steps to get the public key and verify the tag -

ii) Download public key

Open https://keys.openpgp.org/, input Full Key ID (i.e., EB4D99E5113E284368955757F18D9D84E60D69E7), or,
short Key ID (i.e., F18D9D84E60D69E7, the Last 16 digitals). or, the tagger email address(i.e., sys_oak@intel.com), 
Click ‘Search’, then you can download the pub key file (i.e., EB4D99E5113E284368955757F18D9D84E60D69E7.asc).
The md5sum checksum is 40b0222665a5f6c70ca9d990b4014f43 for the pub key file:
$ md5sum EB4D99E5113E284368955757F18D9D84E60D69E7.asc 
40b0222665a5f6c70ca9d990b4014f43  EB4D99E5113E284368955757F18D9D84E60D69E7.asc

Once your checksum is correct, please do next step.

iii) Configure your Linux Environment and verify the GPG signature of a tag ( one time setup) 

After you get the right pub key, please import it:
$ gpg --import EB4D99E5113E284368955757F18D9D84E60D69E7.asc

Now, when you check the tag GPG signature, you can see ‘Good signature’ with a WARNING:
$ git tag -v lts-v4.19.282-android_t-230509T073627Z
object 180df1199944ebd8928f320a1bd16c8a87dba2ed
type commit
tag lts-v4.19.282-android_t-230509T073627Z
tagger sys_oak sys_oak@intel.com 1683864457 -0700

release Kernel 4.19 for android T Dessert
gpg: Signature made Fri 12 May 2023 12:07:37 AM EDT
gpg:                using RSA key EB4D99E5113E284368955757F18D9D84E60D69E7
gpg: Good signature from "sys_oak (NSWE) sys_oak@intel.com" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: EB4D 99E5 113E 2843 6895  5757 F18D 9D84 E60D 69E7

To deal with the WARNING, let the pub key be trusted, run ‘gpg --edit-key <key>’ to edit it ( one time setup)
$ gpg --edit-key F18D9D84E60D69E7  
input trust
input 5
input y
input quit

Now, when you check the tag GPG signature again , you can see ‘Good signature’ without warnings: 
$ git tag -v lts-v4.19.282-android_t-230509T073627Z
object 180df1199944ebd8928f320a1bd16c8a87dba2ed
type commit
tag lts-v4.19.282-android_t-230509T073627Z
tagger sys_oak sys_oak@intel.com 1683864457 -0700

release Kernel 4.19 for android T Dessert
gpg: Signature made Fri 12 May 2023 12:07:37 AM EDT
gpg:                using RSA key EB4D99E5113E284368955757F18D9D84E60D69E7
gpg: Good signature from "sys_oak (NSWE) sys_oak@intel.com" [ultimate]
