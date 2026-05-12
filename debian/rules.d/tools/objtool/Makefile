PROGS = \
	objtool \
	objtool.real-powerpc \
	objtool.real-x86

include $(top_rulesdir)/Makefile.inc

objtool.real-%: objdir = $(CURDIR)/$*
objtool.real-%:
	mkdir -p $*
	$(MAKE_UPSTREAM_FORCE_CROSS) ARCH=$*
	ln -f $*/objtool $@

%: %.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
