From 173a445eebaf36fb5ade80d07673f88c9f48353f Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Tue, 19 Apr 2022 23:41:07 +0800
Subject: [PATCH 23/23] tcc: Choose different L3 cache miss perf event for
 ADL-N.

ADL-N has no MEM_LOAD_RETIRED.L3_MISS, choose generic LLC_MISS instead.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 7 ++++++-
 1 file changed, 6 insertions(+), 1 deletion(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index c4fa8093eb9a..c40b253475fa 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -306,6 +306,7 @@ static int tcc_perf_fn(void);
 #define MSR_MISC_FEATURE_CONTROL    0x000001a4
 #define READ_BYTE_SIZE              64
 #define MISC_MSR_BITS_COMMON        ((0x52ULL << 16) | 0xd1)
+#define MISC_MSR_BITS_GENERIC_L3    ((0x52ULL << 16) | 0x2e)
 #define MISC_MSR_BITS_ALL_CLEAR     0x0
 #define PERFMON_EVENTSEL_BITMASK    (~(0x40ULL << 16))
 
@@ -322,6 +323,7 @@ static u64 get_hardware_prefetcher_disable_bits(void)
 	case INTEL_FAM6_ATOM_TREMONT:
 	return 0x1F;
 	case INTEL_FAM6_ALDERLAKE:
+	case INTEL_FAM6_ALDERLAKE_N:
 	case INTEL_FAM6_RAPTORLAKE:
 	return 0x2F;
 	default:
@@ -353,7 +355,10 @@ static int tcc_perf_fn(void)
 		msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
 		msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
 		msr_bits_l3h = (MISC_MSR_BITS_COMMON) | (0x4  << 8);
-		msr_bits_l3m = (MISC_MSR_BITS_COMMON) | (0x20 << 8);
+		if (boot_cpu_data.x86_model == INTEL_FAM6_ALDERLAKE_N)
+			msr_bits_l3m = (MISC_MSR_BITS_GENERIC_L3) | (0x41 << 8);
+		else
+			msr_bits_l3m = (MISC_MSR_BITS_COMMON) | (0x20 << 8);
 	}
 	asm volatile (" cli ");
 	__wrmsr(MSR_MISC_FEATURE_CONTROL, hardware_prefetcher_disable_bits, 0x0);
-- 
2.25.1

