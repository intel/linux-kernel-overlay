include $(top_rulesdir)/Makefile.inc

# Upstream enables LTO by default, but we don't want it.  We need to
# put -fno-lto in the CFLAGS *environment* variable so it comes after
# the -flto option but does not override other necessary options
# appended to CFLAGS by upstream.
MAKE_UPSTREAM_ENV = CFLAGS=-fno-lto

# Use the version of libcpupower that we just built
CPPFLAGS += -I$(top_srcdir)/tools/power/cpupower/lib -I$(top_srcdir)/tools/lib
LDFLAGS += -L$(CURDIR)/../../power/cpupower

all:
	$(MAKE_UPSTREAM)

install:
	$(MAKE_UPSTREAM) install
ifneq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	rm -rf $(DESTDIR)/usr/share/man
endif
