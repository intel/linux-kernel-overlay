From d8031db18f30b04b146aea3882fe635e8094bb84 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Mon, 8 Jun 2020 00:40:45 +0800
Subject: [PATCH 03/19] tcc: update license header

Fix error/warning in static analyze tool checking.
Update license header to be dual license.
When release device node, the minor bit must be cleared.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 arch/x86/kernel/acpi/boot.c |  3 --
 drivers/tcc/tcc_buffer.c    | 76 ++++++++++++++++++++++++++++++-------
 2 files changed, 62 insertions(+), 17 deletions(-)

diff --git a/arch/x86/kernel/acpi/boot.c b/arch/x86/kernel/acpi/boot.c
index 941c8f942d8c..46330302796a 100644
--- a/arch/x86/kernel/acpi/boot.c
+++ b/arch/x86/kernel/acpi/boot.c
@@ -1238,9 +1238,6 @@ static inline bool is_TCC_range(u64 start, u64 end)
 {
 	int i;
 
-	if (!ptct_psram_regions)
-		return false;
-
 	for (i = 0; i < total_psram_region; i++) {
 		if ((start >= ptct_psram_regions[i].phyaddr_start) &&
 			(end <= ptct_psram_regions[i].phyaddr_end))
diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index 4d4e0557dddc..cd4a83f6e7e0 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -1,12 +1,57 @@
-// SPDX-License-Identifier: GPL-2.0-only
 /*
- * Time Coordinated Compute (TCC)
- *
- * Pseudo SRAM interface support on top of Cache Allocation Technology
- *
- * Copyright (C) 2020 Intel Corporation
- *
- */
+  This file is provided under a dual BSD/GPLv2 license.  When using or
+  redistributing this file, you may do so under either license.
+
+  GPL LICENSE SUMMARY
+
+  Time Coordinated Compute (TCC)
+  Pseudo SRAM interface support on top of Cache Allocation Technology
+  Copyright (C) 2020 Intel Corporation
+
+  This program is free software; you can redistribute it and/or modify
+  it under the terms of version 2 of the GNU General Public License as
+  published by the Free Software Foundation.
+
+  This program is distributed in the hope that it will be useful, but
+  WITHOUT ANY WARRANTY; without even the implied warranty of
+  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
+  General Public License for more details.
+
+  BSD LICENSE
+
+  Time Coordinated Compute (TCC)
+  Pseudo SRAM interface support on top of Cache Allocation Technology
+  Copyright (C) 2020 Intel Corporation
+
+  Redistribution and use in source and binary forms, with or without
+  modification, are permitted provided that the following conditions
+  are met:
+
+    * Redistributions of source code must retain the above copyright
+      notice, this list of conditions and the following disclaimer.
+
+    * Redistributions in binary form must reproduce the above copyright
+      notice, this list of conditions and the following disclaimer in
+      the documentation and/or other materials provided with the
+      distribution.
+
+    * Neither the name of Intel Corporation nor the names of its
+      contributors may be used to endorse or promote products derived
+      from this software without specific prior written permission.
+
+  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
+  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
+  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
+  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
+  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
+  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
+  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
+  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+*/
+
 #define pr_fmt(fmt) "TCC Buffer: " fmt
 
 #include <linux/acpi.h>
@@ -235,8 +280,8 @@ static int tcc_parse_ptct(void)
 	struct tcc_ptct_entry_header *entry_header;
 	struct tcc_ptct_mhlatency *entry_mhl;
 	struct tcc_ptct_psram *entry_psram;
-	struct psram *p_new_psram;
-	struct memory_slot_info *p_memslot;
+	static struct psram *p_new_psram;
+	static struct memory_slot_info *p_memslot;
 
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 
@@ -336,7 +381,7 @@ static u32 tcc_allocate_memslot(u32 id, size_t size)
 	struct device *dev_ret;
 	u32 new_minor = UNDEFINED_DEVNODE;
 	struct psram *p_psram;
-	struct memory_slot_info *p_memslot;
+	static struct memory_slot_info *p_memslot;
 	struct memory_slot_info *p_slot;
 	u32 found = 0;
 	u32 new_size = 0;
@@ -380,18 +425,20 @@ static u32 tcc_allocate_memslot(u32 id, size_t size)
 	}
 
 	dev_ret = device_create(tcc_buffer_class, NULL,
-							MKDEV(tcc_buffer_device_major, new_minor),
-							NULL, TCC_BUFFER_NAME "%d", new_minor);
+				MKDEV(tcc_buffer_device_major, new_minor),
+				NULL, TCC_BUFFER_NAME "%d", new_minor);
 	if (IS_ERR(dev_ret)) {
 		ret = PTR_ERR(dev_ret);
 		pr_err("Failed to create character device\n");
-		goto fail;
+		goto fail_create_device;
 	}
 
 	p_slot->minor = new_minor;
 
 	mutex_unlock(&tccbuffer_mutex);
 	return new_minor;
+fail_create_device:
+	__set_bit(new_minor, &tcc_buffer_device_minor_avail);
 fail:
 	mutex_unlock(&tccbuffer_mutex);
 	return UNDEFINED_DEVNODE;
@@ -405,6 +452,7 @@ static void tcc_free_memslot(struct memory_slot_info *p_memslot)
 
 	mutex_lock(&tccbuffer_mutex);
 	device_destroy(tcc_buffer_class, MKDEV(tcc_buffer_device_major, p_memslot->minor));
+	__set_bit(p_memslot->minor, &tcc_buffer_device_minor_avail);
 	p_memslot->status = MEM_FREE;
 	p_memslot->minor = UNDEFINED_DEVNODE;
 	vaddr = memremap(p_memslot->paddr, p_memslot->size, MEMREMAP_WB);
-- 
2.32.0

