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
# Rename rtla to rtla-intel
	@if [ -f $(DESTDIR)/usr/bin/rtla ]; then mv $(DESTDIR)/usr/bin/rtla $(DESTDIR)/usr/bin/rtla-intel; fi
# Rename man pages and update .links file references
	@if [ -d $(DESTDIR)/usr/share/man ]; then \
		find $(DESTDIR)/usr/share/man -name 'rtla*.1' -o -name 'hwnoise.1' -o -name 'osnoise.1' -o -name 'timerlat.1' | while read f; do \
			dir=$$(dirname "$$f"); \
			base=$$(basename "$$f"); \
			newbase=$$(echo "$$base" | sed 's/^rtla-/rtla-intel-/; s/^rtla\.1/rtla-intel.1/'); \
			[ "$$base" != "$$newbase" ] && mv "$$f" "$$dir/$$newbase" || true; \
		done; \
	fi
