From f5ec45061291356f156efccde620949171790b27 Mon Sep 17 00:00:00 2001
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
index 0be13df58526..8e2ab1efb4d3 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -114,6 +114,7 @@
 #define INTEL_FAM6_RAPTORLAKE_P		0xBA
 #define INTEL_FAM6_RAPTORLAKE_S		0XBF
 
+
 /* "Small Core" Processors (Atom) */
 
 #define INTEL_FAM6_ATOM_BONNELL		0x1C /* Diamondville, Pineview */
-- 
2.25.1

