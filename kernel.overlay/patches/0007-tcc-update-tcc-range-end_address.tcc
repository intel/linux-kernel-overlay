From 759cb91b41ee358ed0cc46d1fbb3a8779b02bc01 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 4 Sep 2020 16:56:12 +0800
Subject: [PATCH 07/16] tcc: update tcc range end_address.

To report tcc range, start_address is inclusive; but end_address is not.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index e7419ee4b2b2..9376b1692b83 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1286,7 +1286,7 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 		if ((entry->type == ACPI_PTCT_ENTRY_PSEUDO_SRAM) && (id < total_psram_region)) {
 			psram = (struct acpi_ptct_psram *)(ptr+PTCT_ENTRY_HEADER_SIZE);
 			ptct_psram_regions[id].phyaddr_start = ((u64)(psram->phyaddr_lo))|((u64)(psram->phyaddr_hi)<<32);
-			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram->size - 1;
+			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram->size;
 			id++;
 		}
 		ptr += entry->size;
-- 
2.32.0

