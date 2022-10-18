From 3beaf553385ac699b9794959a5d29078fef7f744 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Thu, 22 Jul 2021 18:48:46 +0800
Subject: [PATCH 10/23] tcc: update RTCT table parser to support two versions

Reject request if size is not kernel page size aligned;
Clear memory by affinity cpu;
Extend number of devices can allocate on the buffer.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c |  51 +++-
 drivers/tcc/tcc_buffer.c    | 537 ++++++++++++++++++++++++++++++------
 include/acpi/actbl2.h       |  46 ++-
 3 files changed, 546 insertions(+), 88 deletions(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index 2b730274584e..0c8b070b77e3 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1316,6 +1316,10 @@ static inline int acpi_parse_madt_ioapic_entries(void)
 static struct ptct_psram_region ptct_psram_regions[MAX_PSRAM_REGIONS];
 static u32 total_psram_region;
 
+#define ACPI_PTCT_FORMAT_V1      1
+#define ACPI_PTCT_FORMAT_V2      2
+static u32 acpi_ptct_format = ACPI_PTCT_FORMAT_V1;
+
 static inline bool is_TCC_range(u64 start, u64 end)
 {
 	int i;
@@ -1342,13 +1346,32 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 
 	struct acpi_ptct_entry_header *entry;
 	struct acpi_ptct_psram  *psram;
+	struct acpi_ptct_psram_v2  *psram_v2;
+	struct acpi_ptct_compatibility  *compatibility;
 
 	if (!table)
 		return -EINVAL;
 
 	total_length = table->length;
 
-	/* Parse PTCT table for the first round to get number of regions*/
+	/* Parse PTCT table for the first round to determine PTCT version */
+	ptr = (u8 *)table;
+	ptr += PTCT_ACPI_HEADER_SIZE;
+
+	for (offset = PTCT_ACPI_HEADER_SIZE; offset < total_length;) {
+		entry = (struct acpi_ptct_entry_header *)(ptr);
+		offset += entry->size;
+
+		if (entry->type == ACPI_PTCT_V2_ENTRY_COMPATIBILITY) {
+			compatibility = (struct acpi_ptct_compatibility *)(ptr + PTCT_ENTRY_HEADER_SIZE);
+			acpi_ptct_format = compatibility->rtct_version;
+			if ((acpi_ptct_format != ACPI_PTCT_FORMAT_V1) && (acpi_ptct_format != ACPI_PTCT_FORMAT_V2))
+				return -EINVAL;
+		}
+		ptr += entry->size;
+	}
+
+	/* Parse PTCT table for the second round to get number of regions*/
 
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
@@ -1357,15 +1380,18 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 		entry = (struct acpi_ptct_entry_header *)(ptr);
 		offset += entry->size;
 
-		if (entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM)
+		if ((acpi_ptct_format == ACPI_PTCT_FORMAT_V1) &&
+		    (entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM))
+			total_psram_region++;
+		else if ((acpi_ptct_format == ACPI_PTCT_FORMAT_V2) &&
+		    (entry->type == ACPI_PTCT_V2_ENTRY_SSRAM))
 			total_psram_region++;
-
 		ptr += entry->size;
 	}
 	if (total_psram_region > MAX_PSRAM_REGIONS)
 		return -EINVAL;
 
-	/* Parse for the second round to record address for each regions */
+	/* Parse for the third round to record address for each regions */
 
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
@@ -1374,11 +1400,20 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 		entry = (struct acpi_ptct_entry_header *)(ptr);
 		offset += entry->size;
 
-		if ((entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM) && (id < total_psram_region)) {
-			psram = (struct acpi_ptct_psram *)(ptr+PTCT_ENTRY_HEADER_SIZE);
-			ptct_psram_regions[id].phyaddr_start = ((u64)(psram->phyaddr_lo))|((u64)(psram->phyaddr_hi)<<32);
+		if ((acpi_ptct_format == ACPI_PTCT_FORMAT_V1) &&
+		    (entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM) &&
+		    (id < total_psram_region)) {
+			psram = (struct acpi_ptct_psram *)(ptr + PTCT_ENTRY_HEADER_SIZE);
+			ptct_psram_regions[id].phyaddr_start = ((u64)(psram->phyaddr_lo)) | ((u64)(psram->phyaddr_hi) << 32);
 			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram->size;
 			id++;
+		} else if ((acpi_ptct_format == ACPI_PTCT_FORMAT_V2) &&
+		    (entry->type == ACPI_PTCT_V2_ENTRY_SSRAM) &&
+		    (id < total_psram_region)) {
+			psram_v2 = (struct acpi_ptct_psram_v2 *)(ptr + PTCT_ENTRY_HEADER_SIZE);
+			ptct_psram_regions[id].phyaddr_start = ((u64)(psram_v2->phyaddr_lo)) | ((u64)(psram_v2->phyaddr_hi) << 32);
+			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram_v2->size;
+			id++;
 		}
 		ptr += entry->size;
 	}
@@ -1388,7 +1423,7 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 
 static void __init acpi_process_ptct(void)
 {
-	if (!acpi_table_parse(ACPI_SIG_PTCT, acpi_parse_ptct))
+	if ((!acpi_table_parse(ACPI_SIG_PTCT, acpi_parse_ptct)) || (!acpi_table_parse(ACPI_SIG_RTCT, acpi_parse_ptct)))
 		x86_platform.is_untracked_pat_range = tcc_is_untracked_pat_range;
 }
 
diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index a9f83c1d0722..fbdab419a241 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -57,14 +57,22 @@
 
 #include <linux/acpi.h>
 #include <linux/kernel.h>
+#include <linux/smp.h>
 #include <linux/list.h>
 #include <linux/mm.h>
 #include <linux/module.h>
 #include <linux/types.h>
 #include <linux/version.h>
 
+#include <linux/init.h>
 #include "tcc_buffer.h"
 
+static int tccdbg;
+module_param(tccdbg, int, 0644);
+MODULE_PARM_DESC(tccdbg, "Turn on/off trace");
+#define dprintk(fmt, arg...) \
+	do { if (tccdbg) pr_info(fmt, ##arg); } while (0)
+
 #define PTCT_ENTRY_OFFSET_VERSION 0
 #define PTCT_ENTRY_OFFSET_SIZE    0
 #define PTCT_ENTRY_OFFSET_TYPE    1
@@ -80,24 +88,44 @@
 #define MHL_OFFSET_CLOCKCYCLES    (MHL_OFFSET_HIERARCHY + 1)
 #define MHL_OFFSET_APIC           (MHL_OFFSET_CLOCKCYCLES + 1)
 
+#define FORMAT_V1                 1
+#define FORMAT_V2                 2
+
 enum PTCT_ENTRY_TYPE {
-	PTCT_PTCD_LIMITS          = 1,
-	PTCT_PTCM_BINARY          = 2,
-	PTCT_WRC_L3_WAYMASK       = 3,
-	PTCT_GT_L3_WAYMASK        = 4,
-	PTCT_PESUDO_SRAM          = 5,
-	PTCT_STREAM_DATAPATH      = 6,
-	PTCT_TIMEAWARE_SUBSYSTEMS = 7,
-	PTCT_REALTIME_IOMMU       = 8,
-	PTCT_MEMORY_HIERARCHY_LATENCY = 9,
+	PTCT_PTCD_LIMITS             = 0x00000001,
+	PTCT_PTCM_BINARY             = 0x00000002,
+	PTCT_WRC_L3_WAYMASK          = 0x00000003,
+	PTCT_GT_L3_WAYMASK           = 0x00000004,
+	PTCT_PESUDO_SRAM             = 0x00000005,
+	PTCT_STREAM_DATAPATH         = 0x00000006,
+	PTCT_TIMEAWARE_SUBSYSTEMS    = 0x00000007,
+	PTCT_REALTIME_IOMMU          = 0x00000008,
+	PTCT_MEMORY_HIERARCHY_LATENCY = 0x00000009,
 	PTCT_ENTRY_TYPE_NUMS
 };
 
+enum PTCT_V2_ENTRY_TYPE {
+	PTCT_V2_COMPATIBILITY        = 0x00000000,
+	PTCT_V2_RTCD_LIMIT           = 0x00000001,
+	PTCT_V2_CRL_BINARY           = 0x00000002,
+	PTCT_V2_IA_WAYMASK           = 0x00000003,
+	PTCT_V2_WRC_WAYMASK          = 0x00000004,
+	PTCT_V2_GT_WAYMASK           = 0x00000005,
+	PTCT_V2_SSRAM_WAYMASK        = 0x00000006,
+	PTCT_V2_SSRAM                = 0x00000007,
+	PTCT_V2_MEMORY_HIERARCHY_LATENCY = 0x00000008,
+	PTCT_V2_ERROR_LOG_ADDRESS    = 0x00000009,
+
+	PTCT_V2_ENTRY_TYPE_NUMS
+};
+
 #define ENTRY_HEADER_SIZE (sizeof(struct tcc_ptct_entry_header) / sizeof(u32))
 #define ACPI_HEADER_SIZE (sizeof(struct acpi_table_header) / sizeof(u32))
 
-#define MEM_FREE 0
-#define MEM_BUSY 1
+#define MEM_FREE     0
+#define MEM_BUSY     1
+#define MAXCACHEID   64
+static u32 ssram_waymask_v2[2][MAXCACHEID] = {{0}};
 
 struct tcc_ptct_entry_header {
 	u16 size;
@@ -120,12 +148,44 @@ struct tcc_ptct_mhlatency {
 	u32 *apicids;
 };
 
+struct tcc_ptct_psram_v2 {
+	u32 cache_level;
+	u32 cache_id;
+	u32 phyaddr_lo;
+	u32 phyaddr_hi;
+	u32 size;
+	u32 shared;
+};
+
+struct tcc_ptct_mhlatency_v2 {
+	u32 cache_level;
+	u32 latency;
+	u32 latency_VT;
+	u32 *cacheids;
+};
+
+struct tcc_ptct_sram_waymask_v2 {
+	u32 cache_level;
+	u32 cache_id;
+	u32 waymask;
+};
+
+struct tcc_ptct_compatibility {
+	u32 rtct_version;
+	u32 rtct_version_minor;
+	u32 rtcd_version;
+	u32 rtcd_version_minor;
+};
+
 struct memory_slot_info {
 	u64 paddr;
+	void *vaddr;
 	size_t size;
 	u32 status;
 	u32 minor;
 	u32 open_count;
+	u32 psramid;
+	cpumask_t cpumask;
 	struct list_head node;
 };
 
@@ -149,22 +209,54 @@ struct tcc_config {
 	struct list_head psrams;
 };
 
+#define MAXDEVICENODE 250
 static unsigned int tcc_buffer_device_major;
-static unsigned long tcc_buffer_device_minor_avail = GENMASK(MINORBITS, 0);
+DECLARE_BITMAP(tcc_buffer_device_minor_avail, MAXDEVICENODE);
 static struct class *tcc_buffer_class;
 static struct acpi_table_header *acpi_ptct_tbl;
 static struct tcc_config *p_tcc_config;
 static u32 tcc_init;
+static u32 ptct_format = FORMAT_V1;
 DEFINE_MUTEX(tccbuffer_mutex);
 
+#define CPUID_LEAF_EXT_TOPO_ENUM 0x0B
+#define CPUID_0B_SUBLEAF_SMT     0
+#define CPUID_0B_SUBLEAF_CORE    1
+
+static u32 utils_apicid(void)
+{
+	u32 eax = 0, ebx = 0, ecx = 0, edx = 0;
+
+	cpuid_count(CPUID_LEAF_EXT_TOPO_ENUM, CPUID_0B_SUBLEAF_SMT, &eax, &ebx, &ecx, &edx);
+	return edx;
+}
+
+static int curr_process_cpu(void)
+{
+	u32 i = 0, cpu = 0xFFFF, apicid = 0;
+
+	apicid = utils_apicid();
+	for_each_online_cpu(i) {
+		dprintk("cpu_data(%d).apicid = %08x. Check for %08x.\n", i, cpu_data(i).apicid, apicid);
+		/* each cpu could corresponding to one apicid, even with HT */
+		if (cpu_data(i).apicid == apicid)
+			cpu = i;
+	}
+	if (cpu == 0xFFFF) {
+		pr_err("Failed to find  cpu for apicid\n");
+		return -EFAULT;
+	}
+	return cpu;
+}
+
 static int tcc_buffer_minor_get(u32 *minor)
 {
 	unsigned long first_bit;
 
-	first_bit = find_first_bit(&tcc_buffer_device_minor_avail, MINORBITS);
-	if (first_bit == MINORBITS)
+	first_bit = find_first_bit(&tcc_buffer_device_minor_avail[0], MAXDEVICENODE);
+	if (first_bit == MAXDEVICENODE)
 		return -ENOSPC;
-	__clear_bit(first_bit, &tcc_buffer_device_minor_avail);
+	__clear_bit(first_bit, &tcc_buffer_device_minor_avail[0]);
 	*minor = first_bit;
 	return 0;
 }
@@ -206,10 +298,17 @@ static void tcc_get_cache_info(void)
 	} while ((eax & 0x1F) != 0);
 }
 
-static void tcc_get_psram_cpumask(u32 apicid, u32 num_threads_sharing, cpumask_t *mask)
+static void tcc_get_psram_cpumask(u32 coreid, u32 num_threads_sharing, cpumask_t *mask)
 {
 	u32 i = 0;
 	u32 apicid_start = 0, apicid_end = 0;
+	u32 index_msb, id;
+	u32 apicid = 0;
+
+	if (ptct_format == FORMAT_V2)
+		apicid = cpu_data(coreid).apicid;
+	else
+		apicid = coreid;
 
 	apicid_start = apicid & (~(num_threads_sharing - 1));
 	apicid_end = apicid_start + num_threads_sharing;
@@ -218,19 +317,28 @@ static void tcc_get_psram_cpumask(u32 apicid, u32 num_threads_sharing, cpumask_t
 		if ((cpu_data(i).apicid >= apicid_start) &&
 			(cpu_data(i).apicid < apicid_end))
 			cpumask_set_cpu(i, mask);
+		index_msb = get_count_order(num_threads_sharing);
+		id = cpu_data(i).apicid >> index_msb;
+		dprintk("cpu_data(%d).apicid %d\tnum_threads_sharing %d\tmsb %d\tcache_id %d\n", i, cpu_data(i).apicid, num_threads_sharing, index_msb, id);
 	}
+	dprintk("Cachel level dependent! apicid  %d  num_threads_sharing %d ==> cpumask %lx\n", apicid, num_threads_sharing, *(unsigned long *)mask);
 }
 
 static int tcc_parse_ptct(void)
 {
 	u32 *tbl_swap;
-	u32 offset = 0, entry_size, entry_type;
+	u32 offset = 0, entry_size = 0, entry_type = 0;
+	u32 cache_level = 0, cache_id = 0;
 	struct tcc_ptct_entry_header *entry_header;
 	struct tcc_ptct_mhlatency *entry_mhl;
 	struct tcc_ptct_psram *entry_psram;
+	struct tcc_ptct_mhlatency_v2 *entry_mhl_v2;
+	struct tcc_ptct_psram_v2 *entry_psram_v2;
+	struct tcc_ptct_sram_waymask_v2 *entry_sram_waymask_v2;
 	static struct psram *p_new_psram;
 	static struct memory_slot_info *p_memslot;
 	struct psram *p_tmp_psram;
+	struct tcc_ptct_compatibility *compatibility;
 	u64 l2_start, l2_end, l3_start, l3_end;
 
 	tbl_swap = (u32 *)acpi_ptct_tbl;
@@ -243,24 +351,84 @@ static int tcc_parse_ptct(void)
 	offset = ACPI_HEADER_SIZE;
 	tbl_swap = tbl_swap + offset;
 
+	/* Check PTCT format */
 	do {
 		entry_header = (struct tcc_ptct_entry_header *)tbl_swap;
 
 		entry_size = entry_header->size;
 		entry_type = entry_header->type;
 
-		if (entry_type == PTCT_MEMORY_HIERARCHY_LATENCY) {
+		if (entry_type == PTCT_V2_COMPATIBILITY) {
+			compatibility = (struct tcc_ptct_compatibility *)(tbl_swap + ENTRY_HEADER_SIZE);
+			ptct_format = compatibility->rtct_version;
+			if ((ptct_format != FORMAT_V1) && (ptct_format != FORMAT_V2)) {
+				pr_err("TCC PTCT cannot support this version %d.\n", ptct_format);
+				return -EINVAL;
+			}
+		}
+
+		offset += entry_size / sizeof(u32);
+		tbl_swap = tbl_swap + entry_size / sizeof(u32);
+	} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
+
+	dprintk("ptct_format = %s\n", (ptct_format == FORMAT_V1) ? "FORMAT_V1":"FORMAT_V2");
+
+	/* Parse and save memory latency */
+	tbl_swap = (u32 *)acpi_ptct_tbl;
+	offset = ACPI_HEADER_SIZE;
+	tbl_swap = tbl_swap + offset;
+
+	do {
+		entry_header = (struct tcc_ptct_entry_header *)tbl_swap;
+
+		entry_size = entry_header->size;
+		entry_type = entry_header->type;
+
+		if ((ptct_format == FORMAT_V1) && (entry_type == PTCT_MEMORY_HIERARCHY_LATENCY)) {
 			entry_mhl = (struct tcc_ptct_mhlatency *)(tbl_swap + ENTRY_HEADER_SIZE);
 			if (entry_mhl->cache_level == RGN_L2)
 				p_tcc_config->l2_latency = entry_mhl->latency;
 			else if (entry_mhl->cache_level == RGN_L3)
 				p_tcc_config->l3_latency = entry_mhl->latency;
+		} else if ((ptct_format == FORMAT_V2) && (entry_type == PTCT_V2_MEMORY_HIERARCHY_LATENCY)) {
+			entry_mhl_v2 = (struct tcc_ptct_mhlatency_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
+			if (entry_mhl_v2->cache_level == RGN_L2)
+				p_tcc_config->l2_latency = entry_mhl_v2->latency_VT;
+			else if (entry_mhl_v2->cache_level == RGN_L3)
+				p_tcc_config->l3_latency = entry_mhl_v2->latency_VT;
 		}
 
 		offset += entry_size / sizeof(u32);
 		tbl_swap = tbl_swap + entry_size / sizeof(u32);
 	} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
 
+	/* Parse and save ssram waymask in version 2 format*/
+	if (ptct_format == FORMAT_V2) {
+		tbl_swap = (u32 *)acpi_ptct_tbl;
+		offset = ACPI_HEADER_SIZE;
+		tbl_swap = tbl_swap + offset;
+
+		do {
+			entry_header = (struct tcc_ptct_entry_header *)tbl_swap;
+			entry_size = entry_header->size;
+			entry_type = entry_header->type;
+
+			if (entry_type == PTCT_V2_SSRAM_WAYMASK) {
+				entry_sram_waymask_v2 = (struct tcc_ptct_sram_waymask_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
+				cache_level = entry_sram_waymask_v2->cache_level;
+				cache_id =  entry_sram_waymask_v2->cache_id;
+				if (((cache_level == RGN_L2) || (cache_level == RGN_L3)) && (cache_id < MAXCACHEID)) {
+					ssram_waymask_v2[cache_level - RGN_L2][cache_id] = entry_sram_waymask_v2->waymask;
+					dprintk("ssram_waymask_v2[cache_level %d][cache_id %d]  = 0x%08x\n", cache_level, cache_id, ssram_waymask_v2[cache_level - RGN_L2][cache_id]);
+				}
+			}
+
+			offset += entry_size / sizeof(u32);
+			tbl_swap = tbl_swap + entry_size / sizeof(u32);
+		} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
+	}
+
+	/* Parse and save ssram regions */
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 	offset = ACPI_HEADER_SIZE;
 	tbl_swap = tbl_swap + offset;
@@ -271,54 +439,128 @@ static int tcc_parse_ptct(void)
 		entry_size = entry_header->size;
 		entry_type = entry_header->type;
 
-		switch (entry_type) {
-		case PTCT_PESUDO_SRAM:
-			entry_psram = (struct tcc_ptct_psram *)(tbl_swap + ENTRY_HEADER_SIZE);
-			if (entry_psram->cache_level != RGN_L2 && entry_psram->cache_level != RGN_L3)
-				break;
+		if (ptct_format == FORMAT_V1) {
+			switch (entry_type) {
+			case PTCT_PESUDO_SRAM:
+				entry_psram = (struct tcc_ptct_psram *)(tbl_swap + ENTRY_HEADER_SIZE);
+				if (entry_psram->cache_level != RGN_L2 && entry_psram->cache_level != RGN_L3)
+					break;
 
-			p_new_psram = kzalloc(sizeof(struct psram), GFP_KERNEL);
-			if (!p_new_psram)
-				return -ENOMEM;
+				p_new_psram = kzalloc(sizeof(struct psram), GFP_KERNEL);
+				if (!p_new_psram)
+					return -ENOMEM;
 
-			p_new_psram->config.id = p_tcc_config->num_of_psram++;
-			p_new_psram->config.type = entry_psram->cache_level;
-			p_new_psram->paddr = ((u64)(entry_psram->phyaddr_hi) << 32) | entry_psram->phyaddr_lo;
-			p_new_psram->config.size = entry_psram->size;
-			p_new_psram->config.ways = entry_psram->cache_ways;
+				p_new_psram->config.id = p_tcc_config->num_of_psram++;
+				p_new_psram->config.type = entry_psram->cache_level;
+				p_new_psram->paddr = ((u64)(entry_psram->phyaddr_hi) << 32) | entry_psram->phyaddr_lo;
+				p_new_psram->config.size = entry_psram->size;
+				p_new_psram->config.ways = entry_psram->cache_ways;
+
+				if (entry_psram->cache_level == RGN_L2) {
+					p_new_psram->config.latency = p_tcc_config->l2_latency;
+					tcc_get_psram_cpumask(entry_psram->apic_id, p_tcc_config->l2_num_of_threads_share, &p_new_psram->cpumask);
+					p_new_psram->vaddr = memremap(p_new_psram->paddr, p_new_psram->config.size, MEMREMAP_WB);
+					INIT_LIST_HEAD(&p_new_psram->memslots);
+
+					p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
+					if (!p_memslot)
+						return -ENOMEM;
+
+					p_memslot->paddr = p_new_psram->paddr;
+					p_memslot->vaddr = p_new_psram->vaddr;
+					p_memslot->size = p_new_psram->config.size;
+					p_memslot->status = MEM_FREE;
+					p_memslot->minor = UNDEFINED_DEVNODE;
+					p_memslot->psramid = p_new_psram->config.id;
+					p_memslot->cpumask = p_new_psram->cpumask;
+					dprintk("%s\n", "RGN_L2");
+					dprintk("p_new_psram->paddr @ %016llx\n", (u64)(p_new_psram->paddr));
+					dprintk("p_memslot->paddr   @ %016llx\n", (u64)(p_memslot->paddr));
+					dprintk("p_memslot->psramid @ %d\n", p_memslot->psramid);
+					dprintk("p_memslot->cpumask @ %llx\n", *((u64 *)&(p_memslot->cpumask)));
+					list_add_tail(&p_memslot->node, &p_new_psram->memslots);
+				} else if (entry_psram->cache_level == RGN_L3) {
+					p_new_psram->config.latency = p_tcc_config->l3_latency;
+					tcc_get_psram_cpumask(entry_psram->apic_id, p_tcc_config->l3_num_of_threads_share, &p_new_psram->cpumask);
+				}
 
-			if (entry_psram->cache_level == RGN_L2) {
-				p_new_psram->config.latency = p_tcc_config->l2_latency;
-				tcc_get_psram_cpumask(entry_psram->apic_id, p_tcc_config->l2_num_of_threads_share, &p_new_psram->cpumask);
-				p_new_psram->vaddr = memremap(p_new_psram->paddr, p_new_psram->config.size, MEMREMAP_WB);
-				INIT_LIST_HEAD(&p_new_psram->memslots);
+				p_new_psram->config.cpu_mask_p = (void *)&p_new_psram->cpumask;
+				list_add_tail(&p_new_psram->node, &p_tcc_config->psrams);
+				break;
 
-				p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
-				if (!p_memslot)
+			default:
+				break;
+			}
+		} else {
+			/* RTCT version 2 format */
+			switch (entry_type) {
+			case PTCT_V2_SSRAM:
+				dprintk("%s\n", "Find new ssram entry");
+				entry_psram_v2 = (struct tcc_ptct_psram_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
+				if (entry_psram_v2->cache_level != RGN_L2 && entry_psram_v2->cache_level != RGN_L3)
+					break;
+				dprintk("%s\n", "PTCT_V2_SSRAM");
+				dprintk("entry_psram_v2->cache_level= %08x\n", entry_psram_v2->cache_level);
+				dprintk("entry_psram_v2->cache_id   = %08x\n", entry_psram_v2->cache_id);
+				dprintk("entry_psram_v2->phyaddr_lo = %08x\n", entry_psram_v2->phyaddr_lo);
+				dprintk("entry_psram_v2->phyaddr_hi = %08x\n", entry_psram_v2->phyaddr_hi);
+				dprintk("entry_psram_v2->size       = %08x\n", entry_psram_v2->size);
+
+				p_new_psram = kzalloc(sizeof(struct psram), GFP_KERNEL);
+				if (!p_new_psram)
 					return -ENOMEM;
 
-				p_memslot->paddr = p_new_psram->paddr;
-				p_memslot->size = p_new_psram->config.size;
-				p_memslot->status = MEM_FREE;
-				p_memslot->minor = UNDEFINED_DEVNODE;
-				list_add_tail(&p_memslot->node, &p_new_psram->memslots);
-			} else if (entry_psram->cache_level == RGN_L3) {
-				p_new_psram->config.latency = p_tcc_config->l3_latency;
-				tcc_get_psram_cpumask(entry_psram->apic_id, p_tcc_config->l3_num_of_threads_share, &p_new_psram->cpumask);
-			}
+				p_new_psram->config.id = p_tcc_config->num_of_psram++;
+				p_new_psram->config.type = entry_psram_v2->cache_level;
+				p_new_psram->paddr = ((u64)(entry_psram_v2->phyaddr_hi) << 32) | entry_psram_v2->phyaddr_lo;
+				p_new_psram->config.size = entry_psram_v2->size;
+				if (((entry_psram_v2->cache_level == RGN_L2) || (entry_psram_v2->cache_level == RGN_L3)) && (entry_psram_v2->cache_id < MAXCACHEID))
+					p_new_psram->config.ways = ssram_waymask_v2[entry_psram_v2->cache_level - RGN_L2][entry_psram_v2->cache_id];
+
+				if (entry_psram_v2->cache_level == RGN_L2) {
+					p_new_psram->config.latency = p_tcc_config->l2_latency;
+					tcc_get_psram_cpumask(entry_psram_v2->cache_id, p_tcc_config->l2_num_of_threads_share, &p_new_psram->cpumask);
+					p_new_psram->vaddr = memremap(p_new_psram->paddr, p_new_psram->config.size, MEMREMAP_WB);
+					INIT_LIST_HEAD(&p_new_psram->memslots);
+
+					p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
+					if (!p_memslot)
+						return -ENOMEM;
+
+					p_memslot->paddr = p_new_psram->paddr;
+					p_memslot->vaddr = p_new_psram->vaddr;
+					dprintk("%s\n", "RGN_L2");
+					dprintk("p_new_psram->paddr @ %016llx\n", (u64)(p_new_psram->paddr));
+					dprintk("p_memslot->paddr   @ %016llx\n", (u64)(p_memslot->paddr));
+					p_memslot->size = p_new_psram->config.size;
+					p_memslot->status = MEM_FREE;
+					p_memslot->minor = UNDEFINED_DEVNODE;
+					p_memslot->psramid = p_new_psram->config.id;
+					p_memslot->cpumask = p_new_psram->cpumask;
+					dprintk("p_memslot->size    @ %016llx\n", (u64)(p_memslot->size));
+					dprintk("p_memslot->psramid @ %d\n", p_memslot->psramid);
+					dprintk("p_memslot->cpumask @ %llx\n", *((u64 *)&(p_memslot->cpumask)));
+					list_add_tail(&p_memslot->node, &p_new_psram->memslots);
+				} else if (entry_psram_v2->cache_level == RGN_L3) {
+					dprintk("%s\n", "RGN_L3 first stage");
+					p_new_psram->config.latency = p_tcc_config->l3_latency;
+					tcc_get_psram_cpumask(entry_psram_v2->cache_id, p_tcc_config->l3_num_of_threads_share, &p_new_psram->cpumask);
+				}
 
-			p_new_psram->config.cpu_mask_p = (void *)&p_new_psram->cpumask;
-			list_add_tail(&p_new_psram->node, &p_tcc_config->psrams);
-			break;
+				p_new_psram->config.cpu_mask_p = (void *)&p_new_psram->cpumask;
+				list_add_tail(&p_new_psram->node, &p_tcc_config->psrams);
+				break;
 
-		default:
-			break;
+			default:
+				break;
+			}
 		}
 		/* move to next entry*/
 		offset += entry_size / sizeof(u32);
 		tbl_swap = tbl_swap + entry_size / sizeof(u32);
 	} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
 
+	dprintk("%s\n", "Process possible overlay l2/l3 region");
 	l2_start = 0;
 	l2_end = 0;
 
@@ -334,6 +576,8 @@ static int tcc_parse_ptct(void)
 				if (p_tmp_psram->paddr + p_tmp_psram->config.size > l2_end)
 					l2_end = p_tmp_psram->paddr + p_tmp_psram->config.size;
 			}
+			dprintk("l2_start = 0x%016llx\n", l2_start);
+			dprintk("l2_end   = 0x%016llx\n", l2_end);
 		}
 	}
 
@@ -351,6 +595,9 @@ static int tcc_parse_ptct(void)
 			} else if (l2_start <= l3_end)
 				l3_end = l2_start;
 
+			dprintk("l3_start = 0x%016llx\n", l3_start);
+			dprintk("l3_end   = 0x%016llx\n", l3_end);
+
 			p_tmp_psram->paddr = l3_start;
 			p_tmp_psram->config.size = l3_end - l3_start;
 
@@ -363,9 +610,18 @@ static int tcc_parse_ptct(void)
 					return -ENOMEM;
 
 				p_memslot->paddr = p_tmp_psram->paddr;
+				p_memslot->vaddr = p_tmp_psram->vaddr;
+				dprintk("%s\n", "RGN_L3 second stage");
+				dprintk("p_tmp_psram->paddr @ %016llx\n", (u64)(p_tmp_psram->paddr));
+				dprintk("p_memslot->paddr   @ %016llx\n", (u64)(p_memslot->paddr));
 				p_memslot->size = p_tmp_psram->config.size;
 				p_memslot->status = MEM_FREE;
 				p_memslot->minor = UNDEFINED_DEVNODE;
+				p_memslot->psramid = p_tmp_psram->config.id;
+				p_memslot->cpumask = p_tmp_psram->cpumask;
+				dprintk("p_memslot->size    @ %016llx\n", (u64)(p_memslot->size));
+				dprintk("p_memslot->psramid @ %d\n", p_memslot->psramid);
+				dprintk("p_memslot->cpumask @ %llx\n", *((u64 *)&(p_memslot->cpumask)));
 				list_add_tail(&p_memslot->node, &p_tmp_psram->memslots);
 			}
 		}
@@ -398,18 +654,32 @@ static u32 tcc_allocate_memslot(u32 id, size_t size)
 		}
 	}
 
-	if (!found)
+	if (!found) {
+		pr_err("No enough memory\n");
 		goto fail;
+	}
 
+	ret = tcc_buffer_minor_get(&new_minor);
+	if (ret < 0) {
+		pr_err("Unable to obtain a new minor number\n");
+		goto fail;
+	}
+	dprintk("%s\n", "tcc_allocate_memslot()");
 	new_size = p_slot->size - size;
 
 	if (new_size > 0) {
 		p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
 		if (p_memslot == NULL)
-			goto fail;
+			goto fail_create_device;
 		p_memslot->paddr = p_slot->paddr + size;
+		p_memslot->vaddr = p_slot->vaddr + size;
 		p_memslot->size = new_size;
 		p_memslot->status = MEM_FREE;
+		p_memslot->psramid = p_slot->psramid;
+		p_memslot->cpumask = p_slot->cpumask;
+		dprintk("%s\n", "memslot for remained memory.");
+		dprintk("p_memslot->paddr   @ %016llx\n", (u64)(p_memslot->paddr));
+		dprintk("p_memslot->size    @ %016llx\n", (u64)(p_memslot->size));
 		list_add(&p_memslot->node, &p_slot->node);
 	}
 
@@ -417,67 +687,114 @@ static u32 tcc_allocate_memslot(u32 id, size_t size)
 	p_slot->status = MEM_BUSY;
 	p_slot->open_count = 0;
 
-	ret = tcc_buffer_minor_get(&new_minor);
-	if (ret < 0) {
-		pr_err("Unable to obtain a new minor number\n");
-		goto fail;
-	}
-
 	dev_ret = device_create(tcc_buffer_class, NULL,
 				MKDEV(tcc_buffer_device_major, new_minor),
 				NULL, TCC_BUFFER_NAME "%d", new_minor);
 	if (IS_ERR(dev_ret)) {
 		ret = PTR_ERR(dev_ret);
-		pr_err("Failed to create character device\n");
+		pr_err("SystemOS failed to create character device. Please reload driver.\n");
 		goto fail_create_device;
 	}
 
 	p_slot->minor = new_minor;
 
+	dprintk("%s\n", "memslot for allocated memory.");
+	dprintk("p_slot->paddr    @ %016llx\n", (u64)(p_slot->paddr));
+	dprintk("p_slot->size     @ %016llx\n", (u64)(p_slot->size));
+	dprintk("p_slot->minor    @ %d\n", p_slot->minor);
+	dprintk("p_slot->psramid  @ %d\n", p_slot->psramid);
+	dprintk("p_slot->cpumask  @ %08llx\n", *((u64 *)&(p_slot->cpumask)));
 	mutex_unlock(&tccbuffer_mutex);
 	return new_minor;
 fail_create_device:
-	__set_bit(new_minor, &tcc_buffer_device_minor_avail);
+	__set_bit(new_minor, &tcc_buffer_device_minor_avail[0]);
 fail:
 	mutex_unlock(&tccbuffer_mutex);
 	return UNDEFINED_DEVNODE;
 }
 
+/*
+ * To use this funcionint:
+ *    smp_call_function_any(const struct cpumask *mask, smp_call_func_t func, void *info, int wait)
+ */
+struct mem_s {
+	void *vaddr;
+	size_t size;
+};
+
+void clear_mem(void *info)
+{
+	struct mem_s *mem = (struct mem_s *) info;
+
+	memset(mem->vaddr, 0, mem->size);
+}
+
 static void tcc_free_memslot(struct memory_slot_info *p_memslot)
 {
 	struct memory_slot_info *pre_slot;
 	struct memory_slot_info *next_slot;
-	void *vaddr;
+	struct mem_s mem_info;
+	struct psram *p_psram;
+	u32 is_first = 0, is_last = 0;
 
 	mutex_lock(&tccbuffer_mutex);
 	device_destroy(tcc_buffer_class, MKDEV(tcc_buffer_device_major, p_memslot->minor));
-	__set_bit(p_memslot->minor, &tcc_buffer_device_minor_avail);
+	__set_bit(p_memslot->minor, &tcc_buffer_device_minor_avail[0]);
 	p_memslot->status = MEM_FREE;
 	p_memslot->minor = UNDEFINED_DEVNODE;
-	vaddr = memremap(p_memslot->paddr, p_memslot->size, MEMREMAP_WB);
-	if (vaddr != NULL) {
-		memset(vaddr, 0, p_memslot->size);
-		memunmap(vaddr);
+	dprintk("%s\n", "tcc_free_memslot()");
+	dprintk("p_memslot->paddr    @ %016llx\n", (u64)(p_memslot->paddr));
+	dprintk("p_memslot->size     @ %016llx\n", (u64)(p_memslot->size));
+	mem_info.vaddr = p_memslot->vaddr;
+	mem_info.size  = p_memslot->size;
+	smp_call_function_any(&(p_memslot->cpumask), clear_mem, &mem_info, 1);
+
+	list_for_each_entry(p_psram, &p_tcc_config->psrams, node) {
+		if (p_psram->config.size > 0) {
+			if (list_is_first(&p_memslot->node, &p_psram->memslots))
+				is_first = 1;
+			if (list_is_last(&p_memslot->node, &p_psram->memslots))
+				is_last = 1;
+		}
 	}
-	pre_slot = list_prev_entry(p_memslot, node);
-	next_slot = list_next_entry(p_memslot, node);
 
-	if (pre_slot->status == MEM_FREE) {
+	if (!is_first)
+		pre_slot = list_prev_entry(p_memslot, node);
+
+	if (!is_last)
+		next_slot = list_next_entry(p_memslot, node);
+
+	if ((!is_first) && (pre_slot->status == MEM_FREE)) {
+		dprintk("%s\n", "This is not FIRST slot, and pre_slot is FREE to merge");
 		pre_slot->size += p_memslot->size;
-		if (next_slot->status == MEM_FREE) {
+		if ((!is_last) && (next_slot->status == MEM_FREE)) {
+			dprintk("%s\n", "AND this is not LAST slot, and next_slot is also FREE to merge");
 			pre_slot->size += next_slot->size;
 			list_del(&next_slot->node);
 			kfree(next_slot);
 		}
+		dprintk("paddr               @ %016llx\n", (u64)(pre_slot->paddr));
+		dprintk("size                @ %016llx (extended)\n", (u64)(pre_slot->size));
 		list_del(&p_memslot->node);
 		kfree(p_memslot);
+	} else if ((!is_last) && (next_slot->status == MEM_FREE)) {
+		dprintk("%s\n", "This is not LAST slot, and next_slot is FREE to merge");
+		p_memslot->size += next_slot->size;
+		dprintk("paddr               @ %016llx\n", (u64)(p_memslot->paddr));
+		dprintk("size                @ %016llx (extended)\n", (u64)(p_memslot->size));
+		list_del(&next_slot->node);
+		kfree(next_slot);
+	} else {
+		dprintk("%s\n", "No other attributes need to set.");
 	}
+
 	mutex_unlock(&tccbuffer_mutex);
 }
 
 static int tcc_buffer_open(struct inode *i, struct file *f)
 {
 	struct memory_slot_info *p_memslot;
+	int cpu, testmask = 0;
 
 	if (p_tcc_config->minor == MINOR(i->i_rdev))
 		return 0;
@@ -490,7 +807,20 @@ static int tcc_buffer_open(struct inode *i, struct file *f)
 		pr_err("OPEN(): This device is already open.\n");
 		return -EBUSY;
 	}
+	cpu = curr_process_cpu();
+	if (cpu < 0) {
+		pr_err("OPEN(): No cpu found.\n");
+		return -EINVAL;
+	}
+	testmask = cpumask_test_cpu(cpu, &(p_memslot->cpumask));
+	if (testmask == 0)
+		pr_err("OPEN(): psram device is open from non-affinity cpu.\n");
+
 	p_memslot->open_count++;
+	dprintk("%s\n", "open()");
+	dprintk("p_memslot->paddr      @ %016llx\n", (u64)(p_memslot->paddr));
+	dprintk("p_memslot->size       @ %016llx\n", (u64)(p_memslot->size));
+
 	f->private_data = p_memslot;
 	return 0;
 }
@@ -503,6 +833,9 @@ static int tcc_buffer_close(struct inode *i, struct file *f)
 		return 0;
 	p_memslot = (struct memory_slot_info *)(f->private_data);
 	p_memslot->open_count--;
+	dprintk("%s\n", "close()");
+	dprintk("p_memslot->paddr      @ %016llx\n", (u64)(p_memslot->paddr));
+	dprintk("p_memslot->size       @ %016llx\n", (u64)(p_memslot->size));
 	if (p_memslot->open_count == 0)
 		tcc_free_memslot(p_memslot);
 
@@ -521,8 +854,17 @@ static int tcc_buffer_mmap(struct file *f, struct vm_area_struct *vma)
 		return -EINVAL;
 	}
 
-	if (!(vma->vm_flags & VM_SHARED))
+	if (!(vma->vm_flags & VM_SHARED)) {
+		pr_err("mmap() should specify VM_SHARED flag!");
 		return -EINVAL;
+	}
+
+	if (p_memslot == NULL)
+		return -EINVAL;
+
+	dprintk("%s\n", "mmap()");
+	dprintk("p_memslot->paddr      @ %016llx\n", (u64)(p_memslot->paddr));
+	dprintk("p_memslot->size       @ %016llx\n", (u64)(p_memslot->size));
 
 	pfn = (p_memslot->paddr) >> PAGE_SHIFT;
 	ret = remap_pfn_range(vma, vma->vm_start, pfn, len, vma->vm_page_prot);
@@ -540,6 +882,8 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	struct tcc_buf_mem_config_s memconfig;
 	struct tcc_buf_mem_req_s req_mem;
 
+	int cpu, testmask = 0;
+
 	switch (cmd) {
 	case TCC_GET_REGION_COUNT:
 		if (NULL == (int *)arg) {
@@ -616,7 +960,34 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 		if (ret != 0)
 			return -EFAULT;
 
-		req_mem.devnode = tcc_allocate_memslot(req_mem.id, req_mem.size);
+		cpu = curr_process_cpu();
+		if (cpu < 0) {
+			pr_err("No cpu found.\n");
+			return -EINVAL;
+		}
+		/* check the request psram region affinity with this process */
+		list_for_each_entry(p_psram, &p_tcc_config->psrams, node) {
+			if (p_psram->config.size > 0) {
+				dprintk("p_psram %d  cpumask %08lx\n", p_psram->config.id, *((long *)&(p_psram->cpumask)));
+				if (p_psram->config.id == req_mem.id)
+					testmask = cpumask_test_cpu(cpu, &(p_psram->cpumask));
+			}
+		}
+		if (testmask == 0)
+			pr_err("psram is requested from non-affinity cpu.\n");
+
+		if (req_mem.size & (PAGE_SIZE - 1)) {
+			pr_err("size must be page-aligned!");
+			return -EINVAL;
+		}
+
+		/* KW */
+		if ((req_mem.size > 0) && (req_mem.size < 0xFFFFFFFF))
+			req_mem.devnode = tcc_allocate_memslot(req_mem.id, req_mem.size);
+		else {
+			pr_err("size requested is either Zero or is too huge.\n");
+			return -EINVAL;
+		}
 
 		if (req_mem.devnode == UNDEFINED_DEVNODE)
 			return -ENOMEM;
@@ -649,8 +1020,10 @@ static void tcc_cleanup(void)
 	list_for_each_entry_safe(p_psram, p_temp_psram, &p_tcc_config->psrams, node) {
 		if (p_psram->config.size > 0) {
 			list_for_each_entry_safe(p_slot, p_temp_slot, &p_psram->memslots, node) {
-				if (p_slot->status != MEM_FREE)
+				if (p_slot->status != MEM_FREE) {
 					device_destroy(tcc_buffer_class, MKDEV(tcc_buffer_device_major, p_slot->minor));
+					__set_bit(p_slot->minor, &tcc_buffer_device_minor_avail[0]);
+				}
 
 				list_del(&p_slot->node);
 				kfree(p_slot);
@@ -672,13 +1045,17 @@ static int __init tcc_buffer_init(void)
 
 	status = acpi_get_table(ACPI_SIG_PTCT, 0, &acpi_ptct_tbl);
 	if (ACPI_FAILURE(status) || !acpi_ptct_tbl) {
-		pr_err("Stop! ACPI doesn't provide PTCT.");
-		return -1;
+		status = acpi_get_table(ACPI_SIG_RTCT, 0, &acpi_ptct_tbl);
+		if (ACPI_FAILURE(status) || !acpi_ptct_tbl) {
+			pr_err("Stop! ACPI doesn't provide PTCT/RTCT.");
+			return -EFAULT;
+		}
+		dprintk("%s\n", "RTCT found.");
 	}
 
 	p_tcc_config = kzalloc(sizeof(struct tcc_config), GFP_KERNEL);
 	if (!p_tcc_config)
-		return -1;
+		return -ENOMEM;
 	INIT_LIST_HEAD(&p_tcc_config->psrams);
 
 	ret = tcc_parse_ptct();
@@ -692,6 +1069,8 @@ static int __init tcc_buffer_init(void)
 	}
 	tcc_buffer_device_major = ret;
 
+	bitmap_set(&tcc_buffer_device_minor_avail[0], 0, MAXDEVICENODE);
+
 	ret = tcc_buffer_minor_get(&new_minor);
 	if (ret < 0) {
 		pr_err("Unable to obtain a new minor number\n");
@@ -735,10 +1114,12 @@ static void __exit tcc_buffer_exit(void)
 	if (tcc_init) {
 		tcc_cleanup();
 		device_destroy(tcc_buffer_class, MKDEV(tcc_buffer_device_major, p_tcc_config->minor));
+		__set_bit(p_tcc_config->minor, &tcc_buffer_device_minor_avail[0]);
 		class_destroy(tcc_buffer_class);
 		unregister_chrdev(tcc_buffer_device_major, TCC_BUFFER_NAME);
 		kfree(p_tcc_config);
 	}
+	pr_err("exit().\n");
 }
 
 module_init(tcc_buffer_init);
diff --git a/include/acpi/actbl2.h b/include/acpi/actbl2.h
index d84695a907f5..e3205c806a81 100644
--- a/include/acpi/actbl2.h
+++ b/include/acpi/actbl2.h
@@ -44,7 +44,8 @@
 #define ACPI_SIG_PMTT           "PMTT"	/* Platform Memory Topology Table */
 #define ACPI_SIG_PPTT           "PPTT"	/* Processor Properties Topology Table */
 #define ACPI_SIG_PRMT           "PRMT"	/* Platform Runtime Mechanism Table */
-#define ACPI_SIG_PTCT           "PTCT"  /* Platform Tuning Configuration Table */
+#define ACPI_SIG_PTCT           "PTCT"	/* Platform Tuning Configuration Table */
+#define ACPI_SIG_RTCT           "RTCT"	/* Real-Time Configuration Table */
 #define ACPI_SIG_RASF           "RASF"	/* RAS Feature table */
 #define ACPI_SIG_RGRT           "RGRT"	/* Regulatory Graphics Resource Table */
 #define ACPI_SIG_SBST           "SBST"	/* Smart Battery Specification Table */
@@ -2361,7 +2362,48 @@ struct ptct_psram_region {
 #define PTCT_ENTRY_PSRAM_SIZE	sizeof(struct acpi_ptct_psram)
 #define PTCT_ACPI_HEADER_SIZE	sizeof(struct acpi_table_header)
 #define PSRAM_REGION_INFO_SIZE	sizeof(struct ptct_psram_region)
-#define MAX_PSRAM_REGIONS	20
+#define MAX_PSRAM_REGIONS	40
+
+/*******************************************************************************
+ *
+ * PTCT - Platform Tuning Configuration Table
+ *        Version 2
+ *
+ ******************************************************************************/
+/* Values for Type field above */
+
+enum acpi_ptct_v2_entry {
+	ACPI_PTCT_V2_ENTRY_COMPATIBILITY        = 0x00,
+	ACPI_PTCT_V2_ENTRY_RTCD_LIMIT           = 0x01,
+	ACPI_PTCT_V2_ENTRY_CRL_BINARY           = 0x02,
+	ACPI_PTCT_V2_ENTRY_IA_WAYMASK           = 0x03,
+	ACPI_PTCT_V2_ENTRY_WRC_WAYMASK          = 0x04,
+	ACPI_PTCT_V2_ENTRY_GT_WAYMASK           = 0x05,
+	ACPI_PTCT_V2_ENTRY_SSRAM_WAYMASK        = 0x06,
+	ACPI_PTCT_V2_ENTRY_SSRAM                = 0x07,
+	ACPI_PTCT_V2_ENTRY_MEMORY_HIERARCHY_LATENCY = 0x08,
+	ACPI_PTCT_V2_ENTRY_ERROR_LOG_ADDRESS    = 0x09,
+
+	ACPI_PTCT_V2_ENTRY_RESERVED
+};
+
+struct acpi_ptct_psram_v2 {
+	u32 cache_level;
+	u32 cache_id;
+	u32 phyaddr_lo;
+	u32 phyaddr_hi;
+	u32 size;
+	u32 shared;
+};
+
+struct acpi_ptct_compatibility {
+	u32 rtct_version;
+	u32 rtct_version_minor;
+	u32 rtcd_version;
+	u32 rtcd_version_minor;
+};
+
+#define PTCT_V2_ENTRY_PSRAM_SIZE   sizeof(struct acpi_ptct_psram_v2)
 
 /*******************************************************************************
  *
-- 
2.25.1

