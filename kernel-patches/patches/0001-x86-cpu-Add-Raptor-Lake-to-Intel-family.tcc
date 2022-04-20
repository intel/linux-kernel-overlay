From 27f296aaee6a437559131c76d058ae2567f06da7 Mon Sep 17 00:00:00 2001
From: Tony Luck <tony.luck@intel.com>
Date: Fri, 12 Nov 2021 10:28:35 -0800
Subject: [PATCH 1/4] x86/cpu: Add Raptor Lake to Intel family

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
index 0fc2a368699c..7ef1afd8fae3 100644
--- a/arch/x86/include/asm/intel-family.h
+++ b/arch/x86/include/asm/intel-family.h
@@ -100,6 +100,8 @@
 #define INTEL_FAM6_ALDERLAKE_L		0x9A
 #define INTEL_FAM6_ALDERLAKE_N		0xBE
 
+#define INTEL_FAM6_RAPTOR_LAKE		0xB7
+
 /* "Small Core" Processors (Atom) */
 
 #define INTEL_FAM6_ATOM_BONNELL		0x1C /* Diamondville, Pineview */
-- 
2.25.1

