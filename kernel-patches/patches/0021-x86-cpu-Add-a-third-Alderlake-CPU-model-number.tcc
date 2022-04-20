From 1357b1852aee60498af668f08633994d2ad99edc Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Wed, 8 Dec 2021 12:27:46 -0800
Subject: [PATCH 21/23] x86/cpu: Add a third Alderlake CPU model number

Existing suffix conventions only cover mobile/desktop/server options.
But this isn't any of those. Use "_N" as it matches the Intel naming
convention for this part.

Signed-off-by: Tony Luck <tony.luck@intel.com>
---
 arch/x86/include/asm/intel-family.h | 2 ++
 1 file changed, 2 insertions(+)

diff --git a/arch/x86/include/asm/intel-family.h b/arch/x86/include/asm/intel-family.h
index 048b6d5aff50..53aba0a2e349 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -107,9 +107,11 @@
 
 #define INTEL_FAM6_ALDERLAKE		0x97	/* Golden Cove / Gracemont */
 #define INTEL_FAM6_ALDERLAKE_L		0x9A	/* Golden Cove / Gracemont */
+#define INTEL_FAM6_ALDERLAKE_N		0xBE
 
 #define INTEL_FAM6_RAPTORLAKE		0xB7
 
+
 /* "Small Core" Processors (Atom) */
 
 #define INTEL_FAM6_ATOM_BONNELL		0x1C /* Diamondville, Pineview */
-- 
2.25.1

