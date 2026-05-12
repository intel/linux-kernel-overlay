PROGS = tmon

installdir = /usr/bin

include $(top_rulesdir)/Makefile.inc

# tmon does not support OOT build, so we copy the source before
# building.  Use the make -I option to allow it to include other
# Makefiles in the source tree.
# tmon expects us to set INSTALL_ROOT instead of DESTDIR (?!).
real_srcdir := $(srcdir)
srcdir := $(objdir)
MAKE_UPSTREAM += -I $(real_srcdir) INSTALL_ROOT=$(DESTDIR)
$(PROGS):
	rsync -a $(real_srcdir)/ .
	$(MAKE_UPSTREAM)
