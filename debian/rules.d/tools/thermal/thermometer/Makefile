PROGS = thermometer

installdir = /usr/bin

include $(top_rulesdir)/Makefile.inc

# thermometer does not support OOT build, so we copy the
# source before building.
real_srcdir := $(srcdir)
srcdir := $(objdir)
CPPFLAGS += -I$(real_srcdir)/../lib
LDFLAGS += -L$(objdir)/../lib
$(PROGS):
	rsync -a $(real_srcdir)/ .
	$(MAKE_UPSTREAM)
