From b3467505bfdc599f8548576ddc65889db712606e Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Fri, 12 Nov 2021 10:28:35 -0800
Subject: [PATCH 0042/8803] x86/cpu: Add Raptor Lake to Intel family

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
index 31adb7dfaaaa..adf7a3072944 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -114,6 +114,8 @@
 #define INTEL_FAM6_ALDERLAKE_L		0x9A	/* Golden Cove / Gracemont */
 #define INTEL_FAM6_ALDERLAKE_N		0xBE
 
+#define INTEL_FAM6_RAPTOR_LAKE		0xB7
+
 /* "Small Core" Processors (Atom/E-Core) */
 
 #define INTEL_FAM6_ATOM_BONNELL		0x1C /* Diamondville, Pineview */
-- 
2.25.1

