From da1069c42224cead63b76572206828f878325ea8 Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Wed, 8 Dec 2021 12:27:46 -0800
Subject: [PATCH 2/6] x86/cpu: Add a third Alderlake CPU model number

Existing suffix conventions only cover mobile/desktop/server options.
But this isn't any of those. Use "_N" as it matches the Intel naming
convention for this part.

Signed-off-by: Tony Luck <tony.luck@intel.com>
---
 arch/x86/include/asm/intel-family.h | 1 +
 1 file changed, 1 insertion(+)

diff --git a/arch/x86/include/asm/intel-family.h b/arch/x86/include/asm/intel-family.h
index 27158436f322..2827b72eed9e 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -107,6 +107,7 @@
 
 #define INTEL_FAM6_ALDERLAKE		0x97	/* Golden Cove / Gracemont */
 #define INTEL_FAM6_ALDERLAKE_L		0x9A	/* Golden Cove / Gracemont */
+#define INTEL_FAM6_ALDERLAKE_N		0xBE
 
 /* "Small Core" Processors (Atom) */
 
-- 
2.17.1

