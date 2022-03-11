From 6e7f487e500c778400e05f691a53a64a931aa59d Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Thu, 10 Feb 2022 18:08:20 +0800
Subject: [PATCH 2/3] tcc: fix patch style problem

Unnecessary blank lines are removed, sort local varibles.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 20 ++++++--------------
 include/acpi/actbl2.h       | 27 +++++++++++----------------
 2 files changed, 17 insertions(+), 30 deletions(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index 898f37577a9f..a79d1158b006 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1248,21 +1248,19 @@ static bool tcc_is_untracked_pat_range(u64 start, u64 end)
 
 static int __init acpi_parse_ptct(struct acpi_table_header *table)
 {
-	u32 total_length = 0;
-	u32 offset = 0;
-	u8  *ptr;
-	u32 id = 0;
-
+	struct acpi_ptct_compatibility  *compatibility;
 	struct acpi_ptct_entry_header *entry;
-	struct acpi_ptct_psram  *psram;
 	struct acpi_ptct_psram_v2  *psram_v2;
-	struct acpi_ptct_compatibility  *compatibility;
+	struct acpi_ptct_psram  *psram;
+	u32 total_length;
+	u32 offset;
+	u32 id = 0;
+	u8  *ptr;
 
 	if (!table)
 		return -EINVAL;
 
 	total_length = table->length;
-
 	/* Parse PTCT table for the first round to determine PTCT version */
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
@@ -1281,7 +1279,6 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 	}
 
 	/* Parse PTCT table for the second round to get number of regions*/
-
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
 
@@ -1301,7 +1298,6 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 		return -EINVAL;
 
 	/* Parse for the third round to record address for each regions */
-
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
 
@@ -1344,10 +1340,6 @@ static void __init acpi_process_ptct(void)
 		x86_platform.is_untracked_pat_range = tcc_is_untracked_pat_range;
 }
 
-/*
- *
- */
-
 static void __init early_acpi_process_madt(void)
 {
 #ifdef CONFIG_X86_LOCAL_APIC
diff --git a/include/acpi/actbl2.h b/include/acpi/actbl2.h
index 1f14170981f2..448bf6f51116 100644
--- a/include/acpi/actbl2.h
+++ b/include/acpi/actbl2.h
@@ -1931,13 +1931,11 @@ struct acpi_prmt_handler_info {
  *        Version 1
  *
  ******************************************************************************/
-
 struct acpi_table_ptct {
-	struct acpi_table_header header;	/* Common ACPI table header */
+	struct acpi_table_header header;
 };
 
 /* Values for Type field above */
-
 enum acpi_ptct_entry {
 	ACPI_PTCT_ENTRY_PTCD_LIMITS              = 1,
 	ACPI_PTCT_ENTRY_PTCM_BINARY              = 2,
@@ -1948,7 +1946,6 @@ enum acpi_ptct_entry {
 	ACPI_PTCT_ENTRY_TIME_AWARE_SUBSYSTEMS    = 7,
 	ACPI_PTCT_ENTRY_REALTIME_IOMMU           = 8,
 	ACPI_PTCT_ENTRY_MEMORY_HIERARCHY_LATENCY = 9,
-
 	ACPI_PTCT_ENTRY_RESERVED
 };
 
@@ -1985,19 +1982,17 @@ struct ptct_psram_region {
  *
  ******************************************************************************/
 /* Values for Type field above */
-
 enum acpi_ptct_v2_entry {
-	ACPI_PTCT_V2_ENTRY_COMPATIBILITY        = 0x00,
-	ACPI_PTCT_V2_ENTRY_RTCD_LIMIT           = 0x01,
-	ACPI_PTCT_V2_ENTRY_CRL_BINARY           = 0x02,
-	ACPI_PTCT_V2_ENTRY_IA_WAYMASK           = 0x03,
-	ACPI_PTCT_V2_ENTRY_WRC_WAYMASK          = 0x04,
-	ACPI_PTCT_V2_ENTRY_GT_WAYMASK           = 0x05,
-	ACPI_PTCT_V2_ENTRY_SSRAM_WAYMASK        = 0x06,
-	ACPI_PTCT_V2_ENTRY_SSRAM                = 0x07,
-	ACPI_PTCT_V2_ENTRY_MEMORY_HIERARCHY_LATENCY = 0x08,
-	ACPI_PTCT_V2_ENTRY_ERROR_LOG_ADDRESS    = 0x09,
-
+	ACPI_PTCT_V2_ENTRY_COMPATIBILITY        = 0,
+	ACPI_PTCT_V2_ENTRY_RTCD_LIMIT           = 1,
+	ACPI_PTCT_V2_ENTRY_CRL_BINARY           = 2,
+	ACPI_PTCT_V2_ENTRY_IA_WAYMASK           = 3,
+	ACPI_PTCT_V2_ENTRY_WRC_WAYMASK          = 4,
+	ACPI_PTCT_V2_ENTRY_GT_WAYMASK           = 5,
+	ACPI_PTCT_V2_ENTRY_SSRAM_WAYMASK        = 6,
+	ACPI_PTCT_V2_ENTRY_SSRAM                = 7,
+	ACPI_PTCT_V2_ENTRY_MEMORY_HIERARCHY_LATENCY = 8,
+	ACPI_PTCT_V2_ENTRY_ERROR_LOG_ADDRESS    = 9,
 	ACPI_PTCT_V2_ENTRY_RESERVED
 };
 
-- 
2.25.1

