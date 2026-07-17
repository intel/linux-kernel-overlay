include $(top_rulesdir)/Makefile.inc

# gas only understands the -fdebug-prefix-map option, and gcc doesn't
# convert the -ffile-prefix-map option to that when invoking gas.  So
# use both options.
ifneq ($(filter -ffile-prefix-map=%,$(CFLAGS)),)
CFLAGS += -fdebug-prefix-map=$(DEB_BUILD_PATH)=.
endif

MAKE_UPSTREAM += VF=1 WERROR=0

# Disable Gtk UI until it's more usable
MAKE_UPSTREAM += NO_GTK2=1

# Do not build the unversioned jvmti library
MAKE_UPSTREAM += feature-jvmti=0

MAKE_UPSTREAM += perfexecdir=lib/perf-core plugindir=/usr/lib/traceevent/plugins tipdir=share/doc/linux-intel-perf perf_include_dir=include/perf perf_examples_dir=share/doc/linux-intel-perf/examples

# perf can link against libcrypto if available, but the result is
# undistributable as GPL v2 and Apache 2.0 are not compatible without
# an explicit exception.  Override detection of libcrypto.
MAKE_UPSTREAM += NO_LIBCRYPTO=1

# perf only links against libopencsd (coresight) if specifically enabled
MAKE_UPSTREAM += CORESIGHT=1

# Currently babeltrace support for `perf data' is not automatically detected.
MAKE_UPSTREAM += LIBBABELTRACE=1

# Build with asciidoctor, not asciidoc
MAKE_UPSTREAM += USE_ASCIIDOCTOR=1

# Build with Python 3, not Python 2
MAKE_UPSTREAM += PYTHON=/usr/bin/python3

# Ensure the right options are picked up for libperl and libpython
export PERL5LIB=/usr/lib/$(DEB_HOST_MULTIARCH)/perl/cross-config
MAKE_UPSTREAM += PYTHON_CONFIG=$(CROSS_COMPILE)python3-config

# Explicitly set DEBUG=0.  This is the default for perf itself, but
# it's not passed down to libapi and it uses the wrong compiler
# options unless it's explicitly set.
MAKE_UPSTREAM += DEBUG=0

# Disable Rust support, currently only a test case.  The target name
# mapping in Makefile.config is wrong for some Debian architectures
# and not worth fixing just for a test.
MAKE_UPSTREAM += NO_RUST=1

# Pass PERF_VERSION for documentation generation
MAKE_UPSTREAM += PERF_VERSION=$(VERSION)

all:
	$(MAKE_UPSTREAM) -f Makefile.perf all
ifeq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	# Remove --unsafe and -f options from asciidoctor commands (not supported in newer versions)
	sed -i 's/--unsafe\s*//g; s/-f\s*asciidoc\.conf\s*//g' $(srcdir)/Documentation/Makefile
	$(MAKE_UPSTREAM) -C $(srcdir)/Documentation man
endif
# Check that perf didn't get linked against incompatibly-licensed libraries
	@if readelf -d $(CURDIR)/perf | sed -rne 's/.*NEEDED.*\[(.*)\]/\1/p' | grep -E '\blib(bfd|crypto)'; then \
		echo; \
		echo 'perf linked against incompatibly-licensed libraries'; \
		echo; \
		exit 1; \
	fi
# Check that it links against abi::__cxa_demangle from libstdc++
	grep __cxa_demangle $(CURDIR)/perf

install:
# Force serial install: 'install' and 'install-python_ext' are passed as two
# goals to one jobserver-enabled make, and perf's own install fans out into
# parallel prerequisites (install-tools, install-tests, try-install-man) that
# race on creating shared ancestor dirs. Serialize to avoid the intermittent
# "install: cannot create directory" failure (same class as cpupower).
	$(MAKE_UPSTREAM) -j1 -f Makefile.perf install install-python_ext
# Don't install a 'trace' alias yet:
# - We need a wrapper for it anyway, so there's little point adding a
#   versioned link
# - It doesn't work out-of-the-box as non-root (it depends on debugfs),
#   so it's less widely useful than strace
# - 'perf trace' doesn't take much more typing
	rm -f $(DESTDIR)/usr/bin/trace
	mkdir -p $(DESTDIR)/usr/share/bash-completion/
	mv $(DESTDIR)/etc/bash_completion.d \
		$(DESTDIR)/usr/share/bash-completion/completions
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/etc
# Rename perf binary to perf-intel
	@if [ -f $(DESTDIR)/usr/bin/perf ]; then mv $(DESTDIR)/usr/bin/perf $(DESTDIR)/usr/bin/perf-intel; fi
# NOTE: perf-iostat stays as-is because perf binary hardcodes "perf-<subcommand>" pattern
# Rename bash completion
	@if [ -f $(DESTDIR)/usr/share/bash-completion/completions/perf ]; then \
		mv $(DESTDIR)/usr/share/bash-completion/completions/perf $(DESTDIR)/usr/share/bash-completion/completions/perf-intel; \
	fi
# Rename man pages
	@if [ -d $(DESTDIR)/usr/share/man ]; then \
		find $(DESTDIR)/usr/share/man -name 'perf*.1' | while read f; do \
			dir=$$(dirname "$$f"); \
			base=$$(basename "$$f"); \
			newbase=$$(echo "$$base" | sed 's/^perf-/perf-intel-/; s/^perf\.1/perf-intel.1/'); \
			mv "$$f" "$$dir/$$newbase"; \
		done; \
	fi
