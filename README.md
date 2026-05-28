# Overview
This is the Linux kernel overlay repository to support the Intel products.
And it is expected to help users generate the binary kernel image quickly.

# What is in the repository

## The kernel patch
In the kernel-patches directory, there are the Linux kernel patches which have
not been upstreamed to Linux kernel community. We use the quilt tool to manage 
them and they can be applied to the community kernel automatically.

## kernel configs
In the kernel-config directory, there are three-level kernel configurations.

	- base-os(ubuntu), 
	- features (the .cfg file in kernel-config/features directory)
	- rt/rt.cfg

The rt.cfg overwrites the features configs (.cfg), and then they also
overwrite base-os kernel config.

## cmd-param
cmd-param file has the kernel command line which is ONLY for the preempt-rt
kernel. 

## shell scripts
build.sh is provided to compile the kernel image. normally user only need run
it in Ubuntu OS to get the .deb image. In config.sh, there are configurations
for this release.

# System Requirements

## File Descriptor Limit
The build process applies a large number of kernel patches using quilt, which may 
hit the default system file descriptor limit. The build script will automatically 
attempt to raise the soft limit to 65536 (capped by the hard limit) on a best-effort 
basis without failing the build.

If you encounter "Too many open files" errors, you can manually increase the limit:

	# Check current limit
	ulimit -n

	# Temporarily increase for current shell session
	ulimit -n 65536

	# Permanently increase (add to /etc/security/limits.conf)
	echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
	echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

After modifying limits.conf, log out and log back in for changes to take effect.

# How it works
Run the build.sh script, and it will generate the debian package.

usage:

	./build.sh -r {yes/no, yes if build realtime kernel. otherwise no.}
		   -t { linux_kernel_tag }
		   -b { build-id }
		   -c { customized_kver_string }

Build non-rt kenrel:

	./build.sh -r no

built rt kernel:

	./build.sh -r yes

notes, the default value of -r is no. that means ./build.sh (without -r) would
generate the non-rt binary kernel.

In case you want to add the other meaningful words into the image name, Pls.
use -c parameters. for example: 
	
	./build.sh -c my-rt-build

-t and -b can be used to add tag and build-id information into the name string
of binary kernel image. 

We normally have below commands to build the non-rt and rt .deb image:

	./build.sh -r no  -t 20250501-b 1
	./build.sh -r yes -t 20250501-b 2

# Notes
This should only be used for platform feature evaluation and not for production 
or deployment with commercial Linux distribution.

# Support
baoli.zhang@intel.com
