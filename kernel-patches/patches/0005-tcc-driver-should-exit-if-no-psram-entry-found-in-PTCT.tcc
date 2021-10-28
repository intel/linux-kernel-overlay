From be3f31762394674cfcf1f489ce8ff91807ef0efa Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Mon, 15 Jun 2020 09:55:13 +0800
Subject: [PATCH 05/16] tcc: driver should exit if no psram entry found in
 PTCT.

In TCC SKU BIOS, PTCT is always presented in ACPI. If TCC option
is enabled in BIOS, there will be psram entry in PTCT; if TCC option
is disabled in BIOS, then no psram entry in PTCT.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 2 +-
 drivers/tcc/tcc_buffer.c    | 8 ++++++--
 2 files changed, 7 insertions(+), 3 deletions(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index e7419ee4b2b2..29adf4997397 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1271,7 +1271,7 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 
 		ptr += entry->size;
 	}
-	if (total_psram_region > MAX_PSRAM_REGIONS)
+	if ((total_psram_region > MAX_PSRAM_REGIONS) && (total_psram_region < 1))
 		return -EINVAL;
 
 	/* Parse for the second round to record address for each regions */
diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index ee631d3e1a8e..544ab59b3a94 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -65,7 +65,6 @@
 
 #include "tcc_buffer.h"
 
-#define ACPI_SIG_PTCT             "PTCT"
 #define PTCT_ENTRY_OFFSET_VERSION 0
 #define PTCT_ENTRY_OFFSET_SIZE    0
 #define PTCT_ENTRY_OFFSET_TYPE    1
@@ -320,6 +319,11 @@ static int tcc_parse_ptct(void)
 		tbl_swap = tbl_swap + entry_size / sizeof(u32);
 	} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
 
+	if (p_tcc_config->num_of_psram < 1) {
+		pr_err("No psram found!\n");
+		return -1;
+	}
+
 	l2_start = 0;
 	l2_end = 0;
 
@@ -744,4 +748,4 @@ static void __exit tcc_buffer_exit(void)
 module_init(tcc_buffer_init);
 module_exit(tcc_buffer_exit);
 
-MODULE_LICENSE("GPL v2");
+MODULE_LICENSE("Dual BSD/GPL");
-- 
2.32.0

