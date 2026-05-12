# Normalise OUTDIR to avoid triggering rebuilds
override OUTDIR := $(patsubst ./%,%,$(OUTDIR))

VPATH = $(top_rulesdir)/$(OUTDIR) $(top_srcdir)/$(OUTDIR)

SHELL = /bin/sh -e

srcdir := $(top_srcdir)/$(OUTDIR)
objdir := $(CURDIR)

CC = $(CROSS_COMPILE)gcc
CXX = $(CROSS_COMPILE)g++
PKG_CONFIG = $(CROSS_COMPILE)pkg-config
CFLAGS := $(shell dpkg-buildflags --get CFLAGS) -Wall
CPPFLAGS := $(shell dpkg-buildflags --get CPPFLAGS) \
	-I$(srcdir) \
	-I$(top_srcdir)/debian/build/build-tools/$(OUTDIR) \
	-I$(top_srcdir)/scripts/include \
	-isystem $(top_srcdir)/debian/build/build-tools/include
CXXFLAGS := $(shell dpkg-buildflags --get CXXFLAGS) -Wall
LDFLAGS := $(shell dpkg-buildflags --get LDFLAGS)

installdir ?= $(prefix)/$(OUTDIR)

all: all-local all-recursive
install: install-local install-recursive

%-recursive:
	+@list='$(SUBDIRS)'; \
	for subdir in $$list; do \
	  echo "Making $* in $$subdir"; \
	  mkdir -p $$subdir; \
	  $(MAKE) -C $$subdir -f $(top_rulesdir)/$(OUTDIR)/$$subdir/Makefile OUTDIR=$(OUTDIR)/$$subdir $*; \
	done

all-local: $(PROGS) $(KBUILD_PROGS)

install-local: install-local-progs install-local-scripts install-local-data

install-local-progs: $(PROGS) $(KBUILD_PROGS)
	@for p in $^; do \
	  echo " install -m755 '$$p' '$(DESTDIR)/$(installdir)'"; \
	  install -D -m755 "$$p" "$(DESTDIR)/$(installdir)/$$(basename $$p)"; \
	done

SCRIPTS_REAL = $(wildcard $(addprefix $(srcdir)/,$(SCRIPTS)))

install-local-scripts: $(SCRIPTS_REAL)
	@for p in $^; do \
	  echo " install -m755 '$$p' '$(DESTDIR)/$(installdir)'"; \
	  install -D -m755 \
	    -s --strip-program $(top_srcdir)/debian/bin/fix-shebang \
	    "$$p" "$(DESTDIR)/$(installdir)/$$(basename $$p)"; \
	done

DATA_REAL = $(wildcard $(addprefix $(srcdir)/,$(DATA)))

install-local-data: $(DATA_REAL)
	@for p in $^; do \
	  echo " install -m644 '$$p' '$(DESTDIR)/$(installdir)'"; \
	  install -D -m644 "$$p" "$(DESTDIR)/$(installdir)/$$(basename $$p)"; \
	done

# Invoke upstream makefile with common required variables, not
# including architecture and toolchain options
MAKE_UPSTREAM_BASE = +$(MAKE_UPSTREAM_ENV) $(MAKE) -C $(srcdir) \
	prefix=/usr \
	bindir=$(or $(bindir),/usr/bin) \
	libdir=/usr/lib/$(DEB_HOST_MULTIARCH) \
	mandir=/usr/share/man \
	DESTDIR=$(DESTDIR) \
	O=$(objdir) \
	STRIP=true \
	V=1

# Invoke upstream makefile with common required variables
MAKE_UPSTREAM = $(MAKE_UPSTREAM_BASE) \
	ARCH=$(KERNEL_ARCH) \
	CC='$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS)' \
	CXX='$(CXX) $(CXXFLAGS) $(CPPFLAGS) $(LDFLAGS)' \
	LD=$(CROSS_COMPILE)ld \
	PKG_CONFIG='$(PKG_CONFIG)'

MAKE_UPSTREAM_FORCE_CROSS_VARS = \
	HOSTARCH=$(KERNEL_ARCH) \
	HOSTAR=$(CROSS_COMPILE)ar \
	HOSTCC='$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS)' \
	HOSTLD=$(CROSS_COMPILE)ld \
	HOSTPKG_CONFIG=$(CROSS_COMPILE)pkg-config \
	REALHOSTCC=gcc \
	REALHOSTLD=ld

# Invoke upstream makefile with common required variables, forcing
# cross-build of a tool that expects to always be native
MAKE_UPSTREAM_FORCE_CROSS = $(MAKE_UPSTREAM_BASE) \
	$(MAKE_UPSTREAM_FORCE_CROSS_VARS)

ifdef KBUILD_PROGS
# Invoke Kbuild for this directory, forcing cross-build of hostprogs
$(KBUILD_PROGS):
	+$(MAKE) -C $(top_srcdir)/debian/build/build-tools \
		-f $(top_srcdir)/scripts/Makefile.build \
		srcroot=$(top_srcdir) \
		srctree=$(top_srcdir) \
		VPATH=$(top_srcdir) \
		building_out_of_srctree=1 \
		objtree=$(top_srcdir)/debian/build/build-tools \
		obj=$(OUTDIR) \
		KBUILD_VERBOSE=1 \
		$(MAKE_UPSTREAM_FORCE_CROSS_VARS) \
		$(addprefix $(OUTDIR)/,$@)
endif
