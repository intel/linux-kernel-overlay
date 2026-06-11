include $(top_rulesdir)/Makefile.inc

MAKE_UPSTREAM += CPUFREQ_BENCH=false V=true
MAKE_UPSTREAM += DEBUG=$(if $(filter noopt,$(DEB_BUILD_OPTIONS)),true,)
MAKE_UPSTREAM += CROSS='$(CROSS_COMPILE)'
MAKE_UPSTREAM += PACKAGE_BUGREPORT='Debian\ \(reportbug\ linux-intel-cpupower\)'

all:
	$(MAKE_UPSTREAM)

install:
	$(MAKE_UPSTREAM) install
ifneq (,$(filter nodoc,$(DEB_BUILD_PROFILES)))
	rm -rf $(DESTDIR)/usr/share/man
endif
# Rename binaries to add -intel suffix
	@if [ -f $(DESTDIR)/usr/bin/cpupower ]; then mv $(DESTDIR)/usr/bin/cpupower $(DESTDIR)/usr/bin/cpupower-intel; fi
	@if [ -f $(DESTDIR)/usr/sbin/cpupower-gui ]; then mv $(DESTDIR)/usr/sbin/cpupower-gui $(DESTDIR)/usr/sbin/cpupower-intel-gui; fi
# Rename x86 power tools
	@if [ -f $(DESTDIR)/usr/sbin/turbostat ]; then mv $(DESTDIR)/usr/sbin/turbostat $(DESTDIR)/usr/sbin/turbostat-intel; fi
	@if [ -f $(DESTDIR)/usr/sbin/x86_energy_perf_policy ]; then mv $(DESTDIR)/usr/sbin/x86_energy_perf_policy $(DESTDIR)/usr/sbin/x86_energy_perf_policy-intel; fi
	@if [ -f $(DESTDIR)/usr/sbin/intel-speed-select ]; then mv $(DESTDIR)/usr/sbin/intel-speed-select $(DESTDIR)/usr/sbin/intel-speed-select-intel; fi
	@if [ -f $(DESTDIR)/usr/sbin/intel_pstate_tracer.py ]; then mv $(DESTDIR)/usr/sbin/intel_pstate_tracer.py $(DESTDIR)/usr/sbin/intel_pstate_tracer-intel.py; fi
# Rename systemd service file
	@if [ -f $(DESTDIR)/usr/lib/systemd/system/cpupower.service ]; then \
		mv $(DESTDIR)/usr/lib/systemd/system/cpupower.service $(DESTDIR)/usr/lib/systemd/system/cpupower-intel.service; \
	fi
# Update service file to reference renamed binary
	@if [ -f $(DESTDIR)/usr/lib/systemd/system/cpupower-intel.service ]; then \
		sed -i 's|/usr/bin/cpupower|/usr/bin/cpupower-intel|g' $(DESTDIR)/usr/lib/systemd/system/cpupower-intel.service; \
		sed -i 's|cpupower\.service|cpupower-intel.service|g' $(DESTDIR)/usr/lib/systemd/system/cpupower-intel.service; \
	fi
# Rename man pages
	@if [ -d $(DESTDIR)/usr/share/man ]; then \
		find $(DESTDIR)/usr/share/man \( -name 'cpupower*.1' -o -name 'cpupower*.8' -o -name 'turbostat*.8' -o -name 'x86_energy*.8' -o -name 'intel-speed-select*.8' \) | while read f; do \
			dir=$$(dirname "$$f"); \
			base=$$(basename "$$f"); \
			newbase=$$(echo "$$base" | sed 's/^cpupower/cpupower-intel/; s/^turbostat/turbostat-intel/; s/^x86_energy_perf_policy/x86_energy_perf_policy-intel/; s/^intel-speed-select/intel-speed-select-intel/'); \
			mv "$$f" "$$dir/$$newbase"; \
		done; \
	fi
