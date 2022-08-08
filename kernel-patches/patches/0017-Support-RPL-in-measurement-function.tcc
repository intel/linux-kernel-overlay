From 8a856a610fbd70c667c21c5ccac7f966f40da403 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Tue, 9 Nov 2021 00:05:41 +0800
Subject: [PATCH 17/23] Support RPL in measurement function.

Fix sparse warnings.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 37 +++++++++++++++++++++++++++++++------
 drivers/tcc/tcc_buffer.h | 15 ---------------
 2 files changed, 31 insertions(+), 21 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index 7943c17c5175..0e584e4e65a6 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -239,6 +239,22 @@ struct tcc_config {
 	struct list_head psrams;
 };
 
+/* White-listed registers */
+static const struct tcc_registers_wl_s tcc_registers_wl_ehl[] = {
+	{0xFEDA0000, 0x0A78},
+};
+
+static const struct tcc_registers_wl_s tcc_registers_wl_tglu[] = {
+	{ 0xFEDA0000, 0x0A78},
+	{ 0xFEDC0000, 0x6F08},
+	{ 0xFEDC0000, 0x6F10},
+	{ 0xFEDC0000, 0x6F00}
+};
+
+static const struct tcc_registers_wl_s tcc_registers_wl_tglh[] = {
+	{ 0xFEDA0000, 0x0A78}
+};
+
 #define MAXDEVICENODE 250
 static unsigned int tcc_buffer_device_major;
 DECLARE_BITMAP(tcc_buffer_device_minor_avail, MAXDEVICENODE);
@@ -259,8 +275,11 @@ static int tcc_errlog_show(struct seq_file *m, void *v);
 #ifndef INTEL_FAM6_ALDERLAKE_L
 #define INTEL_FAM6_ALDERLAKE_L 0x9A
 #endif
+#ifndef INTEL_FAM6_RAPTOR_LAKE
+#define INTEL_FAM6_RAPTOR_LAKE 0xB7
+#endif
 
-void *cache_info_k_virt_addr;
+static void *cache_info_k_virt_addr;
 
 struct cache_info_s {
 	u64 phy_addr;           // in: psram physical address
@@ -276,7 +295,7 @@ struct cache_info_s {
 	u64 l3_miss;            // out:
 };
 
-struct cache_info_s cache_info_k = {0,};
+static struct cache_info_s cache_info_k = {0,};
 #define BUFSIZE  sizeof(struct cache_info_s)
 static struct proc_dir_entry *ent;
 static u64 hardware_prefetcher_disable_bits;
@@ -307,6 +326,7 @@ static u64 get_hardware_prefetcher_disable_bits(void)
 	case INTEL_FAM6_ICELAKE_L:
 	case INTEL_FAM6_ICELAKE_X:
 	case INTEL_FAM6_ICELAKE_D:
+	case INTEL_FAM6_RAPTOR_LAKE:
 	return 0xF;
 	case INTEL_FAM6_ATOM_GOLDMONT:
 	case INTEL_FAM6_ATOM_GOLDMONT_PLUS:
@@ -351,6 +371,7 @@ static int tcc_perf_fn(void)
 	case INTEL_FAM6_ICELAKE_L:
 	case INTEL_FAM6_ICELAKE_X:
 	case INTEL_FAM6_ICELAKE_D:
+	case INTEL_FAM6_RAPTOR_LAKE:
 	{
 		if (cache_info_k.cache_level == RGN_L2) {
 			msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
@@ -367,7 +388,7 @@ static int tcc_perf_fn(void)
 	break;
 	default:
 		pr_err("Didn't catch this CPU Model in perf_fn()!\n");
-		goto out;
+		return -1;
 	}
 
 	asm volatile (" cli ");
@@ -466,8 +487,11 @@ static int tcc_perf_fn(void)
 	pr_err("start: %lld\n", start);
 	pr_err("end:   %lld\n", end);
 	pr_err("delta: %lld\n", (end-start));
+	pr_err("tsc:   %d kHz\n", tsc_khz);
+	pr_err("With integer truncation:\n");
+	pr_err("Average each cacheline read takes: %lld tsc ticks\n", (end-start)/(cacheread_size/cacheline_len));
+	pr_err("Total cache read takes:      %lld us\n", ((end-start)*1000)/tsc_khz);
 
-out:
 	return 0;
 }
 
@@ -550,13 +574,13 @@ static ssize_t get_test_result(struct file *file, char __user *ubuf, size_t coun
 }
 
 #if KERNEL_VERSION(5, 6, 1) > LINUX_VERSION_CODE
-const struct file_operations testops = {
+static const struct file_operations testops = {
 	.owner = THIS_MODULE,
 	.read = get_test_result,
 	.write = set_test_setup,
 };
 #else
-const struct proc_ops testops = {
+static const struct proc_ops testops = {
 	.proc_read = get_test_result,
 	.proc_write = set_test_setup,
 };
@@ -1118,6 +1142,7 @@ static void tcc_free_memslot(struct memory_slot_info *p_memslot)
 	p_memslot->minor = UNDEFINED_DEVNODE;
 	dprintk("%s\n", "tcc_free_memslot()");
 	dprintk("p_memslot->paddr    @ %016llx\n", (u64)(p_memslot->paddr));
+	dprintk("p_memslot->vaddr    @ %016llx\n", (u64)(p_memslot->vaddr));
 	dprintk("p_memslot->size     @ %016llx\n", (u64)(p_memslot->size));
 	mem_info.vaddr = p_memslot->vaddr;
 	mem_info.size  = p_memslot->size;
diff --git a/drivers/tcc/tcc_buffer.h b/drivers/tcc/tcc_buffer.h
index 7fcce803c874..dc4663a5c555 100644
--- a/drivers/tcc/tcc_buffer.h
+++ b/drivers/tcc/tcc_buffer.h
@@ -113,21 +113,6 @@ struct tcc_registers_wl_s {
 	u64 offset;
 };
 
-struct tcc_registers_wl_s tcc_registers_wl_ehl[] = {
-	{0xFEDA0000, 0x0A78},
-};
-
-struct tcc_registers_wl_s tcc_registers_wl_tglu[] = {
-	{ 0xFEDA0000, 0x0A78},
-	{ 0xFEDC0000, 0x6F08},
-	{ 0xFEDC0000, 0x6F10},
-	{ 0xFEDC0000, 0x6F00}
-};
-
-struct tcc_registers_wl_s tcc_registers_wl_tglh[] = {
-	{ 0xFEDA0000, 0x0A78}
-};
-
 /* enum type for tcc_register structure */
 enum TCC_REG_PHASE {
 	TCC_PRE_MEM        = 0x00000000,
-- 
2.25.1

