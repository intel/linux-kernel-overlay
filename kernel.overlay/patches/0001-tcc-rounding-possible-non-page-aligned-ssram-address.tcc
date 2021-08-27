From a70bb6a927c84079200a53c29462319293d3df1d Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Sun, 8 Aug 2021 03:13:01 +0800
Subject: [PATCH] tcc: rounding possible non page-aligned ssram address

ssram address and size could be not aligned to page boundary for some skus.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c | 8 ++++++++
 1 file changed, 8 insertions(+)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index e54723f00fec..644dcfdc432e 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1329,6 +1329,10 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 			psram = (struct acpi_ptct_psram *)(ptr + PTCT_ENTRY_HEADER_SIZE);
 			ptct_psram_regions[id].phyaddr_start = ((u64)(psram->phyaddr_lo)) | ((u64)(psram->phyaddr_hi) << 32);
 			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram->size;
+			if (ptct_psram_regions[id].phyaddr_start & (PAGE_SIZE - 1))
+				ptct_psram_regions[id].phyaddr_start -= ptct_psram_regions[id].phyaddr_start & (PAGE_SIZE - 1);
+			if (ptct_psram_regions[id].phyaddr_end & (PAGE_SIZE - 1))
+				ptct_psram_regions[id].phyaddr_end += PAGE_SIZE - (ptct_psram_regions[id].phyaddr_end & (PAGE_SIZE - 1));
 			id++;
 		} else if ((acpi_ptct_format == ACPI_PTCT_FORMAT_V2) &&
 		    (entry->type == ACPI_PTCT_V2_ENTRY_SSRAM) &&
@@ -1336,6 +1340,10 @@ static int __init acpi_parse_ptct(struct acpi_table_header *table)
 			psram_v2 = (struct acpi_ptct_psram_v2 *)(ptr + PTCT_ENTRY_HEADER_SIZE);
 			ptct_psram_regions[id].phyaddr_start = ((u64)(psram_v2->phyaddr_lo)) | ((u64)(psram_v2->phyaddr_hi) << 32);
 			ptct_psram_regions[id].phyaddr_end  = ptct_psram_regions[id].phyaddr_start + psram_v2->size;
+			if (ptct_psram_regions[id].phyaddr_start & (PAGE_SIZE - 1))
+				ptct_psram_regions[id].phyaddr_start -= ptct_psram_regions[id].phyaddr_start & (PAGE_SIZE - 1);
+			if (ptct_psram_regions[id].phyaddr_end & (PAGE_SIZE - 1))
+				ptct_psram_regions[id].phyaddr_end += PAGE_SIZE - (ptct_psram_regions[id].phyaddr_end & (PAGE_SIZE - 1));
 			id++;
 		}
 		ptr += entry->size;
-- 
2.27.0
