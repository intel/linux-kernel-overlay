include $(top_rulesdir)/Makefile.inc

MAKE_UPSTREAM += CPUFREQ_BENCH=false V=true
MAKE_UPSTREAM += DEBUG=$(if $(filter noopt,$(DEB_BUILD_OPTIONS)),true,)
MAKE_UPSTREAM += CROSS='$(CROSS_COMPILE)'
MAKE_UPSTREAM += PACKAGE_BUGREPORT='Debian\ \(reportbug\ linux-cpupower\)'

all:
	$(MAKE_UPSTREAM)

install:
	$(MAKE_UPSTREAM) install
ifneq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	rm -rf $(DESTDIR)/usr/share/man
endif
