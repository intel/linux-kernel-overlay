From 49090fc7b06b1cd59f3d830de1487c00cd6e4bab Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 16 Oct 2020 14:43:41 +0800
Subject: [PATCH 1/9] tcc: parse PTCT table and record pesudo sram ranges

ACPI may include PTCT table. If PTCT is included, this table need to be parsed
and records all pesudo SRAM ranges indicated in the table. These pesudo SRAM
should be marked as cacheable for the tcc feature.

If PTCT is not found in ACPI, nothing will be changed.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 95 +++++++++++++++++++++++++++++++++++++
 include/acpi/actbl2.h       | 54 +++++++++++++++++++++
 2 files changed, 149 insertions(+)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index e90310cbe73a..6f7af786d41e 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1232,6 +1232,96 @@ static inline int acpi_parse_madt_ioapic_entries(void)
 }
 #endif	/* !CONFIG_X86_IO_APIC */
 
+/*
+ * Parse pSRAM entry in PTCT
+ * Update PAT cache attribute configuration range
+ */
+static struct ptct_psram_region ptct_psram_regions[MAX_PSRAM_REGIONS];
+static u32 total_psram_region;
+
+static inline bool is_TCC_range(u64 start, u64 end)
+{
+	int i;
+
+	if (!ptct_psram_regions)
+		return false;
+
+	for (i = 0; i < total_psram_region; i++) {
+		if ((start >= ptct_psram_regions[i].phyaddr_start) &&
+			(end <= ptct_psram_regions[i].phyaddr_end))
+			return true;
+	}
+	return false;
+}
+
+static bool tcc_is_untracked_pat_range(u64 start, u64 end)
+{
+	return is_ISA_range(start, end) || is_TCC_range(start, end);
+}
+
+static int __init acpi_parse_ptct(struct acpi_table_header *table)
+{
+	u32 total_length = 0;
+	u32 offset = 0;
+	u8  *ptr;
+	u32 id = 0;
+
+	struct acpi_ptct_entry_header *entry;
+	struct acpi_ptct_psram  *psram;
+
+	if (!table)
+		return -EINVAL;
+
+	total_length = table->length;
+
+	/* Parse PTCT table for the first round to get number of regions*/
+
+	ptr = (u8 *)table;
+	ptr += PTCT_ACPI_HEADER_SIZE;
+
+	for (offset = PTCT_ACPI_HEADER_SIZE; offset < total_length;) {
+		entry = (struct acpi_ptct_entry_header *)(ptr);
+		offset += entry->size;
+
+		if (entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM)
+			total_psram_region++;
+
+		ptr += entry->size;
+	}
+	if (total_psram_region > MAX_PSRAM_REGIONS)
+		return -EINVAL;
+
+	/* Parse for the second round to record address for each regions */
+
+	ptr = (u8 *)table;
+	ptr += PTCT_ACPI_HEADER_SIZE;
+
+	for (offset = PTCT_ACPI_HEADER_SIZE; offset < total_length;) {
+		entry = (struct acpi_ptct_entry_header *)(ptr);
+		offset += entry->size;
+
+		if ((entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM) && (id < total_psram_region)) {
+			psram = (struct acpi_ptct_psram *)(ptr+PTCT_ENTRY_HEADER_SIZE);
+			ptct_psram_regions[id].phyaddr_start = ((u64)(psram->phyaddr_lo))|((u64)(psram->phyaddr_hi)<<32);
+			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram->size - 1;
+			id++;
+		}
+		ptr += entry->size;
+	}
+
+	return 0;
+}
+
+static void __init acpi_process_ptct(void)
+{
+	if (!acpi_table_parse(ACPI_SIG_PTCT, acpi_parse_ptct))
+		x86_platform.is_untracked_pat_range = tcc_is_untracked_pat_range;
+}
+
+/*
+ *
+ */
+
 static void __init early_acpi_process_madt(void)
 {
 #ifdef CONFIG_X86_LOCAL_APIC
@@ -1622,6 +1712,11 @@ int __init acpi_boot_init(void)
 	if (IS_ENABLED(CONFIG_ACPI_BGRT) && !acpi_nobgrt)
 		acpi_table_parse(ACPI_SIG_BGRT, acpi_parse_bgrt);
 
+	/*
+	 * Process the Platform Tuning Configuration Table (PTCT), if present
+	 */
+	acpi_process_ptct();
+
 	if (!acpi_noirq)
 		x86_init.pci.init = pci_acpi_init;
 
diff --git a/include/acpi/actbl2.h b/include/acpi/actbl2.h
index 18cafe3ebddc..fbdd8428e487 100644
--- a/include/acpi/actbl2.h
+++ b/include/acpi/actbl2.h
@@ -39,6 +39,7 @@
 #define ACPI_SIG_PHAT           "PHAT"	/* Platform Health Assessment Table */
 #define ACPI_SIG_PMTT           "PMTT"	/* Platform Memory Topology Table */
 #define ACPI_SIG_PPTT           "PPTT"	/* Processor Properties Topology Table */
+#define ACPI_SIG_PTCT           "PTCT"	/* Platform Tuning Configuration Table */
 #define ACPI_SIG_RASF           "RASF"	/* RAS Feature table */
 #define ACPI_SIG_SBST           "SBST"	/* Smart Battery Specification Table */
 #define ACPI_SIG_SDEI           "SDEI"	/* Software Delegated Exception Interface Table */
@@ -1673,6 +1674,59 @@ struct acpi_pptt_id {
 	u16 spin_rev;
 };
 
+/*******************************************************************************
+ *
+ * PTCT - Platform Tuning Configuration Table
+ *        Version 1
+ *
+ ******************************************************************************/
+
+struct acpi_table_ptct {
+	struct acpi_table_header header;	/* Common ACPI table header */
+};
+
+/* Values for Type field above */
+
+enum acpi_ptct_entry {
+	ACPI_PTCT_ENTRY_PTCD_LIMITS              = 1,
+	ACPI_PTCT_ENTRY_PTCM_BINARY              = 2,
+	ACPI_PTCT_ENTRY_WRC_L3_WAY_MASKS         = 3,
+	ACPI_PTCT_ENTRY_GT_L3_WAY_MASKS          = 4,
+	ACPI_PTCT_ENTRY_PSEUDO_SRAM              = 5,
+	ACPI_PTCT_ENTRY_STREAM_DATA_PATH         = 6,
+	ACPI_PTCT_ENTRY_TIME_AWARE_SUBSYSTEMS    = 7,
+	ACPI_PTCT_ENTRY_REALTIME_IOMMU           = 8,
+	ACPI_PTCT_ENTRY_MEMORY_HIERARCHY_LATENCY = 9,
+
+	ACPI_PTCT_ENTRY_RESERVED
+};
+
+struct acpi_ptct_entry_header {
+	u16 size;
+	u16 format;
+	u32 type;
+};
+
+struct acpi_ptct_psram {
+	u32 cache_level;
+	u32 phyaddr_lo;
+	u32 phyaddr_hi;
+	u32 cache_ways;
+	u32 size;
+	u32 apic_id;
+};
+
+struct ptct_psram_region {
+	u64 phyaddr_start;
+	u64 phyaddr_end;
+};
+
+#define PTCT_ENTRY_HEADER_SIZE	sizeof(struct acpi_ptct_entry_header)
+#define PTCT_ENTRY_PSRAM_SIZE	sizeof(struct acpi_ptct_psram)
+#define PTCT_ACPI_HEADER_SIZE	sizeof(struct acpi_table_header)
+#define PSRAM_REGION_INFO_SIZE	sizeof(struct ptct_psram_region)
+#define MAX_PSRAM_REGIONS		20
+
 /*******************************************************************************
  *
  * RASF - RAS Feature Table (ACPI 5.0)
-- 
2.27.0

