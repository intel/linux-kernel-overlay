From c191c2a7fb50abb75c69aac7c4fbea2403a57144 Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Fri, 12 Nov 2021 10:28:35 -0800
Subject: [PATCH 3/6] x86/cpu: Add Raptor Lake to Intel family

Add model ID for Raptor Lake.

[ dhansen: These get added as soon as possible so that folks doing
  development can leverage them. ]

Signed-off-by: Tony Luck <tony.luck@intel.com>
Signed-off-by: Dave Hansen <dave.hansen@linux.intel.com>
Link: https://lkml.kernel.org/r/20211112182835.924977-1-tony.luck@intel.com
---
 arch/x86/include/asm/intel-family.h | 2 ++
 1 file changed, 2 insertions(+)

diff --git a/arch/x86/include/asm/intel-family.h b/arch/x86/include/asm/intel-family.h
index 2827b72eed9e..0e3a9ddaf8eb 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -109,6 +109,8 @@
 #define INTEL_FAM6_ALDERLAKE_L		0x9A	/* Golden Cove / Gracemont */
 #define INTEL_FAM6_ALDERLAKE_N		0xBE
 
+#define INTEL_FAM6_RAPTOR_LAKE		0xB7
+
 /* "Small Core" Processors (Atom) */
 
 #define INTEL_FAM6_ATOM_BONNELL		0x1C /* Diamondville, Pineview */
-- 
2.17.1

