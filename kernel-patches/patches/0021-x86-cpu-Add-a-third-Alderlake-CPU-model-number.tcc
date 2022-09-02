From 6e2958493080613d75492e165a44213aa8a50ada Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Wed, 8 Dec 2021 12:27:46 -0800
Subject: [PATCH 21/23] x86/cpu: Add a third Alderlake CPU model number

Existing suffix conventions only cover mobile/desktop/server options.
But this isn't any of those. Use "_N" as it matches the Intel naming
convention for this part.

Signed-off-by: Tony Luck <tony.luck@intel.com>
---
 arch/x86/include/asm/intel-family.h | 1 +
 1 file changed, 1 insertion(+)

diff --git a/arch/x86/include/asm/intel-family.h b/arch/x86/include/asm/intel-family.h
index aeb38023a703..d45366fe96fb 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -115,6 +115,7 @@
 #define INTEL_FAM6_RAPTORLAKE_P		0xBA
 #define INTEL_FAM6_RAPTORLAKE_S		0xBF
 
+
 /* "Small Core" Processors (Atom) */
 
 #define INTEL_FAM6_ATOM_BONNELL		0x1C /* Diamondville, Pineview */
-- 
2.25.1

