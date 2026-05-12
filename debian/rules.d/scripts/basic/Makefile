PROGS = \
	fixdep.host

include $(top_rulesdir)/Makefile.inc

# We build fixdep as fixdep.host to avoid overwriting the native build
# that Kbuild depends on
fixdep.host: fixdep.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ $<
install-local-progs:
	install -D -m755 fixdep.host $(DESTDIR)/$(installdir)/fixdep
