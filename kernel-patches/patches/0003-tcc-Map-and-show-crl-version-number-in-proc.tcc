From 7a579fa218c9f7a233932be497bd74eee4920f24 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Tue, 22 Feb 2022 00:57:00 +0800
Subject: [PATCH 3/3] tcc: Map and show crl version number in /proc.

Use do_div() to fix ld error undefined reference to `__udivdi3'.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 123 +++++++++++++++++++++++++++++----------
 1 file changed, 91 insertions(+), 32 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index cbac7cc8f329..439d1de723aa 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -56,6 +56,7 @@
 #define pr_fmt(fmt) "TCC Buffer: " fmt
 
 #include <asm/cacheflush.h>
+#include <asm/div64.h>
 #include <asm/intel-family.h>
 #include <asm/nops.h>
 #include <asm/perf_event.h>
@@ -172,6 +173,12 @@ struct tcc_ptct_mhlatency {
 	u32 *apicids;
 };
 
+struct tcc_ptct_crl {
+	u32 crladdr_lo;
+	u32 crladdr_hi;
+	u32 crlsize;
+};
+
 struct tcc_ptct_psram_v2 {
 	u32 cache_level;
 	u32 cache_id;
@@ -206,6 +213,12 @@ struct tcc_ptct_errlog_v2 {
 	u32 errsize;
 };
 
+struct tcc_ptct_crl_v2 {
+	u32 crladdr_lo;
+	u32 crladdr_hi;
+	u32 crlsize;
+};
+
 struct memory_slot_info {
 	u64 paddr;
 	void *vaddr;
@@ -262,10 +275,13 @@ static struct acpi_table_header *acpi_ptct_tbl;
 static struct tcc_config *p_tcc_config;
 static u64 erraddr;
 static u32 errsize;
+static u64 crladdr;
+static u32 crlsize;
 static u32 tcc_init;
 static u32 ptct_format = FORMAT_V1;
 DEFINE_MUTEX(tccbuffer_mutex);
 static int tcc_errlog_show(struct seq_file *m, void *v);
+static int tcc_crlver_show(struct seq_file *m, void *v);
 static void *cache_info_k_virt_addr;
 struct cache_info_s {
 	u64 phy_addr;
@@ -319,20 +335,24 @@ static inline void tcc_perf_wrmsrl(u32 reg, u64 data)
 
 static int tcc_perf_fn(void)
 {
-	u32 cacheline_len = 0, cacheread_size = 0;
-	u64 perf_l1h = 0, perf_l1m = 0, msr_bits_l1h = 0, msr_bits_l1m = 0;
-	u64 perf_l2h = 0, perf_l2m = 0, msr_bits_l2h = 0, msr_bits_l2m = 0;
-	u64 perf_l3h = 0, perf_l3m = 0, msr_bits_l3h = 0, msr_bits_l3m = 0;
-	u64 i = 0, start = 0, end = 0;
+	u64 perf_l1h, perf_l1m, msr_bits_l1h, msr_bits_l1m;
+	u64 perf_l2h, perf_l2m, msr_bits_l2h, msr_bits_l2m;
+	u64 perf_l3h, perf_l3m, msr_bits_l3h, msr_bits_l3m;
+	u64 i, start, end, tsc_delta, tsc_us;
+	u32 cacheline_len, cacheread_size;
 	void *cachemem_k;
 
-	pr_err("In %s\n", __func__);
+	pr_info("In %s\n", __func__);
 	if (cache_info_k.cache_level == RGN_L2) {
-		msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
-		msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
 		msr_bits_l1h = (MISC_MSR_BITS_COMMON) | (0x1  << 8);
 		msr_bits_l1m = (MISC_MSR_BITS_COMMON) | (0x08 << 8);
-	} else if (cache_info_k.cache_level == RGN_L3) {
+		msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
+		msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
+		msr_bits_l3h = 0;
+		msr_bits_l3m = 0;
+	} else {
+		msr_bits_l1h = 0;
+		msr_bits_l1m = 0;
 		msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
 		msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
 		msr_bits_l3h = (MISC_MSR_BITS_COMMON) | (0x4  << 8);
@@ -344,6 +364,8 @@ static int tcc_perf_fn(void)
 	cachemem_k     = cache_info_k_virt_addr;
 	cacheread_size = cache_info_k.cache_size;
 	cacheline_len  = cache_info_k.cacheline_size;
+	if ((cacheline_len == 0) || (cachemem_k == NULL))
+		return -1;
 
 	/* Disable events and reset counters. 4 pairs. */
 	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, MISC_MSR_BITS_ALL_CLEAR);
@@ -412,17 +434,17 @@ static int tcc_perf_fn(void)
 	asm volatile (" sti ");
 
 	if (cache_info_k.cache_level == RGN_L2) {
-		pr_err("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
-		pr_err("PERFMARK perf_l1h=%-10llu perf_l1m=%-10llu", perf_l1h, perf_l1m);
+		pr_info("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
+		pr_info("PERFMARK perf_l1h=%-10llu perf_l1m=%-10llu", perf_l1h, perf_l1m);
 		cache_info_k.l1_hits = perf_l1h;
 		cache_info_k.l1_miss = perf_l1m;
 		cache_info_k.l2_hits = perf_l2h;
 		cache_info_k.l2_miss = perf_l2m;
 		cache_info_k.l3_hits = 0;
 		cache_info_k.l3_miss = 0;
-	} else if (cache_info_k.cache_level == RGN_L3) {
-		pr_err("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
-		pr_err("PERFMARK perf_l3h=%-10llu perf_l3m=%-10llu", perf_l3h, perf_l3m);
+	} else {
+		pr_info("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
+		pr_info("PERFMARK perf_l3h=%-10llu perf_l3m=%-10llu", perf_l3h, perf_l3m);
 		cache_info_k.l1_hits = 0;
 		cache_info_k.l1_miss = 0;
 		cache_info_k.l2_hits = perf_l2h;
@@ -430,13 +452,17 @@ static int tcc_perf_fn(void)
 		cache_info_k.l3_hits = perf_l3h;
 		cache_info_k.l3_miss = perf_l3m;
 	}
-	pr_err("start: %lld\n", start);
-	pr_err("end:   %lld\n", end);
-	pr_err("delta: %lld\n", (end-start));
-	pr_err("tsc:   %d kHz\n", tsc_khz);
-	pr_err("With integer truncation:\n");
-	pr_err("Average each cacheline read takes: %lld tsc ticks\n", (end-start)/(cacheread_size/cacheline_len));
-	pr_err("Total cache read takes:      %lld us\n", ((end-start)*1000)/tsc_khz);
+	tsc_delta = end-start;
+	tsc_us = (end-start)*1000;
+	pr_info("start: %lld\n", start);
+	pr_info("end:   %lld\n", end);
+	pr_info("delta: %lld\n", tsc_delta);
+	pr_info("tsc:   %d kHz\n", tsc_khz);
+	pr_info("With integer truncation:\n");
+	do_div(tsc_delta, cacheread_size/cacheline_len);
+	pr_info("Average each cacheline read takes: %lld tsc ticks\n", tsc_delta);
+	do_div(tsc_us, tsc_khz);
+	pr_info("Total cache read takes:      %lld us\n", tsc_us);
 
 	return 0;
 }
@@ -473,18 +499,18 @@ static ssize_t set_test_setup(struct file *file, const char __user *ubuf, size_t
 	switch (cache_info_k.testcase) {
 	case TEST_CACHE_PERF:
 	{
-		pr_err("cache_info_k.phy_addr        0x%016llx\n", cache_info_k.phy_addr);
-		pr_err("cache_info_k.cache_level     %d\n", cache_info_k.cache_level);
-		pr_err("cache_info_k.cache_size      0x%08x\n", cache_info_k.cache_size);
-		pr_err("cache_info_k.cacheline_size  %d\n", cache_info_k.cacheline_size);
-		pr_err("cache_info_k.testcase        %d\n", cache_info_k.testcase);
+		pr_info("cache_info_k.phy_addr        0x%016llx\n", cache_info_k.phy_addr);
+		pr_info("cache_info_k.cache_level     %d\n", cache_info_k.cache_level);
+		pr_info("cache_info_k.cache_size      0x%08x\n", cache_info_k.cache_size);
+		pr_info("cache_info_k.cacheline_size  %d\n", cache_info_k.cacheline_size);
+		pr_info("cache_info_k.testcase        %d\n", cache_info_k.testcase);
 
 		cache_info_k_virt_addr = memremap(cache_info_k.phy_addr, cache_info_k.cache_size, MEMREMAP_WB);
 
-		if (cache_info_k_virt_addr == NULL)
+		if (cache_info_k_virt_addr == NULL) {
 			pr_err("cache_info_k_virt_addr == NULL\n");
-		else
-			pr_err("cache_info_k_virt_addr       0x%px\n", cache_info_k_virt_addr);
+			return -EFAULT;
+		}
 
 		if (start_measure() != 0)
 			pr_err("Something wrong with the cache performance measurement!");
@@ -642,8 +668,8 @@ static void tcc_get_psram_cpumask(u32 coreid, u32 num_threads_sharing, cpumask_t
 
 static int tcc_errlog_show(struct seq_file *m, void *v)
 {
-	void *errlog_buff = NULL;
-	u32 i = 0;
+	void *errlog_buff;
+	u32 i;
 	int ret = 0;
 
 	if (errsize > 0) {
@@ -664,6 +690,27 @@ static int tcc_errlog_show(struct seq_file *m, void *v)
 	return ret;
 }
 
+static int tcc_crlver_show(struct seq_file *m, void *v)
+{
+	void *crl_buff;
+	int ret = 0;
+
+	if (crlsize > 0) {
+		crl_buff = memremap(crladdr, 8, MEMREMAP_WB);
+		if (!crl_buff) {
+			seq_puts(m, "System error. Fail to map this CRL address.\n");
+			ret = -ENOMEM;
+		} else {
+			seq_printf(m, "%08x\n", ((u32 *)crl_buff)[0]);
+			seq_printf(m, "%08x\n", ((u32 *)crl_buff)[1]);
+			memunmap(crl_buff);
+		}
+	} else
+		seq_puts(m, "No CRL.\n");
+
+	return ret;
+}
+
 static int tcc_parse_ptct(void)
 {
 	u32 *tbl_swap;
@@ -676,6 +723,8 @@ static int tcc_parse_ptct(void)
 	struct tcc_ptct_psram_v2 *entry_psram_v2;
 	struct tcc_ptct_sram_waymask_v2 *entry_sram_waymask_v2;
 	struct tcc_ptct_errlog_v2 *entry_errlog_v2;
+	struct tcc_ptct_crl_v2 *entry_crl_v2;
+	struct tcc_ptct_crl *entry_crl;
 	static struct psram *p_new_psram;
 	static struct memory_slot_info *p_memslot;
 	struct psram *p_tmp_psram;
@@ -714,7 +763,7 @@ static int tcc_parse_ptct(void)
 
 	dprintk("ptct_format = %s\n", (ptct_format == FORMAT_V1) ? "FORMAT_V1":"FORMAT_V2");
 
-	/* Parse and save memory latency and errer log buffer address */
+	/* Parse and save memory latency and errer log buffer address and crl version */
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 	offset = ACPI_HEADER_SIZE;
 	tbl_swap = tbl_swap + offset;
@@ -741,6 +790,14 @@ static int tcc_parse_ptct(void)
 			entry_errlog_v2 = (struct tcc_ptct_errlog_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
 			erraddr = ((u64)(entry_errlog_v2->erraddr_hi) << 32) | entry_errlog_v2->erraddr_lo;
 			errsize = entry_errlog_v2->errsize;
+		} else if ((ptct_format == FORMAT_V2) && (entry_type == PTCT_V2_CRL_BINARY)) {
+			entry_crl_v2 = (struct tcc_ptct_crl_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
+			crladdr = ((u64)(entry_crl_v2->crladdr_hi) << 32) | entry_crl_v2->crladdr_lo;
+			crlsize = entry_crl_v2->crlsize;
+		} else if ((ptct_format == FORMAT_V1) && (entry_type == PTCT_PTCM_BINARY)) {
+			entry_crl = (struct tcc_ptct_crl *)(tbl_swap + ENTRY_HEADER_SIZE);
+			crladdr = ((u64)(entry_crl->crladdr_hi) << 32) | entry_crl->crladdr_lo;
+			crlsize = entry_crl->crlsize;
 		}
 
 		offset += entry_size / sizeof(u32);
@@ -1574,6 +1631,7 @@ static int __init tcc_buffer_init(void)
 
 	ent = proc_create("tcc_cache_test", 0660, NULL, &testops);
 	proc_create_single("tcc_errlog", 0, NULL, tcc_errlog_show);
+	proc_create_single("tcc_crlver", 0, NULL, tcc_crlver_show);
 	tcc_init = 1;
 	p_tcc_config->minor = new_minor;
 
@@ -1602,6 +1660,7 @@ static void __exit tcc_buffer_exit(void)
 
 		proc_remove(ent);
 		remove_proc_entry("tcc_errlog", NULL);
+		remove_proc_entry("tcc_crlver", NULL);
 	}
 	pr_err("exit().\n");
 }
-- 
2.25.1

