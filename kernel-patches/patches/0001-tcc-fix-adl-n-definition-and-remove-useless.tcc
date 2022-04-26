From d1713be6c1542fd79ad8926d90ae943cee9678dc Mon Sep 17 00:00:00 2001
From: Junxiao Chang <junxiao.chang@intel.com>
Date: Wed, 20 Apr 2022 11:14:54 +0800
Subject: [PATCH] tcc: fix adl-n definition and remove useless rmb

Removing useless rmb and pr_info, and fix adl-n definition issue.

Signed-off-by: Junxiao Chang <junxiao.chang@intel.com>
---
 drivers/tcc/tcc_buffer.c | 8 +-------
 1 file changed, 1 insertion(+), 7 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index e80866462cec..6b547693d140 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -324,9 +324,8 @@ static u64 get_hardware_prefetcher_disable_bits(void)
 	return 0x5;
 	case INTEL_FAM6_ATOM_TREMONT:
 	return 0x1F;
-	case INTEL_FAM6_ALDERLAKE_N:
-	return 0xAF;
 	case INTEL_FAM6_ALDERLAKE:
+	case INTEL_FAM6_ALDERLAKE_N:
 	case INTEL_FAM6_RAPTORLAKE:
 	return 0x2F;
 	default:
@@ -405,8 +404,6 @@ static int tcc_perf_fn(void)
 
 	/* capture the timestamp at the meantime while hitting buffer */
 	start = rdtsc_ordered();
-	/* Add a barrier to ensure all previous instructions are retired before proceeding */
-	rmb();
 	for (i = 0; i < cacheread_size; i += cacheline_len) {
 		/* Add a barrier to prevent reading beyond the end of the buffer */
 		rmb();
@@ -415,8 +412,6 @@ static int tcc_perf_fn(void)
 				: "r" (cachemem_k), "r" (i)
 				: "%eax", "memory");
 	}
-	/* Add a barrier to ensure all previous instructions are retired before proceeding */
-	rmb();
 	end = rdtsc_ordered();
 	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, msr_bits_l2h & PERFMON_EVENTSEL_BITMASK);
 	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 1, msr_bits_l2m & PERFMON_EVENTSEL_BITMASK);
@@ -448,7 +443,6 @@ static int tcc_perf_fn(void)
 	wrmsr(MSR_MISC_FEATURE_CONTROL, 0x0, 0x0);
 	asm volatile (" sti ");
 
-	pr_info("Finish test: i = %lld\n", i);
 	if (cache_info_k.cache_level == RGN_L2) {
 		pr_info("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
 		pr_info("PERFMARK perf_l1h=%-10llu perf_l1m=%-10llu", perf_l1h, perf_l1m);
-- 
2.17.1

