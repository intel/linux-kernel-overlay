include $(top_rulesdir)/Makefile.inc

MAKE_UPSTREAM += CPUFREQ_BENCH=false V=true
MAKE_UPSTREAM += DEBUG=$(if $(filter noopt,$(DEB_BUILD_OPTIONS)),true,)
MAKE_UPSTREAM += CROSS='$(CROSS_COMPILE)'
MAKE_UPSTREAM += PACKAGE_BUGREPORT='Debian\ \(reportbug\ linux-intel-cpupower\)'

all:
	$(MAKE_UPSTREAM)

install:
# Force serial install: upstream's install-man/install-gmo/install-tools run
# as parallel prerequisites and race on creating shared ancestor dirs (e.g.
# usr/share), which intermittently fails with "cannot create directory".
	$(MAKE_UPSTREAM) -j1 install
ifneq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	rm -rf $(DESTDIR)/usr/share/man
endif
