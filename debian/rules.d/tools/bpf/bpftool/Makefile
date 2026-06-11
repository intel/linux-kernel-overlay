include $(top_rulesdir)/Makefile.inc

# dynamically linking with libbfd is not allowed in Debian
MAKE_UPSTREAM += feature-libbfd=0 feature-libbfd-liberty=0 feature-libbfd-liberty-z=0

all:
	$(MAKE_UPSTREAM)
ifeq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	$(MAKE_UPSTREAM) doc
endif
# Check that bpftool wasn't linked with libbfd
	type ldd
	! ldd $(CURDIR)/bpftool | grep -E '\blibbfd'

install:
	$(MAKE_UPSTREAM) install
ifeq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	$(MAKE_UPSTREAM) doc-install
endif
# Rename bpftool to bpftool-intel
	@if [ -f $(DESTDIR)/usr/sbin/bpftool ]; then mv $(DESTDIR)/usr/sbin/bpftool $(DESTDIR)/usr/sbin/bpftool-intel; fi
# Rename bash completion
	@if [ -f $(DESTDIR)/usr/share/bash-completion/completions/bpftool ]; then \
		mv $(DESTDIR)/usr/share/bash-completion/completions/bpftool $(DESTDIR)/usr/share/bash-completion/completions/bpftool-intel; \
	fi
# Rename man pages
	@if [ -d $(DESTDIR)/usr/share/man ]; then \
		find $(DESTDIR)/usr/share/man -name 'bpftool*.8' | while read f; do \
			dir=$$(dirname "$$f"); \
			base=$$(basename "$$f"); \
			newbase=$$(echo "$$base" | sed 's/^bpftool/bpftool-intel/'); \
			mv "$$f" "$$dir/$$newbase"; \
		done; \
	fi
