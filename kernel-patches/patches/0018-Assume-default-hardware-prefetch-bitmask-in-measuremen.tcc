From d8741d2eb8d060ba45767f1c753f81fb6cf8fbce Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 11 Feb 2022 00:15:14 +0800
Subject: [PATCH 18/22] Assume default hardware prefetch bitmask in measurement
 function.

Most platforms supporting tcc use same hardware prefetch bitmask,
only a few uses different bitmask. With this change, no need to
patch for every new platform.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 170 +++++++++++++--------------------------
 drivers/tcc/tcc_buffer.h | 125 ++++++++++------------------
 2 files changed, 101 insertions(+), 194 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index 0e584e4e65a6..b3d19b4caacf 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -55,26 +55,26 @@
 
 #define pr_fmt(fmt) "TCC Buffer: " fmt
 
-#include <linux/module.h>
-#include <linux/moduleparam.h>
-#include <linux/version.h>
-#include <linux/init.h>
-#include <linux/kernel.h>
-#include <linux/proc_fs.h>
-#include <linux/uaccess.h>
-#include <linux/slab.h>
-#include <linux/io.h>
-#include <linux/sched.h>
-#include <linux/kthread.h>
 #include <asm/cacheflush.h>
 #include <asm/intel-family.h>
-#include <asm/perf_event.h>
 #include <asm/nops.h>
+#include <asm/perf_event.h>
 #include <linux/acpi.h>
-#include <linux/smp.h>
+#include <linux/init.h>
+#include <linux/io.h>
+#include <linux/kernel.h>
+#include <linux/kthread.h>
 #include <linux/list.h>
 #include <linux/mm.h>
+#include <linux/module.h>
+#include <linux/moduleparam.h>
+#include <linux/proc_fs.h>
+#include <linux/sched.h>
 #include <linux/seq_file.h>
+#include <linux/slab.h>
+#include <linux/smp.h>
+#include <linux/uaccess.h>
+#include <linux/version.h>
 #include "tcc_buffer.h"
 
 /*
@@ -117,30 +117,29 @@ MODULE_PARM_DESC(strict_affinity_check, "Check affinity of buffer request");
 #define FORMAT_V2                 2
 
 enum PTCT_ENTRY_TYPE {
-	PTCT_PTCD_LIMITS             = 0x00000001,
-	PTCT_PTCM_BINARY             = 0x00000002,
-	PTCT_WRC_L3_WAYMASK          = 0x00000003,
-	PTCT_GT_L3_WAYMASK           = 0x00000004,
-	PTCT_PESUDO_SRAM             = 0x00000005,
-	PTCT_STREAM_DATAPATH         = 0x00000006,
-	PTCT_TIMEAWARE_SUBSYSTEMS    = 0x00000007,
-	PTCT_REALTIME_IOMMU          = 0x00000008,
-	PTCT_MEMORY_HIERARCHY_LATENCY = 0x00000009,
+	PTCT_PTCD_LIMITS = 1,
+	PTCT_PTCM_BINARY,
+	PTCT_WRC_L3_WAYMASK,
+	PTCT_GT_L3_WAYMASK,
+	PTCT_PESUDO_SRAM,
+	PTCT_STREAM_DATAPATH,
+	PTCT_TIMEAWARE_SUBSYSTEMS,
+	PTCT_REALTIME_IOMMU,
+	PTCT_MEMORY_HIERARCHY_LATENCY,
 	PTCT_ENTRY_TYPE_NUMS
 };
 
 enum PTCT_V2_ENTRY_TYPE {
-	PTCT_V2_COMPATIBILITY        = 0x00000000,
-	PTCT_V2_RTCD_LIMIT           = 0x00000001,
-	PTCT_V2_CRL_BINARY           = 0x00000002,
-	PTCT_V2_IA_WAYMASK           = 0x00000003,
-	PTCT_V2_WRC_WAYMASK          = 0x00000004,
-	PTCT_V2_GT_WAYMASK           = 0x00000005,
-	PTCT_V2_SSRAM_WAYMASK        = 0x00000006,
-	PTCT_V2_SSRAM                = 0x00000007,
-	PTCT_V2_MEMORY_HIERARCHY_LATENCY = 0x00000008,
-	PTCT_V2_ERROR_LOG_ADDRESS    = 0x00000009,
-
+	PTCT_V2_COMPATIBILITY = 0,
+	PTCT_V2_RTCD_LIMIT,
+	PTCT_V2_CRL_BINARY,
+	PTCT_V2_IA_WAYMASK,
+	PTCT_V2_WRC_WAYMASK,
+	PTCT_V2_GT_WAYMASK,
+	PTCT_V2_SSRAM_WAYMASK,
+	PTCT_V2_SSRAM,
+	PTCT_V2_MEMORY_HIERARCHY_LATENCY,
+	PTCT_V2_ERROR_LOG_ADDRESS,
 	PTCT_V2_ENTRY_TYPE_NUMS
 };
 
@@ -248,11 +247,11 @@ static const struct tcc_registers_wl_s tcc_registers_wl_tglu[] = {
 	{ 0xFEDA0000, 0x0A78},
 	{ 0xFEDC0000, 0x6F08},
 	{ 0xFEDC0000, 0x6F10},
-	{ 0xFEDC0000, 0x6F00}
+	{ 0xFEDC0000, 0x6F00},
 };
 
 static const struct tcc_registers_wl_s tcc_registers_wl_tglh[] = {
-	{ 0xFEDA0000, 0x0A78}
+	{ 0xFEDA0000, 0x0A78},
 };
 
 #define MAXDEVICENODE 250
@@ -267,39 +266,24 @@ static u32 tcc_init;
 static u32 ptct_format = FORMAT_V1;
 DEFINE_MUTEX(tccbuffer_mutex);
 static int tcc_errlog_show(struct seq_file *m, void *v);
-/****************************************************************************/
-/*These MACROs may not yet defined in previous kernel version*/
-#ifndef INTEL_FAM6_ALDERLAKE
-#define INTEL_FAM6_ALDERLAKE   0x97
-#endif
-#ifndef INTEL_FAM6_ALDERLAKE_L
-#define INTEL_FAM6_ALDERLAKE_L 0x9A
-#endif
-#ifndef INTEL_FAM6_RAPTOR_LAKE
-#define INTEL_FAM6_RAPTOR_LAKE 0xB7
-#endif
-
 static void *cache_info_k_virt_addr;
-
 struct cache_info_s {
-	u64 phy_addr;           // in: psram physical address
-	u32 cache_level;        // in: cache level, used to determing return l2 hit/miss or l3 hit/miss
-	u32 cache_size;         // in: cache size to test
-	u32 cacheline_size;     // in: cache_line size
-	u32 testcase;           // in: which test case to conduct (sequential or random)
-	u64 l1_hits;            // out:
-	u64 l1_miss;            // out:
-	u64 l2_hits;            // out:
-	u64 l2_miss;            // out:
-	u64 l3_hits;            // out:
-	u64 l3_miss;            // out:
+	u64 phy_addr;
+	u32 cache_level;
+	u32 cache_size;
+	u32 cacheline_size;
+	u32 testcase;
+	u64 l1_hits;
+	u64 l1_miss;
+	u64 l2_hits;
+	u64 l2_miss;
+	u64 l3_hits;
+	u64 l3_miss;
 };
-
 static struct cache_info_s cache_info_k = {0,};
 #define BUFSIZE  sizeof(struct cache_info_s)
 static struct proc_dir_entry *ent;
 static u64 hardware_prefetcher_disable_bits;
-
 static u64 get_hardware_prefetcher_disable_bits(void);
 static inline void tcc_perf_wrmsrl(u32 msr, u64 val);
 static int start_measure(void);
@@ -318,25 +302,14 @@ static u64 get_hardware_prefetcher_disable_bits(void)
 
 	dprintk("x86_model 0x%02X\n", (u32)(boot_cpu_data.x86_model));
 	switch (boot_cpu_data.x86_model) {
-	case INTEL_FAM6_TIGERLAKE:
-	case INTEL_FAM6_TIGERLAKE_L:
-	case INTEL_FAM6_ALDERLAKE:
-	case INTEL_FAM6_ALDERLAKE_L:
-	case INTEL_FAM6_ICELAKE:
-	case INTEL_FAM6_ICELAKE_L:
-	case INTEL_FAM6_ICELAKE_X:
-	case INTEL_FAM6_ICELAKE_D:
-	case INTEL_FAM6_RAPTOR_LAKE:
-	return 0xF;
 	case INTEL_FAM6_ATOM_GOLDMONT:
 	case INTEL_FAM6_ATOM_GOLDMONT_PLUS:
 	return 0x5;
 	case INTEL_FAM6_ATOM_TREMONT:
 	return 0x1F;
 	default:
-		pr_err("Didn't catch CPU model in setting prefetcher disable bits.\n");
+	return 0xF;
 	}
-	return 0;
 }
 
 static inline void tcc_perf_wrmsrl(u32 reg, u64 data)
@@ -346,53 +319,26 @@ static inline void tcc_perf_wrmsrl(u32 reg, u64 data)
 
 static int tcc_perf_fn(void)
 {
+	u32 cacheline_len = 0, cacheread_size = 0;
 	u64 perf_l1h = 0, perf_l1m = 0, msr_bits_l1h = 0, msr_bits_l1m = 0;
 	u64 perf_l2h = 0, perf_l2m = 0, msr_bits_l2h = 0, msr_bits_l2m = 0;
 	u64 perf_l3h = 0, perf_l3m = 0, msr_bits_l3h = 0, msr_bits_l3m = 0;
-	u64 i;
-
-	u32 cacheline_len;
-	u32 cacheread_size;
+	u64 i = 0, start = 0, end = 0;
 	void *cachemem_k;
 
-	u64 start, end;
-
 	pr_err("In %s\n", __func__);
-
-	switch (boot_cpu_data.x86_model) {
-	case INTEL_FAM6_ATOM_GOLDMONT:
-	case INTEL_FAM6_ATOM_GOLDMONT_PLUS:
-	case INTEL_FAM6_ATOM_TREMONT:
-	case INTEL_FAM6_TIGERLAKE:
-	case INTEL_FAM6_TIGERLAKE_L:
-	case INTEL_FAM6_ALDERLAKE:
-	case INTEL_FAM6_ALDERLAKE_L:
-	case INTEL_FAM6_ICELAKE:
-	case INTEL_FAM6_ICELAKE_L:
-	case INTEL_FAM6_ICELAKE_X:
-	case INTEL_FAM6_ICELAKE_D:
-	case INTEL_FAM6_RAPTOR_LAKE:
-	{
-		if (cache_info_k.cache_level == RGN_L2) {
-			msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
-			msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
-			msr_bits_l1h = (MISC_MSR_BITS_COMMON) | (0x1  << 8);
-			msr_bits_l1m = (MISC_MSR_BITS_COMMON) | (0x08 << 8);
-		} else if (cache_info_k.cache_level == RGN_L3) {
-			msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
-			msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
-			msr_bits_l3h = (MISC_MSR_BITS_COMMON) | (0x4  << 8);
-			msr_bits_l3m = (MISC_MSR_BITS_COMMON) | (0x20 << 8);
-		}
-	}
-	break;
-	default:
-		pr_err("Didn't catch this CPU Model in perf_fn()!\n");
-		return -1;
+	if (cache_info_k.cache_level == RGN_L2) {
+		msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
+		msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
+		msr_bits_l1h = (MISC_MSR_BITS_COMMON) | (0x1  << 8);
+		msr_bits_l1m = (MISC_MSR_BITS_COMMON) | (0x08 << 8);
+	} else if (cache_info_k.cache_level == RGN_L3) {
+		msr_bits_l2h = (MISC_MSR_BITS_COMMON) | (0x2  << 8);
+		msr_bits_l2m = (MISC_MSR_BITS_COMMON) | (0x10 << 8);
+		msr_bits_l3h = (MISC_MSR_BITS_COMMON) | (0x4  << 8);
+		msr_bits_l3m = (MISC_MSR_BITS_COMMON) | (0x20 << 8);
 	}
-
 	asm volatile (" cli ");
-
 	__wrmsr(MSR_MISC_FEATURE_CONTROL, hardware_prefetcher_disable_bits, 0x0);
 
 	cachemem_k     = cache_info_k_virt_addr;
diff --git a/drivers/tcc/tcc_buffer.h b/drivers/tcc/tcc_buffer.h
index dc4663a5c555..9c1b03e3b630 100644
--- a/drivers/tcc/tcc_buffer.h
+++ b/drivers/tcc/tcc_buffer.h
@@ -59,12 +59,8 @@
 /* TCC Device Interface */
 #define TCC_BUFFER_NAME  "/tcc/tcc_buffer"
 #define UNDEFINED_DEVNODE 256
-
 #define TCC_REG_MAX_OFFSET 0x100000
-
-/* IOCTL MAGIC number */
 #define IOCTL_TCC_MAGIC   'T'
-
 enum tcc_buf_region_type {
 	RGN_UNKNOWN = 0,
 	RGN_L1,
@@ -76,9 +72,7 @@ enum tcc_buf_region_type {
 };
 
 /*
- * IN:
  * id: pseudo-SRAM region id from which user request for attribute.
- * OUT:
  * latency: delay in clockcycles
  * type: the type of the memory pSRAM region
  * size: total size in byte
@@ -95,10 +89,8 @@ struct tcc_buf_mem_config_s {
 };
 
 /*
- * IN:
  * id: pseudo-SRAM region id, from which user request for buffer
  * size: buffer size (byte).
- * OUT:
  * devnode: driver returns device node to user
  */
 struct tcc_buf_mem_req_s {
@@ -115,67 +107,67 @@ struct tcc_registers_wl_s {
 
 /* enum type for tcc_register structure */
 enum TCC_REG_PHASE {
-	TCC_PRE_MEM        = 0x00000000,
-	TCC_POST_MEM       = 0x00000001,
-	TCC_LATE_INIT      = 0x00000002,
+	TCC_PRE_MEM = 0,
+	TCC_POST_MEM,
+	TCC_LATE_INIT,
 	TCC_INVALID_PHASE  = 0xFFFFFFFF
 };
 
 enum TCC_REG_FORMAT {
-	TCC_MMIO32         = 0x00000000,
-	TCC_MMIO64         = 0x00000001,
-	TCC_MSR            = 0x00000002,
-	TCC_IOSFSB         = 0x00000003,
-	TCC_MAILBOX        = 0x00000004,
+	TCC_MMIO32 = 0,
+	TCC_MMIO64,
+	TCC_MSR,
+	TCC_IOSFSB,
+	TCC_MAILBOX,
 	TCC_INVALID_FORMAT = 0xFFFFFFFF
 };
 
 enum TCC_IOSFSB_NETWORK {
-	TCC_IOSFSB_CPU     = 0x00000000,
-	TCC_IOSFSB_PCH     = 0x00000001
+	TCC_IOSFSB_CPU = 0,
+	TCC_IOSFSB_PCH
 };
 
 enum TCC_MAILBOX_TYPE {
-	TCC_MAILBOX_SA     = 0x00000000,
-	TCC_MAILBOX_MSR    = 0x00000001
+	TCC_MAILBOX_SA = 0,
+	TCC_MAILBOX_MSR
 };
 
 /* Support mmio32 and mmio64 formats only. */
 struct tcc_register_s {
-	enum TCC_REG_PHASE e_phase;		/* IN: enum'd above */
-	enum TCC_REG_FORMAT e_format;	/* IN: enum'd above, determines which structure format to use */
+	enum TCC_REG_PHASE e_phase;
+	enum TCC_REG_FORMAT e_format;
 	union {
 		struct {
-			u32 base;		/* IN: ECAM format B:D:F:R of BAR (add this to ECAM_BASE) */
-			u32 addr;		/* IN: offset from BAR */
-			u32 mask;		/* IN: data bit-mask (1's are valid) */
-			u32 data;		/* OUT: data value */
+			u32 base;
+			u32 addr;
+			u32 mask;
+			u32 data;
 		} mmio32;
 		struct {
-			u64 base;		/* IN: ECAM format B:D:F:R of BAR (add this to ECAM_BASE) */
-			u64 addr;		/* IN: offset from BAR */
-			u64 mask;		/* IN: data bit-mask (1's are valid) */
-			u64 data;		/* OUT: data value */
+			u64 base;
+			u64 addr;
+			u64 mask;
+			u64 data;
 		} mmio64;
 		struct {
-			u32 apic_id;	/* IN: APIC ID of logical CPU corresponding to this MSR value */
-			u32 addr;		/* IN: ECX value */
-			u64 mask;		/* IN: EDX:EAX data bit-mask (1's are valid) */
-			u64 data;		/* OUT: EDX:EAX data value */
+			u32 apic_id;
+			u32 addr;
+			u64 mask;
+			u64 data;
 		} msr;
 		struct {
-			enum TCC_IOSFSB_NETWORK e_iosfsb_network; /* IN: which IOSFSB network to use */
-			u8 port;		/* IN: IOSFSB Port ID */
-			u8 type;		/* IN: IOSFSB Register Type (Command) */
-			u32 addr;		/* IN: register address */
-			u32 mask;		/* IN: data bit-mask (1's are valid) */
-			u32 data;		/* IN: data value */
+			enum TCC_IOSFSB_NETWORK e_iosfsb_network;
+			u8 port;
+			u8 type;
+			u32 addr;
+			u32 mask;
+			u32 data;
 		} iosfsb;
 		struct {
-			enum TCC_MAILBOX_TYPE e_type;	/* IN: Mailbox type */
-			u32 addr;		/* IN: register address */
-			u32 mask;		/* IN: data bit-mask (1's are valid) */
-			u32 data;		/* OUT: data value */
+			enum TCC_MAILBOX_TYPE e_type;
+			u32 addr;
+			u32 mask;
+			u32 data;
 		} mailbox;
 	} info;
 };
@@ -198,44 +190,13 @@ enum ioctl_index {
 	IOCTL_TCC_MEASURE_USER_END
 };
 
-/*
- * User to get pseudo-SRAM region counts
- */
-#define TCC_GET_REGION_COUNT _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGION_COUNT, unsigned int *)
-
-/*
- * User to get memory config of selected region
- */
-#define TCC_GET_MEMORY_CONFIG _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_MEMORY_CONFIG, struct tcc_buf_mem_config_s *)
-
-/*
- * User to query PTCT size
- */
-#define TCC_QUERY_PTCT_SIZE _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_QUERY_PTCT_SIZE, unsigned int *)
-
-/*
- * User to get PTCT data
- */
-#define TCC_GET_PTCT _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_PTCT, unsigned int *)
-
-/*
- * User to request pseudo-SRAM buffer from selected region
- */
-#define TCC_REQ_BUFFER _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_REQ_BUFFER, struct tcc_buf_mem_req_s *)
-
-/*
- * User to get TCC Register
- */
-#define TCC_GET_REGISTER _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGISTER, struct tcc_register_s *)
-
-/*
- * User to get TCC Error Log Buffer
- */
-#define TCC_GET_ERRLOG _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_ERRLOG, unsigned int *)
-
-/*
- * User to trigger test case on cache
- */
+#define TCC_GET_REGION_COUNT       _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGION_COUNT, unsigned int *)
+#define TCC_GET_MEMORY_CONFIG      _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_MEMORY_CONFIG, struct tcc_buf_mem_config_s *)
+#define TCC_QUERY_PTCT_SIZE        _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_QUERY_PTCT_SIZE, unsigned int *)
+#define TCC_GET_PTCT               _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_PTCT, unsigned int *)
+#define TCC_REQ_BUFFER             _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_REQ_BUFFER, struct tcc_buf_mem_req_s *)
+#define TCC_GET_REGISTER           _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGISTER, struct tcc_register_s *)
+#define TCC_GET_ERRLOG             _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_ERRLOG, unsigned int *)
 #define TCC_MEASURE_CACHE          _IOW(IOCTL_TCC_MAGIC, IOCTL_TCC_MEASURE_CACHE, unsigned int)
 #define TCC_MEASURE_USER_START     _IO(IOCTL_TCC_MAGIC, IOCTL_TCC_MEASURE_USER_START)
 #define TCC_MEASURE_USER_END       _IO(IOCTL_TCC_MAGIC, IOCTL_TCC_MEASURE_USER_END)
-- 
2.25.1

