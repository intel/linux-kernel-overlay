From 3accab19523e5d90303fb4ecd37d872a3e6cb2b6 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Tue, 8 Jun 2021 17:59:33 +0800
Subject: [PATCH 14/23] Display errlog buffer raw data in kernel log as
 requested once this driver is loaded.

Fix W=1 warnings.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 46 +++++++++++++++++++++++-----------------
 1 file changed, 27 insertions(+), 19 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index e06f2ec466b7..dfbdc54379a3 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -282,6 +282,7 @@ static u64 hardware_prefetcher_disable_bits;
 
 static u64 get_hardware_prefetcher_disable_bits(void);
 static inline void tcc_perf_wrmsrl(u32 msr, u64 val);
+static int start_measure(void);
 static int tcc_perf_fn(void);
 
 #define MSR_MISC_FEATURE_CONTROL    0x000001a4
@@ -311,8 +312,9 @@ static u64 get_hardware_prefetcher_disable_bits(void)
 	return 0x5;
 	case INTEL_FAM6_ATOM_TREMONT:
 	return 0x1F;
+	default:
+		pr_err("Didn't catch CPU model in setting prefetcher disable bits.\n");
 	}
-	pr_err("Didn't catch CPU model in setting prefetcher disable bits.\n");
 	return 0;
 }
 
@@ -442,8 +444,8 @@ static int tcc_perf_fn(void)
 	asm volatile (" sti ");
 
 	if (cache_info_k.cache_level == RGN_L2) {
-		pr_err("PERFMARK perf_l2h=%llu perf_l2m=%llu", perf_l2h, perf_l2m);
-		pr_err("PERFMARK perf_l1h=%llu perf_l1m=%llu", perf_l1h, perf_l1m);
+		pr_err("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
+		pr_err("PERFMARK perf_l1h=%-10llu perf_l1m=%-10llu", perf_l1h, perf_l1m);
 		cache_info_k.l1_hits = perf_l1h;
 		cache_info_k.l1_miss = perf_l1m;
 		cache_info_k.l2_hits = perf_l2h;
@@ -451,8 +453,8 @@ static int tcc_perf_fn(void)
 		cache_info_k.l3_hits = 0;
 		cache_info_k.l3_miss = 0;
 	} else if (cache_info_k.cache_level == RGN_L3) {
-		pr_err("PERFMARK perf_l2h=%llu perf_l2m=%llu", perf_l2h, perf_l2m);
-		pr_err("PERFMARK perf_l3h=%llu perf_l3m=%llu", perf_l3h, perf_l3m);
+		pr_err("PERFMARK perf_l2h=%-10llu perf_l2m=%-10llu", perf_l2h, perf_l2m);
+		pr_err("PERFMARK perf_l3h=%-10llu perf_l3m=%-10llu", perf_l3h, perf_l3m);
 		cache_info_k.l1_hits = 0;
 		cache_info_k.l1_miss = 0;
 		cache_info_k.l2_hits = perf_l2h;
@@ -468,7 +470,7 @@ static int tcc_perf_fn(void)
 	return 0;
 }
 
-int start_measure(void)
+static int start_measure(void)
 {
 	int ret = -1;
 
@@ -487,10 +489,8 @@ int start_measure(void)
 	ret = 0;
 out:
 	return ret;
-
 }
 
-
 static ssize_t set_test_setup(struct file *file, const char __user *ubuf, size_t count, loff_t *ppos)
 {
 	if (count > BUFSIZE)
@@ -513,7 +513,7 @@ static ssize_t set_test_setup(struct file *file, const char __user *ubuf, size_t
 		if (cache_info_k_virt_addr == NULL)
 			pr_err("cache_info_k_virt_addr == NULL\n");
 		else
-			pr_err("cache_info_k_virt_addr	0x%016llx\n", (u64)(cache_info_k_virt_addr));
+			pr_err("cache_info_k_virt_addr       0x%px\n", cache_info_k_virt_addr);
 
 		if (start_measure() != 0)
 			pr_err("Something wrong with the cache performance measurement!");
@@ -577,7 +577,8 @@ static u32 utils_apicid(void)
 
 static int curr_process_cpu(void)
 {
-	u32 i = 0, cpu = 0xFFFF, apicid = 0;
+	u32 apicid = 0;
+	int i = 0, cpu = 0xFFFF;
 
 	apicid = utils_apicid();
 	for_each_online_cpu(i) {
@@ -685,6 +686,8 @@ static int tcc_parse_ptct(void)
 	struct psram *p_tmp_psram;
 	struct tcc_ptct_compatibility *compatibility;
 	u64 l2_start, l2_end, l3_start, l3_end;
+	void *errlog_buff = NULL;
+	u32 i = 0;
 
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 
@@ -745,8 +748,18 @@ static int tcc_parse_ptct(void)
 			entry_errlog_v2 = (struct tcc_ptct_errlog_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
 			erraddr = ((u64)(entry_errlog_v2->erraddr_hi) << 32) | entry_errlog_v2->erraddr_lo;
 			errsize = entry_errlog_v2->errsize;
-			dprintk("erraddr   @ %016llx\n", erraddr);
-			dprintk("errsize   @ %08x\n", errsize);
+			if (errsize > 0) {
+				errlog_buff = memremap(erraddr, errsize, MEMREMAP_WB);
+				if (!errlog_buff)
+					pr_err("System error. Fail to map this errlog kernel address.");
+				else {
+					pr_err("errlog_addr   @ %016llx\n", erraddr);
+					pr_err("errlog_size   @ %08x\n", errsize);
+					for (i = 0; i < errsize; i += sizeof(int))
+						pr_err("%08x\n", ((u32 *)errlog_buff)[i/sizeof(int)]);
+					memunmap(errlog_buff);
+				}
+			}
 		}
 
 		offset += entry_size / sizeof(u32);
@@ -1072,8 +1085,9 @@ struct mem_s {
 	void *vaddr;
 	size_t size;
 };
+static void clear_mem(void *info);
 
-void clear_mem(void *info)
+static void clear_mem(void *info)
 {
 	struct mem_s *mem = (struct mem_s *) info;
 
@@ -1282,7 +1296,6 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	u64 register_phyaddr;
 	void *register_data = NULL;
 	void *errlog_buff = NULL;
-	u32 i = 0;
 
 	int cpu, testmask = 0;
 
@@ -1477,15 +1490,10 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 			pr_err("cannot map this errlog address");
 			return -ENOMEM;
 		}
-
-		for (i = 0; ((i < (errsize/sizeof(int))) && (tccdbg == 1)); i++)
-			pr_err("%08x\t", ((u32 *)errlog_buff)[i]);
-
 		ret = copy_to_user((u32 *)arg, errlog_buff, errsize);
 		memunmap(errlog_buff);
 		if (ret != 0)
 			return -EFAULT;
-
 		break;
 	default:
 		return -ENOIOCTLCMD;
-- 
2.25.1

