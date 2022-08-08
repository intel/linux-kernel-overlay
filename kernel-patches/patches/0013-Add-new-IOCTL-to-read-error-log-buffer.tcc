From 58b2ab9a67156a1b56f87da4f83b4eca1c3bdc70 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Thu, 20 May 2021 17:57:47 +0800
Subject: [PATCH 13/23] Add new IOCTL to read error log buffer.

Include cache perf measurement; also include cpu affinity check
when requesting buffer.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 394 ++++++++++++++++++++++++++++++++++++++-
 drivers/tcc/tcc_buffer.h |  23 ++-
 2 files changed, 408 insertions(+), 9 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index d55653a107c4..e06f2ec466b7 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -55,15 +55,25 @@
 
 #define pr_fmt(fmt) "TCC Buffer: " fmt
 
-#include <linux/acpi.h>
-#include <linux/kernel.h>
-#include <linux/smp.h>
-#include <linux/list.h>
-#include <linux/mm.h>
 #include <linux/module.h>
+#include <linux/moduleparam.h>
 #include <linux/version.h>
 #include <linux/init.h>
+#include <linux/kernel.h>
+#include <linux/proc_fs.h>
+#include <linux/uaccess.h>
+#include <linux/slab.h>
+#include <linux/io.h>
+#include <linux/sched.h>
+#include <linux/kthread.h>
+#include <asm/cacheflush.h>
 #include <asm/intel-family.h>
+#include <asm/perf_event.h>
+#include <asm/nops.h>
+#include <linux/acpi.h>
+#include <linux/smp.h>
+#include <linux/list.h>
+#include <linux/mm.h>
 #include "tcc_buffer.h"
 
 /*
@@ -81,6 +91,9 @@
 static int tccdbg;
 module_param(tccdbg, int, 0644);
 MODULE_PARM_DESC(tccdbg, "Turn on/off trace");
+static int strict_affinity_check = 1;
+module_param(strict_affinity_check, int, 0644);
+MODULE_PARM_DESC(strict_affinity_check, "Check affinity of buffer request");
 #define dprintk(fmt, arg...) \
 	do { if (tccdbg) pr_info(fmt, ##arg); } while (0)
 
@@ -187,6 +200,12 @@ struct tcc_ptct_compatibility {
 	u32 rtcd_version_minor;
 };
 
+struct tcc_ptct_errlog_v2 {
+	u32 erraddr_lo;
+	u32 erraddr_hi;
+	u32 errsize;
+};
+
 struct memory_slot_info {
 	u64 paddr;
 	void *vaddr;
@@ -225,10 +244,325 @@ DECLARE_BITMAP(tcc_buffer_device_minor_avail, MAXDEVICENODE);
 static struct class *tcc_buffer_class;
 static struct acpi_table_header *acpi_ptct_tbl;
 static struct tcc_config *p_tcc_config;
+static u64 erraddr;
+static u32 errsize;
 static u32 tcc_init;
 static u32 ptct_format = FORMAT_V1;
 DEFINE_MUTEX(tccbuffer_mutex);
 
+/****************************************************************************/
+/*These MACROs may not yet defined in previous kernel version*/
+#ifndef INTEL_FAM6_ALDERLAKE
+#define INTEL_FAM6_ALDERLAKE   0x97
+#endif
+#ifndef INTEL_FAM6_ALDERLAKE_L
+#define INTEL_FAM6_ALDERLAKE_L 0x9A
+#endif
+
+void *cache_info_k_virt_addr;
+
+struct cache_info_s {
+	u64 phy_addr;           // in: psram physical address
+	u32 cache_level;        // in: cache level, used to determing return l2 hit/miss or l3 hit/miss
+	u32 cache_size;         // in: cache size to test
+	u32 cacheline_size;     // in: cache_line size
+	u32 testcase;           // in: which test case to conduct (sequential or random)
+	u64 l1_hits;            // out:
+	u64 l1_miss;            // out:
+	u64 l2_hits;            // out:
+	u64 l2_miss;            // out:
+	u64 l3_hits;            // out:
+	u64 l3_miss;            // out:
+};
+
+struct cache_info_s cache_info_k = {0,};
+#define BUFSIZE  sizeof(struct cache_info_s)
+static struct proc_dir_entry *ent;
+static u64 hardware_prefetcher_disable_bits;
+
+static u64 get_hardware_prefetcher_disable_bits(void);
+static inline void tcc_perf_wrmsrl(u32 msr, u64 val);
+static int tcc_perf_fn(void);
+
+#define MSR_MISC_FEATURE_CONTROL    0x000001a4
+#define READ_BYTE_SIZE              64
+#define MISC_MSR_BITS_COMMON        ((0x52ULL << 16) | 0xd1)
+#define MISC_MSR_BITS_ALL_CLEAR     0x0
+#define PERFMON_EVENTSEL_BITMASK    (~(0x40ULL << 16))
+
+static u64 get_hardware_prefetcher_disable_bits(void)
+{
+	if (boot_cpu_data.x86_vendor != X86_VENDOR_INTEL || boot_cpu_data.x86 != 6)
+		return 0;
+
+	dprintk("x86_model 0x%02X\n", (u32)(boot_cpu_data.x86_model));
+	switch (boot_cpu_data.x86_model) {
+	case INTEL_FAM6_TIGERLAKE:
+	case INTEL_FAM6_TIGERLAKE_L:
+	case INTEL_FAM6_ALDERLAKE:
+	case INTEL_FAM6_ALDERLAKE_L:
+	case INTEL_FAM6_ICELAKE:
+	case INTEL_FAM6_ICELAKE_L:
+	case INTEL_FAM6_ICELAKE_X:
+	case INTEL_FAM6_ICELAKE_D:
+	return 0xF;
+	case INTEL_FAM6_ATOM_GOLDMONT:
+	case INTEL_FAM6_ATOM_GOLDMONT_PLUS:
+	return 0x5;
+	case INTEL_FAM6_ATOM_TREMONT:
+	return 0x1F;
+	}
+	pr_err("Didn't catch CPU model in setting prefetcher disable bits.\n");
+	return 0;
+}
+
+static inline void tcc_perf_wrmsrl(u32 reg, u64 data)
+{
+	__wrmsr(reg, (u32)(data & 0xffffffffULL), (u32)(data >> 32));
+}
+
+static int tcc_perf_fn(void)
+{
+	u64 perf_l1h = 0, perf_l1m = 0, msr_bits_l1h = 0, msr_bits_l1m = 0;
+	u64 perf_l2h = 0, perf_l2m = 0, msr_bits_l2h = 0, msr_bits_l2m = 0;
+	u64 perf_l3h = 0, perf_l3m = 0, msr_bits_l3h = 0, msr_bits_l3m = 0;
+	u64 i;
+
+	u32 cacheline_len;
+	u32 cacheread_size;
+	void *cachemem_k;
+
+	u64 start, end;
+
+	pr_err("In %s\n", __func__);
+
+	switch (boot_cpu_data.x86_model) {
+	case INTEL_FAM6_ATOM_GOLDMONT:
+	case INTEL_FAM6_ATOM_GOLDMONT_PLUS:
+	case INTEL_FAM6_ATOM_TREMONT:
+	case INTEL_FAM6_TIGERLAKE:
+	case INTEL_FAM6_TIGERLAKE_L:
+	case INTEL_FAM6_ALDERLAKE:
+	case INTEL_FAM6_ALDERLAKE_L:
+	case INTEL_FAM6_ICELAKE:
+	case INTEL_FAM6_ICELAKE_L:
+	case INTEL_FAM6_ICELAKE_X:
+	case INTEL_FAM6_ICELAKE_D:
+	{
+		if (cache_info_k.cache_level == RGN_L2) {
+			msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
+			msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
+			msr_bits_l1h = (MISC_MSR_BITS_COMMON) | (0x1  << 8);
+			msr_bits_l1m = (MISC_MSR_BITS_COMMON) | (0x08 << 8);
+		} else if (cache_info_k.cache_level == RGN_L3) {
+			msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
+			msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
+			msr_bits_l3h = (MISC_MSR_BITS_COMMON) | (0x4  << 8);
+			msr_bits_l3m = (MISC_MSR_BITS_COMMON) | (0x20 << 8);
+		}
+	}
+	break;
+	default:
+		pr_err("Didn't catch this CPU Model in perf_fn()!\n");
+		goto out;
+	}
+
+	asm volatile (" cli ");
+
+	__wrmsr(MSR_MISC_FEATURE_CONTROL, hardware_prefetcher_disable_bits, 0x0);
+
+	cachemem_k     = cache_info_k_virt_addr;
+	cacheread_size = cache_info_k.cache_size;
+	cacheline_len  = cache_info_k.cacheline_size;
+
+	/* Disable events and reset counters. 4 pairs. */
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, MISC_MSR_BITS_ALL_CLEAR);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 1, MISC_MSR_BITS_ALL_CLEAR);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 2, MISC_MSR_BITS_ALL_CLEAR);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 3, MISC_MSR_BITS_ALL_CLEAR);
+
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_PERFCTR0, MISC_MSR_BITS_ALL_CLEAR);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_PERFCTR0 + 1, MISC_MSR_BITS_ALL_CLEAR);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_PERFCTR0 + 2, MISC_MSR_BITS_ALL_CLEAR);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_PERFCTR0 + 3, MISC_MSR_BITS_ALL_CLEAR);
+
+	/* Set and enable L3 counters if msr_bits_l3h is prepared */
+	if (msr_bits_l3h > 0) {
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 2, msr_bits_l3h);
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 3, msr_bits_l3m);
+	}
+
+	/* Set and enable L1 counters if msr_bits_l1h is prepared */
+	if (msr_bits_l1h > 0) {
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 2, msr_bits_l1h);
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 3, msr_bits_l1m);
+	}
+
+	/* Set and enable the L2 counters, which is always preapred */
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, msr_bits_l2h);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 1, msr_bits_l2m);
+
+	/* capture the timestamp at the meantime while hitting buffer */
+	start = rdtsc_ordered();
+	for (i = 0; i < cacheread_size; i += cacheline_len) {
+		asm volatile("mov (%0,%1,1), %%eax\n\t"
+				:
+				: "r" (cachemem_k), "r" (i)
+				: "%eax", "memory");
+	}
+	end = rdtsc_ordered();
+
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0, msr_bits_l2h & PERFMON_EVENTSEL_BITMASK);
+	tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 1, msr_bits_l2m & PERFMON_EVENTSEL_BITMASK);
+
+	if (msr_bits_l3h > 0) {
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 2, msr_bits_l3h & PERFMON_EVENTSEL_BITMASK);
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 3, msr_bits_l3m & PERFMON_EVENTSEL_BITMASK);
+	}
+
+	if (msr_bits_l1h > 0) {
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 2, msr_bits_l1h & PERFMON_EVENTSEL_BITMASK);
+		tcc_perf_wrmsrl(MSR_ARCH_PERFMON_EVENTSEL0 + 3, msr_bits_l1m & PERFMON_EVENTSEL_BITMASK);
+	}
+
+	perf_l2h = native_read_pmc(0);
+	perf_l2m = native_read_pmc(1);
+
+	if (msr_bits_l3h > 0) {
+		perf_l3h = native_read_pmc(2);
+		perf_l3m = native_read_pmc(3);
+	}
+
+	if (msr_bits_l1h > 0) {
+		perf_l1h = native_read_pmc(2);
+		perf_l1m = native_read_pmc(3);
+	}
+
+	wrmsr(MSR_MISC_FEATURE_CONTROL, 0x0, 0x0);
+	asm volatile (" sti ");
+
+	if (cache_info_k.cache_level == RGN_L2) {
+		pr_err("PERFMARK perf_l2h=%llu perf_l2m=%llu", perf_l2h, perf_l2m);
+		pr_err("PERFMARK perf_l1h=%llu perf_l1m=%llu", perf_l1h, perf_l1m);
+		cache_info_k.l1_hits = perf_l1h;
+		cache_info_k.l1_miss = perf_l1m;
+		cache_info_k.l2_hits = perf_l2h;
+		cache_info_k.l2_miss = perf_l2m;
+		cache_info_k.l3_hits = 0;
+		cache_info_k.l3_miss = 0;
+	} else if (cache_info_k.cache_level == RGN_L3) {
+		pr_err("PERFMARK perf_l2h=%llu perf_l2m=%llu", perf_l2h, perf_l2m);
+		pr_err("PERFMARK perf_l3h=%llu perf_l3m=%llu", perf_l3h, perf_l3m);
+		cache_info_k.l1_hits = 0;
+		cache_info_k.l1_miss = 0;
+		cache_info_k.l2_hits = perf_l2h;
+		cache_info_k.l2_miss = perf_l2m;
+		cache_info_k.l3_hits = perf_l3h;
+		cache_info_k.l3_miss = perf_l3m;
+	}
+	pr_err("start: %lld\n", start);
+	pr_err("end:   %lld\n", end);
+	pr_err("delta: %lld\n", (end-start));
+
+out:
+	return 0;
+}
+
+int start_measure(void)
+{
+	int ret = -1;
+
+	hardware_prefetcher_disable_bits = get_hardware_prefetcher_disable_bits();
+
+	switch (cache_info_k.testcase) {
+	case TEST_CACHE_PERF:
+		ret = tcc_perf_fn();
+	break;
+	default:
+		goto out;
+	}
+
+	if (ret < 0)
+		goto out;
+	ret = 0;
+out:
+	return ret;
+
+}
+
+
+static ssize_t set_test_setup(struct file *file, const char __user *ubuf, size_t count, loff_t *ppos)
+{
+	if (count > BUFSIZE)
+		return -EFAULT;
+
+	if (copy_from_user((char *)(&cache_info_k), ubuf, BUFSIZE))
+		return -EFAULT;
+
+	switch (cache_info_k.testcase) {
+	case TEST_CACHE_PERF:
+	{
+		pr_err("cache_info_k.phy_addr        0x%016llx\n", cache_info_k.phy_addr);
+		pr_err("cache_info_k.cache_level     %d\n", cache_info_k.cache_level);
+		pr_err("cache_info_k.cache_size      0x%08x\n", cache_info_k.cache_size);
+		pr_err("cache_info_k.cacheline_size  %d\n", cache_info_k.cacheline_size);
+		pr_err("cache_info_k.testcase        %d\n", cache_info_k.testcase);
+
+		cache_info_k_virt_addr = memremap(cache_info_k.phy_addr, cache_info_k.cache_size, MEMREMAP_WB);
+
+		if (cache_info_k_virt_addr == NULL)
+			pr_err("cache_info_k_virt_addr == NULL\n");
+		else
+			pr_err("cache_info_k_virt_addr	0x%016llx\n", (u64)(cache_info_k_virt_addr));
+
+		if (start_measure() != 0)
+			pr_err("Something wrong with the cache performance measurement!");
+
+		memunmap(cache_info_k_virt_addr);
+		cache_info_k_virt_addr = NULL;
+	}
+	break;
+	default:
+		pr_err("This testcase is not handled yet.\n");
+	return -EFAULT;
+	}
+
+	return BUFSIZE;
+}
+
+static ssize_t get_test_result(struct file *file, char __user *ubuf, size_t count, loff_t *ppos)
+{
+	if (count < BUFSIZE)
+		return 0;
+
+	switch (cache_info_k.testcase) {
+	case TEST_CACHE_PERF:
+		if (copy_to_user(ubuf, (char *)(&cache_info_k), BUFSIZE))
+			return -EFAULT;
+	break;
+	default:
+		pr_err("This testcase is not handled yet.\n");
+	return -EFAULT;
+	}
+
+	return BUFSIZE;
+}
+
+#if KERNEL_VERSION(5, 6, 1) > LINUX_VERSION_CODE
+const struct file_operations testops = {
+	.owner = THIS_MODULE,
+	.read = get_test_result,
+	.write = set_test_setup,
+};
+#else
+const struct proc_ops testops = {
+	.proc_read = get_test_result,
+	.proc_write = set_test_setup,
+};
+#endif
+
+/****************************************************************************/
+
 #define CPUID_LEAF_EXT_TOPO_ENUM 0x0B
 #define CPUID_0B_SUBLEAF_SMT     0
 #define CPUID_0B_SUBLEAF_CORE    1
@@ -345,6 +679,7 @@ static int tcc_parse_ptct(void)
 	struct tcc_ptct_mhlatency_v2 *entry_mhl_v2;
 	struct tcc_ptct_psram_v2 *entry_psram_v2;
 	struct tcc_ptct_sram_waymask_v2 *entry_sram_waymask_v2;
+	struct tcc_ptct_errlog_v2 *entry_errlog_v2;
 	static struct psram *p_new_psram;
 	static struct memory_slot_info *p_memslot;
 	struct psram *p_tmp_psram;
@@ -383,7 +718,7 @@ static int tcc_parse_ptct(void)
 
 	dprintk("ptct_format = %s\n", (ptct_format == FORMAT_V1) ? "FORMAT_V1":"FORMAT_V2");
 
-	/* Parse and save memory latency */
+	/* Parse and save memory latency and errer log buffer address */
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 	offset = ACPI_HEADER_SIZE;
 	tbl_swap = tbl_swap + offset;
@@ -406,6 +741,12 @@ static int tcc_parse_ptct(void)
 				p_tcc_config->l2_latency = entry_mhl_v2->latency;
 			else if (entry_mhl_v2->cache_level == RGN_L3)
 				p_tcc_config->l3_latency = entry_mhl_v2->latency;
+		} else if ((ptct_format == FORMAT_V2) && (entry_type == PTCT_V2_ERROR_LOG_ADDRESS)) {
+			entry_errlog_v2 = (struct tcc_ptct_errlog_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
+			erraddr = ((u64)(entry_errlog_v2->erraddr_hi) << 32) | entry_errlog_v2->erraddr_lo;
+			errsize = entry_errlog_v2->errsize;
+			dprintk("erraddr   @ %016llx\n", erraddr);
+			dprintk("errsize   @ %08x\n", errsize);
 		}
 
 		offset += entry_size / sizeof(u32);
@@ -823,8 +1164,11 @@ static int tcc_buffer_open(struct inode *i, struct file *f)
 		return -EINVAL;
 	}
 	testmask = cpumask_test_cpu(cpu, &(p_memslot->cpumask));
-	if (testmask == 0)
+	if (testmask == 0) {
 		pr_err("OPEN(): psram device is open from non-affinity cpu.\n");
+		if (strict_affinity_check == 1)
+			return -EINVAL;
+	}
 
 	p_memslot->open_count++;
 	dprintk("%s\n", "open()");
@@ -937,6 +1281,8 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	struct tcc_register_s tcc_register;
 	u64 register_phyaddr;
 	void *register_data = NULL;
+	void *errlog_buff = NULL;
+	u32 i = 0;
 
 	int cpu, testmask = 0;
 
@@ -1029,8 +1375,11 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 					testmask = cpumask_test_cpu(cpu, &(p_psram->cpumask));
 			}
 		}
-		if (testmask == 0)
+		if (testmask == 0) {
 			pr_err("psram is requested from non-affinity cpu.\n");
+			if (strict_affinity_check == 1)
+				return -EFAULT;
+		}
 
 		if (req_mem.size & (PAGE_SIZE - 1)) {
 			pr_err("size must be page-aligned!");
@@ -1113,6 +1462,30 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 		if (ret != 0)
 			return -EFAULT;
 
+		break;
+	case TCC_GET_ERRLOG:
+		if ((ptct_format == FORMAT_V1) || (errsize == 0)) {
+			pr_err("ErrLog entry in this version is not valid!");
+			return -EFAULT;
+		}
+		if (NULL == (u32 *)arg) {
+			pr_err("arg from user is nullptr!");
+			return -EINVAL;
+		}
+		errlog_buff = memremap(erraddr, errsize, MEMREMAP_WB);
+		if (!errlog_buff) {
+			pr_err("cannot map this errlog address");
+			return -ENOMEM;
+		}
+
+		for (i = 0; ((i < (errsize/sizeof(int))) && (tccdbg == 1)); i++)
+			pr_err("%08x\t", ((u32 *)errlog_buff)[i]);
+
+		ret = copy_to_user((u32 *)arg, errlog_buff, errsize);
+		memunmap(errlog_buff);
+		if (ret != 0)
+			return -EFAULT;
+
 		break;
 	default:
 		return -ENOIOCTLCMD;
@@ -1210,6 +1583,9 @@ static int __init tcc_buffer_init(void)
 		pr_err("Failed to create character device\n");
 		goto err_device;
 	}
+
+	ent = proc_create("tcc_cache_test", 0660, NULL, &testops);
+
 	tcc_init = 1;
 	p_tcc_config->minor = new_minor;
 
@@ -1235,6 +1611,8 @@ static void __exit tcc_buffer_exit(void)
 		class_destroy(tcc_buffer_class);
 		unregister_chrdev(tcc_buffer_device_major, TCC_BUFFER_NAME);
 		kfree(p_tcc_config);
+
+		proc_remove(ent);
 	}
 	pr_err("exit().\n");
 }
diff --git a/drivers/tcc/tcc_buffer.h b/drivers/tcc/tcc_buffer.h
index 3fe446173fcb..a97d4197959a 100644
--- a/drivers/tcc/tcc_buffer.h
+++ b/drivers/tcc/tcc_buffer.h
@@ -195,13 +195,22 @@ struct tcc_register_s {
 	} info;
 };
 
+enum {
+	TEST_CACHE_PERF = 1,
+	TEST_CACHE_TOTAL_CASES
+};
+
 enum ioctl_index {
 	IOCTL_TCC_GET_REGION_COUNT = 1,
 	IOCTL_TCC_GET_MEMORY_CONFIG,
 	IOCTL_TCC_REQ_BUFFER,
 	IOCTL_TCC_QUERY_PTCT_SIZE,
 	IOCTL_TCC_GET_PTCT,
-	IOCTL_TCC_GET_REGISTER
+	IOCTL_TCC_GET_REGISTER,
+	IOCTL_TCC_GET_ERRLOG,
+	IOCTL_TCC_MEASURE_CACHE = 10,
+	IOCTL_TCC_MEASURE_USER_START,
+	IOCTL_TCC_MEASURE_USER_END
 };
 
 /*
@@ -233,3 +242,15 @@ enum ioctl_index {
  * User to get TCC Register
  */
 #define TCC_GET_REGISTER _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGISTER, struct tcc_register_s *)
+
+/*
+ * User to get TCC Error Log Buffer
+ */
+#define TCC_GET_ERRLOG _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_ERRLOG, unsigned int *)
+
+/*
+ * User to trigger test case on cache
+ */
+#define TCC_MEASURE_CACHE          _IOW(IOCTL_TCC_MAGIC, IOCTL_TCC_MEASURE_CACHE, unsigned int)
+#define TCC_MEASURE_USER_START     _IO(IOCTL_TCC_MAGIC, IOCTL_TCC_MEASURE_USER_START)
+#define TCC_MEASURE_USER_END       _IO(IOCTL_TCC_MAGIC, IOCTL_TCC_MEASURE_USER_END)
-- 
2.25.1

