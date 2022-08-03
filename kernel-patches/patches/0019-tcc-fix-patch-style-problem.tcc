From e8c68bee50267b60e97739ac8e351c731cdea4cb Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Thu, 10 Feb 2022 18:08:20 +0800
Subject: [PATCH 19/23] tcc: fix patch style problem

Unnecessary blank lines are removed, sort local varibles.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 20 ++++++--------------
 include/acpi/actbl2.h       | 27 +++++++++++----------------
 2 files changed, 17 insertions(+), 30 deletions(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index 3bbae9b0de32..9f5a62f112ab 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1339,21 +1339,19 @@ static bool tcc_is_untracked_pat_range(u64 start, u64 end)
 
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
@@ -1372,7 +1370,6 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 	}
 
 	/* Parse PTCT table for the second round to get number of regions*/
-
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
 
@@ -1392,7 +1389,6 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 		return -EINVAL;
 
 	/* Parse for the third round to record address for each regions */
-
 	ptr = (u8 *)table;
 	ptr += PTCT_ACPI_HEADER_SIZE;
 
@@ -1435,10 +1431,6 @@ static void __init acpi_process_ptct(void)
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
index e3205c806a81..5964f95a84c9 100644
--- a/include/acpi/actbl2.h
+++ b/include/acpi/actbl2.h
@@ -2317,13 +2317,11 @@ struct acpi_prmt_handler_info {
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
@@ -2334,7 +2332,6 @@ enum acpi_ptct_entry {
 	ACPI_PTCT_ENTRY_TIME_AWARE_SUBSYSTEMS    = 7,
 	ACPI_PTCT_ENTRY_REALTIME_IOMMU           = 8,
 	ACPI_PTCT_ENTRY_MEMORY_HIERARCHY_LATENCY = 9,
-
 	ACPI_PTCT_ENTRY_RESERVED
 };
 
@@ -2371,19 +2368,17 @@ struct ptct_psram_region {
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

