include $(top_rulesdir)/Makefile.inc

all:
# We do not want a shared library, and the shared library link does
# not include LDFLAGS so blhc will complain about it
	$(MAKE_UPSTREAM) fixdep
	$(MAKE_UPSTREAM) $(objdir)/libthermal_tools.a
