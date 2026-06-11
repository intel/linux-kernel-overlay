srcdir := $(top_srcdir)/tools/usb/usbip

# Make sure we don't override top_srcdir in the sub-make.  'unexport
# top_srcdir' is *not* sufficient; nor is adding 'MAKEFLAGS=' to the
# sub-make command line.
unexport MAKEFLAGS

all: export CFLAGS := $(shell dpkg-buildflags --get CFLAGS)
all: export CPPFLAGS := $(shell dpkg-buildflags --get CPPFLAGS) \
	-isystem $(top_srcdir)/debian/build/build-tools/include
all: export LDFLAGS := $(shell dpkg-buildflags --get LDFLAGS)
all:
	rsync -a $(srcdir)/ .
	./autogen.sh
	./configure \
		--prefix=/usr \
		--with-tcp-wrappers \
		--with-usbids-dir=/usr/share/misc \
		--disable-shared \
		--disable-static \
		--host=$(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)
	$(MAKE) V=1

install:
	$(MAKE) V=1 install
ifneq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	rm -rf $(DESTDIR)/usr/share/man
endif
# Rename binaries to add -intel suffix
	@if [ -f $(DESTDIR)/usr/sbin/usbip ]; then mv $(DESTDIR)/usr/sbin/usbip $(DESTDIR)/usr/sbin/usbip-intel; fi
	@if [ -f $(DESTDIR)/usr/sbin/usbipd ]; then mv $(DESTDIR)/usr/sbin/usbipd $(DESTDIR)/usr/sbin/usbipd-intel; fi
# Rename man pages
	@if [ -d $(DESTDIR)/usr/share/man ]; then \
		find $(DESTDIR)/usr/share/man -name 'usbip*.8' | while read f; do \
			dir=$$(dirname "$$f"); \
			base=$$(basename "$$f"); \
			newbase=$$(echo "$$base" | sed 's/^usbip\.8/usbip-intel.8/; s/^usbipd\.8/usbipd-intel.8/'); \
			mv "$$f" "$$dir/$$newbase"; \
		done; \
	fi
