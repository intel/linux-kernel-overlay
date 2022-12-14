From 5c5bb053e30eefca841e324143fd7becbfaa7dfe Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 9 Apr 2021 16:22:34 +0800
Subject: [PATCH 12/22] Remove Clock_Cycles_VT from MHL entry.

No numbers for Clock_Cycles_VT, so this element
in MHL entry should be removed.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 5 ++---
 1 file changed, 2 insertions(+), 3 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index b70cb689930d..d55653a107c4 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -171,7 +171,6 @@ struct tcc_ptct_psram_v2 {
 struct tcc_ptct_mhlatency_v2 {
 	u32 cache_level;
 	u32 latency;
-	u32 latency_VT;
 	u32 *cacheids;
 };
 
@@ -404,9 +403,9 @@ static int tcc_parse_ptct(void)
 		} else if ((ptct_format == FORMAT_V2) && (entry_type == PTCT_V2_MEMORY_HIERARCHY_LATENCY)) {
 			entry_mhl_v2 = (struct tcc_ptct_mhlatency_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
 			if (entry_mhl_v2->cache_level == RGN_L2)
-				p_tcc_config->l2_latency = entry_mhl_v2->latency_VT;
+				p_tcc_config->l2_latency = entry_mhl_v2->latency;
 			else if (entry_mhl_v2->cache_level == RGN_L3)
-				p_tcc_config->l3_latency = entry_mhl_v2->latency_VT;
+				p_tcc_config->l3_latency = entry_mhl_v2->latency;
 		}
 
 		offset += entry_size / sizeof(u32);
-- 
2.25.1

