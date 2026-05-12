ifeq ($(filter i386 amd64 x32 arm64,$(DEB_HOST_ARCH)),)

# Build nothing
include $(top_rulesdir)/Makefile.inc

else

PROGS = \
	hv_kvp_daemon \
	hv_vss_daemon

installdir = /usr/sbin

include $(top_rulesdir)/Makefile.inc

install-local: install-hvkvpd-scripts

install-hvkvpd-scripts: installdir = /usr/libexec/hypervkvpd
install-hvkvpd-scripts: hv_get_dhcp_info.sh hv_get_dns_info.sh
	@for p in $^; do \
	  echo " install -D -m755 '$$p' '$(DESTDIR)/$(installdir)/$$(basename $$p .sh)'"; \
	  install -D -m755 \
	    "$$p" "$(DESTDIR)/$(installdir)/$$(basename $$p .sh)"; \
	done

endif
