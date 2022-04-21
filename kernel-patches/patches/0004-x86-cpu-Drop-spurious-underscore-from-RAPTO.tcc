From 61cbf659aed8ff53f71308771a86ead12cefc8e9 Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Fri, 19 Nov 2021 09:08:32 -0800
Subject: [PATCH 4/6] x86/cpu: Drop spurious underscore from RAPTOR_LAKE
 #define

Convention for all the other "lake" CPUs is all one word.

So s/RAPTOR_LAKE/RAPTORLAKE/

Fixes: fbdb5e8f2926 ("x86/cpu: Add Raptor Lake to Intel family")
Reported-by: Rui Zhang <rui.zhang@intel.com>
Signed-off-by: Tony Luck <tony.luck@intel.com>
Signed-off-by: Dave Hansen <dave.hansen@linux.intel.com>
Link: https://lkml.kernel.org/r/20211119170832.1034220-1-tony.luck@intel.com
---
 arch/x86/include/asm/intel-family.h | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/arch/x86/include/asm/intel-family.h b/arch/x86/include/asm/intel-family.h
index 0e3a9ddaf8eb..2f7b608f3e55 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -109,7 +109,7 @@
 #define INTEL_FAM6_ALDERLAKE_L		0x9A	/* Golden Cove / Gracemont */
 #define INTEL_FAM6_ALDERLAKE_N		0xBE
 
-#define INTEL_FAM6_RAPTOR_LAKE		0xB7
+#define INTEL_FAM6_RAPTORLAKE		0xB7
 
 /* "Small Core" Processors (Atom) */
 
-- 
2.17.1

