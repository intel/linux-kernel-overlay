From 1a96e816fb0e187ab1553b6a8a2941734af1d669 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 10 Jul 2020 17:48:35 +0800
Subject: [PATCH 6/9] tcc: tcc drvier should not exit even if no psram entry.

Driver should work even no pSRAM regions are created, because it is used
by tcc_cache_configurator to read RTCT and configure pSRAM.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 2 +-
 drivers/tcc/tcc_buffer.c    | 5 -----
 2 files changed, 1 insertion(+), 6 deletions(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index b2a2fc7d80b0..7fdcdaebe781 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1285,7 +1285,7 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 
 		ptr += entry->size;
 	}
-	if ((total_psram_region > MAX_PSRAM_REGIONS) && (total_psram_region < 1))
+	if (total_psram_region > MAX_PSRAM_REGIONS)
 		return -EINVAL;
 
 	/* Parse for the second round to record address for each regions */
diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index 544ab59b3a94..ce5d565b68ee 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -319,11 +319,6 @@ static int tcc_parse_ptct(void)
 		tbl_swap = tbl_swap + entry_size / sizeof(u32);
 	} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
 
-	if (p_tcc_config->num_of_psram < 1) {
-		pr_err("No psram found!\n");
-		return -1;
-	}
-
 	l2_start = 0;
 	l2_end = 0;
 
-- 
2.27.0

