From b05bd6b8e81e087f34e040c2e08a5452f344b206 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 4 Sep 2020 17:04:16 +0800
Subject: [PATCH 09/23] tcc: l3 psram region size could become zero after
 exclude l2 inclusive regions

Zero size psram region will still be reported since it's specified in PTCT.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 27 +++++++++++++++------------
 1 file changed, 15 insertions(+), 12 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index c83e71948579..a9f83c1d0722 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -175,9 +175,11 @@ static struct memory_slot_info *tcc_get_memslot(u32 minor)
 	struct memory_slot_info *p_slot;
 
 	list_for_each_entry(p_psram, &p_tcc_config->psrams, node) {
-		list_for_each_entry(p_slot, &p_psram->memslots, node) {
-			if (p_slot->minor == minor)
-				return p_slot;
+		if (p_psram->config.size > 0) {
+			list_for_each_entry(p_slot, &p_psram->memslots, node) {
+				if (p_slot->minor == minor)
+					return p_slot;
+			}
 		}
 	}
 	return NULL;
@@ -386,7 +388,7 @@ static u32 tcc_allocate_memslot(u32 id, size_t size)
 	mutex_lock(&tccbuffer_mutex);
 
 	list_for_each_entry(p_psram, &p_tcc_config->psrams, node) {
-		if (p_psram->config.id == id) {
+		if ((p_psram->config.id == id) && (p_psram->config.size > 0)) {
 			list_for_each_entry(p_slot, &p_psram->memslots, node) {
 				if (p_slot->status == MEM_FREE && p_slot->size >= size) {
 					found = 1;
@@ -645,16 +647,17 @@ static void tcc_cleanup(void)
 	struct memory_slot_info *p_slot, *p_temp_slot;
 
 	list_for_each_entry_safe(p_psram, p_temp_psram, &p_tcc_config->psrams, node) {
-		list_for_each_entry_safe(p_slot, p_temp_slot, &p_psram->memslots, node) {
-			if (p_slot->status != MEM_FREE)
-				device_destroy(tcc_buffer_class, MKDEV(tcc_buffer_device_major, p_slot->minor));
+		if (p_psram->config.size > 0) {
+			list_for_each_entry_safe(p_slot, p_temp_slot, &p_psram->memslots, node) {
+				if (p_slot->status != MEM_FREE)
+					device_destroy(tcc_buffer_class, MKDEV(tcc_buffer_device_major, p_slot->minor));
 
-			list_del(&p_slot->node);
-			kfree(p_slot);
+				list_del(&p_slot->node);
+				kfree(p_slot);
+			}
+			if ((p_psram->vaddr) && (p_psram->config.size > 0))
+				memunmap(p_psram->vaddr);
 		}
-		if (p_psram->vaddr)
-			memunmap(p_psram->vaddr);
-
 		list_del(&p_psram->node);
 		kfree(p_psram);
 	}
-- 
2.25.1

