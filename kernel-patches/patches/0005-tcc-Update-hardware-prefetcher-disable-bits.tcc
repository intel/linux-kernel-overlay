From 239bcb3070b7d31532f2dc630b25bcd63f00fdbb Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Tue, 19 Apr 2022 12:36:32 +0800
Subject: [PATCH 5/6] tcc: Update hardware prefetcher disable bits for ADL and
 RPL in cache hit/miss measurement.

Adding memory barrier to improve accuracy.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 14 ++++++++++++--
 1 file changed, 12 insertions(+), 2 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index 76cc47c591b8..751be82c4131 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -323,6 +323,9 @@ static u64 get_hardware_prefetcher_disable_bits(void)
 	return 0x5;
 	case INTEL_FAM6_ATOM_TREMONT:
 	return 0x1F;
+	case INTEL_FAM6_ALDERLAKE:
+	case INTEL_FAM6_RAPTORLAKE:
+	return 0x2F;
 	default:
 	return 0xF;
 	}
@@ -396,14 +399,19 @@ static int tcc_perf_fn(void)
 
 	/* capture the timestamp at the meantime while hitting buffer */
 	start = rdtsc_ordered();
+	/* Add a barrier to ensure all previous instructions are retired before proceeding */
+	rmb();
 	for (i = 0; i < cacheread_size; i += cacheline_len) {
+		/* Add a barrier to prevent reading beyond the end of the buffer */
+		rmb();
 		asm volatile("mov (%0,%1,1), %%eax\n\t"
 				:
 				: "r" (cachemem_k), "r" (i)
 				: "%eax", "memory");
 	}
+	/* Add a barrier to ensure all previous instructions are retired before proceeding */
+	rmb();
 	end = rdtsc_ordered();
-
 	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, msr_bits_l2h & PERFMON_EVENTSEL_BITMASK);
 	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 1, msr_bits_l2m & PERFMON_EVENTSEL_BITMASK);
 
@@ -429,10 +437,12 @@ static int tcc_perf_fn(void)
 		perf_l1h = native_read_pmc(2);
 		perf_l1m = native_read_pmc(3);
 	}
-
+	/* Add a barrier to ensure all previous instructions are retired before proceeding */
+	rmb();
 	wrmsr(MSR_MISC_FEATURE_CONTROL, 0x0, 0x0);
 	asm volatile (" sti ");
 
+	pr_info("Finish test: i = %lld\n", i);
 	if (cache_info_k.cache_level == RGN_L2) {
 		pr_info("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
 		pr_info("PERFMARK perf_l1h=%-10llu perf_l1m=%-10llu", perf_l1h, perf_l1m);
-- 
2.17.1

