From e0f08484ce9f95a88d0869eac3b2e3716e857ac2 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Tue, 22 Feb 2022 00:57:00 +0800
Subject: [PATCH 20/23] tcc: Map and show crl version number in /proc.

Use do_div() to fix ld error undefined reference to `__udivdi3'.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 69 +++++++++++++++++++++++++++++++++++-----
 1 file changed, 61 insertions(+), 8 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index b3d19b4caacf..536e7cccfd1c 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -59,6 +59,7 @@
 #include <asm/intel-family.h>
 #include <asm/nops.h>
 #include <asm/perf_event.h>
+#include <asm/div64.h>
 #include <linux/acpi.h>
 #include <linux/init.h>
 #include <linux/io.h>
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
@@ -260,12 +273,13 @@ DECLARE_BITMAP(tcc_buffer_device_minor_avail, MAXDEVICENODE);
 static struct class *tcc_buffer_class;
 static struct acpi_table_header *acpi_ptct_tbl;
 static struct tcc_config *p_tcc_config;
-static u64 erraddr;
-static u32 errsize;
+static u64 erraddr, crladdr;
+static u32 errsize, crlsize;
 static u32 tcc_init;
 static u32 ptct_format = FORMAT_V1;
 DEFINE_MUTEX(tccbuffer_mutex);
 static int tcc_errlog_show(struct seq_file *m, void *v);
+static int tcc_crlver_show(struct seq_file *m, void *v);
 static void *cache_info_k_virt_addr;
 struct cache_info_s {
 	u64 phy_addr;
@@ -319,11 +333,11 @@ static inline void tcc_perf_wrmsrl(u32 reg, u64 data)
 
 static int tcc_perf_fn(void)
 {
-	u32 cacheline_len = 0, cacheread_size = 0;
 	u64 perf_l1h = 0, perf_l1m = 0, msr_bits_l1h = 0, msr_bits_l1m = 0;
 	u64 perf_l2h = 0, perf_l2m = 0, msr_bits_l2h = 0, msr_bits_l2m = 0;
 	u64 perf_l3h = 0, perf_l3m = 0, msr_bits_l3h = 0, msr_bits_l3m = 0;
-	u64 i = 0, start = 0, end = 0;
+	u64 i = 0, start = 0, end = 0, tsc_delta = 0, tsc_us = 0;
+	u32 cacheline_len = 0, cacheread_size = 0;
 	void *cachemem_k;
 
 	pr_err("In %s\n", __func__);
@@ -344,6 +358,8 @@ static int tcc_perf_fn(void)
 	cachemem_k     = cache_info_k_virt_addr;
 	cacheread_size = cache_info_k.cache_size;
 	cacheline_len  = cache_info_k.cacheline_size;
+	if ((cacheline_len == 0) || (cachemem_k == NULL))
+		return -1;
 
 	/* Disable events and reset counters. 4 pairs. */
 	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, MISC_MSR_BITS_ALL_CLEAR);
@@ -430,13 +446,17 @@ static int tcc_perf_fn(void)
 		cache_info_k.l3_hits = perf_l3h;
 		cache_info_k.l3_miss = perf_l3m;
 	}
+	tsc_delta = end-start;
+	tsc_us = (end-start)*1000;
 	pr_err("start: %lld\n", start);
 	pr_err("end:   %lld\n", end);
-	pr_err("delta: %lld\n", (end-start));
+	pr_err("delta: %lld\n", tsc_delta);
 	pr_err("tsc:   %d kHz\n", tsc_khz);
 	pr_err("With integer truncation:\n");
-	pr_err("Average each cacheline read takes: %lld tsc ticks\n", (end-start)/(cacheread_size/cacheline_len));
-	pr_err("Total cache read takes:      %lld us\n", ((end-start)*1000)/tsc_khz);
+	do_div(tsc_delta, cacheread_size/cacheline_len);
+	pr_err("Average each cacheline read takes: %lld tsc ticks\n", tsc_delta);
+	do_div(tsc_us, tsc_khz);
+	pr_err("Total cache read takes:      %lld us\n", tsc_us);
 
 	return 0;
 }
@@ -664,6 +684,27 @@ static int tcc_errlog_show(struct seq_file *m, void *v)
 	return ret;
 }
 
+static int tcc_crlver_show(struct seq_file *m, void *v)
+{
+	void *crl_buff = NULL;
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
@@ -676,6 +717,8 @@ static int tcc_parse_ptct(void)
 	struct tcc_ptct_psram_v2 *entry_psram_v2;
 	struct tcc_ptct_sram_waymask_v2 *entry_sram_waymask_v2;
 	struct tcc_ptct_errlog_v2 *entry_errlog_v2;
+	struct tcc_ptct_crl_v2 *entry_crl_v2;
+	struct tcc_ptct_crl *entry_crl;
 	static struct psram *p_new_psram;
 	static struct memory_slot_info *p_memslot;
 	struct psram *p_tmp_psram;
@@ -714,7 +757,7 @@ static int tcc_parse_ptct(void)
 
 	dprintk("ptct_format = %s\n", (ptct_format == FORMAT_V1) ? "FORMAT_V1":"FORMAT_V2");
 
-	/* Parse and save memory latency and errer log buffer address */
+	/* Parse and save memory latency and errer log buffer address and crl version */
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 	offset = ACPI_HEADER_SIZE;
 	tbl_swap = tbl_swap + offset;
@@ -741,6 +784,14 @@ static int tcc_parse_ptct(void)
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
@@ -1574,6 +1625,7 @@ static int __init tcc_buffer_init(void)
 
 	ent = proc_create("tcc_cache_test", 0660, NULL, &testops);
 	proc_create_single("tcc_errlog", 0, NULL, tcc_errlog_show);
+	proc_create_single("tcc_crlver", 0, NULL, tcc_crlver_show);
 	tcc_init = 1;
 	p_tcc_config->minor = new_minor;
 
@@ -1602,6 +1654,7 @@ static void __exit tcc_buffer_exit(void)
 
 		proc_remove(ent);
 		remove_proc_entry("tcc_errlog", NULL);
+		remove_proc_entry("tcc_crlver", NULL);
 	}
 	pr_err("exit().\n");
 }
-- 
2.25.1

