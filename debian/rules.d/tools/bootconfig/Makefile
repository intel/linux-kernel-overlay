include $(top_rulesdir)/Makefile.inc

# Default target (all) includes running tests.  If this is not wanted
# (e.g. for cross-builds), build the bootconfig target instead.
ifeq ($(filter nocheck,$(DEB_BUILD_OPTIONS)),)
BUILD_TARGET := all
else
BUILD_TARGET := $(CURDIR)/bootconfig
endif

all:
	$(MAKE_UPSTREAM) $(BUILD_TARGET)

install:
	mkdir -p $(DESTDIR)/usr/bin
	$(MAKE_UPSTREAM) install
