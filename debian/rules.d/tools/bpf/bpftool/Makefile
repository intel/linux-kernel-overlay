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
