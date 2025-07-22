# Overview
This is the Linux kernel overlay repository to support the Intel products.
And it is expected to help users generate the Linux kernel binary kernel
image for Edge Microvisor Toolkit (EMT) quickly.

# What is in the repository

## The kernel patch
In the kernel-patches directory, there are the Linux kernel patches which have
not been upstreamed to Linux kernel community. We use the quilt tool to manage
them and they can be applied to the community kernel automatically.

## kernel configs
In the kernel-config directory, there are three-level kernel configurations.

	- base-os(ubuntu),
	- features (the .cfg file in kernel-config/features directory)
	- emt (the .cfg files in kernel-config/emt directory)
	- kernel-config/overlay/overlay.cfg

The overlay.cfg overwrites the emt configs and also the features configs (.cfg),
and then they also overwrite base-os kernel config.

## cmd-param
cmd-param file has the kernel command line which is ONLY for the preempt-rt
kernel.

# How it works
Just follows the Fedora/RHEL/CentOS solution to generate .rpm binary image based
on the SPEC file in source directory.


# Notes
This should only be used for platform feature evaluation and not for production
or deployment with commercial Linux distribution.

# Support
baoli.zhang@intel.com
