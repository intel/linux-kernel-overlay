From f78e6021365bda9fb5eb098751a7620731f89392 Mon Sep 17 00:00:00 2001
From: "Herton R. Krzesinski" <herton@redhat.com>
Date: Mon, 4 Apr 2022 18:05:25 -0300
Subject: [PATCH] tools/power/x86/intel-speed-select: fix build failure when
 using -Wl,--as-needed

Build of intel-speed-select will fail if you run:

$ LDFLAGS="-Wl,--as-needed" /usr/bin/make V=1
...
gcc -O2 -Wall -g -D_GNU_SOURCE -Iinclude -I/usr/include/libnl3 -Wl,--as-needed -lnl-genl-3 -lnl-3 intel-speed-select-in.o -o intel-speed-select
/usr/bin/ld: intel-speed-select-in.o: in function `handle_event':
(...)/linux/tools/power/x86/intel-speed-select/hfi-events.c:189: undefined reference to `nlmsg_hdr'
...

In this case the problem is that order when linking matters when using
the flag -Wl,--as-needed, symbols not used at that point are discarded.
So since intel-speed-select-in.o comes after, at that point the
libraries/symbols are already discarded and then missing/undefined
references are reported.

To fix this, make sure we specify LDFLAGS after the object file.

Acked-by: Srinivas Pandruvada <srinivas.pandruvada@linux.intel.com>
Signed-off-by: Herton R. Krzesinski <herton@redhat.com>
Link: https://lore.kernel.org/r/20220404210525.725611-1-herton@redhat.com
Signed-off-by: Hans de Goede <hdegoede@redhat.com>
---
 tools/power/x86/intel-speed-select/Makefile | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/tools/power/x86/intel-speed-select/Makefile b/tools/power/x86/intel-speed-select/Makefile
index 846f785e278d..7221f2f55e8b 100644
--- a/tools/power/x86/intel-speed-select/Makefile
+++ b/tools/power/x86/intel-speed-select/Makefile
@@ -42,7 +42,7 @@ ISST_IN := $(OUTPUT)intel-speed-select-in.o
 $(ISST_IN): prepare FORCE
 	$(Q)$(MAKE) $(build)=intel-speed-select
 $(OUTPUT)intel-speed-select: $(ISST_IN)
-	$(QUIET_LINK)$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@
+	$(QUIET_LINK)$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@
 
 clean:
 	rm -f $(ALL_PROGRAMS)
-- 
2.25.1

