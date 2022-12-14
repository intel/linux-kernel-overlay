From db6fd6c43a758647e513b0dcc49ad041fd10dab6 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Thu, 11 Jun 2020 02:09:09 +0800
Subject: [PATCH 04/22] tcc: L3 psram region should not overlay L2 psram
 region.

Update logic to calculate L3 cache region size for inclusive case.
L3 psram region exposed to user should not overlay L2 psram resion.
And, extract structure and ioctls from source to header file for
reference.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 288 ++++++++++++++++++++-------------------
 drivers/tcc/tcc_buffer.h | 140 +++++++++++++++++++
 2 files changed, 286 insertions(+), 142 deletions(-)
 create mode 100644 drivers/tcc/tcc_buffer.h

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index cd4a83f6e7e0..ee631d3e1a8e 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -1,61 +1,61 @@
+// SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
 /*
-  This file is provided under a dual BSD/GPLv2 license.  When using or
-  redistributing this file, you may do so under either license.
-
-  GPL LICENSE SUMMARY
-
-  Time Coordinated Compute (TCC)
-  Pseudo SRAM interface support on top of Cache Allocation Technology
-  Copyright (C) 2020 Intel Corporation
-
-  This program is free software; you can redistribute it and/or modify
-  it under the terms of version 2 of the GNU General Public License as
-  published by the Free Software Foundation.
-
-  This program is distributed in the hope that it will be useful, but
-  WITHOUT ANY WARRANTY; without even the implied warranty of
-  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-  General Public License for more details.
-
-  BSD LICENSE
-
-  Time Coordinated Compute (TCC)
-  Pseudo SRAM interface support on top of Cache Allocation Technology
-  Copyright (C) 2020 Intel Corporation
-
-  Redistribution and use in source and binary forms, with or without
-  modification, are permitted provided that the following conditions
-  are met:
-
-    * Redistributions of source code must retain the above copyright
-      notice, this list of conditions and the following disclaimer.
-
-    * Redistributions in binary form must reproduce the above copyright
-      notice, this list of conditions and the following disclaimer in
-      the documentation and/or other materials provided with the
-      distribution.
-
-    * Neither the name of Intel Corporation nor the names of its
-      contributors may be used to endorse or promote products derived
-      from this software without specific prior written permission.
-
-  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
-  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
-  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
-  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
-  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
-  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-*/
+ *  This file is provided under a dual BSD/GPLv2 license.  When using or
+ *  redistributing this file, you may do so under either license.
+ *
+ *  GPL LICENSE SUMMARY
+ *
+ *  Time Coordinated Compute (TCC)
+ *  Pseudo SRAM interface support on top of Cache Allocation Technology
+ *  Copyright (C) 2020 Intel Corporation
+ *
+ *  This program is free software; you can redistribute it and/or modify
+ *  it under the terms of version 2 of the GNU General Public License as
+ *  published by the Free Software Foundation.
+ *
+ *  This program is distributed in the hope that it will be useful, but
+ *  WITHOUT ANY WARRANTY; without even the implied warranty of
+ *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
+ *  General Public License for more details.
+ *
+ *  BSD LICENSE
+ *
+ *  Time Coordinated Compute (TCC)
+ *  Pseudo SRAM interface support on top of Cache Allocation Technology
+ *  Copyright (C) 2020 Intel Corporation
+ *
+ *  Redistribution and use in source and binary forms, with or without
+ *  modification, are permitted provided that the following conditions
+ *  are met:
+ *
+ *    * Redistributions of source code must retain the above copyright
+ *      notice, this list of conditions and the following disclaimer.
+ *
+ *    * Redistributions in binary form must reproduce the above copyright
+ *      notice, this list of conditions and the following disclaimer in
+ *      the documentation and/or other materials provided with the
+ *      distribution.
+ *
+ *    * Neither the name of Intel Corporation nor the names of its
+ *      contributors may be used to endorse or promote products derived
+ *      from this software without specific prior written permission.
+ *
+ *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
+ *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
+ *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
+ *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
+ *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
+ *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
+ *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
+ *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
 
 #define pr_fmt(fmt) "TCC Buffer: " fmt
 
 #include <linux/acpi.h>
-#include <linux/ioctl.h>
 #include <linux/kernel.h>
 #include <linux/list.h>
 #include <linux/mm.h>
@@ -63,81 +63,43 @@
 #include <linux/types.h>
 #include <linux/version.h>
 
-enum ioctl_index {
-	IOCTL_TCC_GET_REGION_COUNT = 1,
-	IOCTL_TCC_GET_MEMORY_CONFIG,
-	IOCTL_TCC_REQ_BUFFER,
-	IOCTL_TCC_QUERY_PTCT_SIZE,
-	IOCTL_TCC_GET_PTCT
-};
-
-#define TCC_GET_REGION_COUNT \
-	_IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGION_COUNT, unsigned int *)
-
-#define TCC_GET_MEMORY_CONFIG                               \
-	_IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_MEMORY_CONFIG, \
-		  struct tcc_buf_mem_config_s *)
-
-#define TCC_REQ_BUFFER \
-	_IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_REQ_BUFFER, struct tcc_buf_mem_req_s *)
-
-#define TCC_QUERY_PTCT_SIZE \
-	_IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_QUERY_PTCT_SIZE, unsigned int *)
+#include "tcc_buffer.h"
 
-#define TCC_GET_PTCT _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_PTCT, unsigned int *)
-
-#define ACPI_SIG_PTCT "PTCT"
+#define ACPI_SIG_PTCT             "PTCT"
 #define PTCT_ENTRY_OFFSET_VERSION 0
-#define PTCT_ENTRY_OFFSET_SIZE 0
-#define PTCT_ENTRY_OFFSET_TYPE 1
+#define PTCT_ENTRY_OFFSET_SIZE    0
+#define PTCT_ENTRY_OFFSET_TYPE    1
 
-#define PSRAM_OFFSET_CACHELEVEL (PTCT_ENTRY_OFFSET_TYPE + 1)
-#define PSRAM_OFFSET_PADDR_LO (PSRAM_OFFSET_CACHELEVEL + 1)
-#define PSRAM_OFFSET_PADDR_HI (PSRAM_OFFSET_PADDR_LO + 1)
-#define PSRAM_OFFSET_WAY (PSRAM_OFFSET_PADDR_HI + 1)
-#define PSRAM_OFFSET_SIZE (PSRAM_OFFSET_WAY + 1)
-#define PSRAM_OFFSET_APIC (PSRAM_OFFSET_SIZE + 1)
+#define PSRAM_OFFSET_CACHELEVEL   (PTCT_ENTRY_OFFSET_TYPE + 1)
+#define PSRAM_OFFSET_PADDR_LO     (PSRAM_OFFSET_CACHELEVEL + 1)
+#define PSRAM_OFFSET_PADDR_HI     (PSRAM_OFFSET_PADDR_LO + 1)
+#define PSRAM_OFFSET_WAY          (PSRAM_OFFSET_PADDR_HI + 1)
+#define PSRAM_OFFSET_SIZE         (PSRAM_OFFSET_WAY + 1)
+#define PSRAM_OFFSET_APIC         (PSRAM_OFFSET_SIZE + 1)
 
-#define MHL_OFFSET_HIERARCHY (PTCT_ENTRY_OFFSET_TYPE + 1)
-#define MHL_OFFSET_CLOCKCYCLES (MHL_OFFSET_HIERARCHY + 1)
-#define MHL_OFFSET_APIC (MHL_OFFSET_CLOCKCYCLES + 1)
+#define MHL_OFFSET_HIERARCHY      (PTCT_ENTRY_OFFSET_TYPE + 1)
+#define MHL_OFFSET_CLOCKCYCLES    (MHL_OFFSET_HIERARCHY + 1)
+#define MHL_OFFSET_APIC           (MHL_OFFSET_CLOCKCYCLES + 1)
 
 enum PTCT_ENTRY_TYPE {
-	PTCT_PTCD_LIMITS = 0x00000001,
-	PTCT_PTCM_BINARY = 0x00000002,
-	PTCT_WRC_L3_WAYMASK = 0x00000003,
-	PTCT_GT_L3_WAYMASK = 0x00000004,
-	PTCT_PESUDO_SRAM = 0x00000005,
-	PTCT_STREAM_DATAPATH = 0x00000006,
-	PTCT_TIMEAWARE_SUBSYSTEMS = 0x00000007,
-	PTCT_REALTIME_IOMMU = 0x00000008,
-	PTCT_MEMORY_HIERARCHY_LATENCY = 0x00000009,
+	PTCT_PTCD_LIMITS          = 1,
+	PTCT_PTCM_BINARY          = 2,
+	PTCT_WRC_L3_WAYMASK       = 3,
+	PTCT_GT_L3_WAYMASK        = 4,
+	PTCT_PESUDO_SRAM          = 5,
+	PTCT_STREAM_DATAPATH      = 6,
+	PTCT_TIMEAWARE_SUBSYSTEMS = 7,
+	PTCT_REALTIME_IOMMU       = 8,
+	PTCT_MEMORY_HIERARCHY_LATENCY = 9,
 	PTCT_ENTRY_TYPE_NUMS
 };
 
 #define ENTRY_HEADER_SIZE (sizeof(struct tcc_ptct_entry_header) / sizeof(u32))
 #define ACPI_HEADER_SIZE (sizeof(struct acpi_table_header) / sizeof(u32))
 
-/* TCC Device Interface */
-#define TCC_BUFFER_NAME "/tcc/tcc_buffer"
-#define UNDEFINED_DEVNODE 256
-
-/* IOCTL MAGIC number */
-#define IOCTL_TCC_MAGIC 'T'
-
 #define MEM_FREE 0
 #define MEM_BUSY 1
 
-enum tcc_buf_region_type {
-	RGN_UNKNOWN = 0,
-	RGN_L1,
-	RGN_L2,
-	RGN_L3,
-	RGN_EDRAM,
-	RGN_MALLOC, /* DRAM */
-	RGN_TOTAL_TYPES
-};
-
 struct tcc_ptct_entry_header {
 	u16 size;
 	u16 format;
@@ -159,21 +121,6 @@ struct tcc_ptct_mhlatency {
 	u32 *apicids;
 };
 
-struct tcc_buf_mem_config_s {
-	unsigned int id;
-	unsigned int latency;
-	size_t size;
-	enum tcc_buf_region_type type;
-	unsigned int ways;
-	void *cpu_mask_p;
-};
-
-struct tcc_buf_mem_req_s {
-	unsigned int id;
-	size_t size;
-	unsigned int devnode;
-};
-
 struct memory_slot_info {
 	u64 paddr;
 	size_t size;
@@ -282,6 +229,8 @@ static int tcc_parse_ptct(void)
 	struct tcc_ptct_psram *entry_psram;
 	static struct psram *p_new_psram;
 	static struct memory_slot_info *p_memslot;
+	struct psram *p_tmp_psram;
+	u64 l2_start, l2_end, l3_start, l3_end;
 
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 
@@ -342,27 +291,25 @@ static int tcc_parse_ptct(void)
 			if (entry_psram->cache_level == RGN_L2) {
 				p_new_psram->config.latency = p_tcc_config->l2_latency;
 				tcc_get_psram_cpumask(entry_psram->apic_id, p_tcc_config->l2_num_of_threads_share, &p_new_psram->cpumask);
-
+				p_new_psram->vaddr = memremap(p_new_psram->paddr, p_new_psram->config.size, MEMREMAP_WB);
+				INIT_LIST_HEAD(&p_new_psram->memslots);
+
+				p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
+				if (!p_memslot)
+					return -1;
+
+				p_memslot->paddr = p_new_psram->paddr;
+				p_memslot->size = p_new_psram->config.size;
+				p_memslot->status = MEM_FREE;
+				p_memslot->minor = UNDEFINED_DEVNODE;
+				list_add_tail(&p_memslot->node, &p_new_psram->memslots);
 			} else if (entry_psram->cache_level == RGN_L3) {
 				p_new_psram->config.latency = p_tcc_config->l3_latency;
 				tcc_get_psram_cpumask(entry_psram->apic_id, p_tcc_config->l3_num_of_threads_share, &p_new_psram->cpumask);
 			}
 
 			p_new_psram->config.cpu_mask_p = (void *)&p_new_psram->cpumask;
-			p_new_psram->vaddr = memremap(p_new_psram->paddr, p_new_psram->config.size, MEMREMAP_WB);
-			INIT_LIST_HEAD(&p_new_psram->memslots);
-
-			p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
-			if (!p_memslot)
-				return -1;
-
-			p_memslot->paddr = p_new_psram->paddr;
-			p_memslot->size = p_new_psram->config.size;
-			p_memslot->status = MEM_FREE;
-			p_memslot->minor = UNDEFINED_DEVNODE;
-
 			list_add_tail(&p_new_psram->node, &p_tcc_config->psrams);
-			list_add_tail(&p_memslot->node, &p_new_psram->memslots);
 			break;
 
 		default:
@@ -372,6 +319,59 @@ static int tcc_parse_ptct(void)
 		offset += entry_size / sizeof(u32);
 		tbl_swap = tbl_swap + entry_size / sizeof(u32);
 	} while ((offset < (acpi_ptct_tbl->length) / sizeof(u32)) && entry_size);
+
+	l2_start = 0;
+	l2_end = 0;
+
+	list_for_each_entry(p_tmp_psram, &p_tcc_config->psrams, node) {
+		if (p_tmp_psram->config.type == RGN_L2) {
+			if (l2_start == 0 && l2_end == 0) {
+				l2_start = p_tmp_psram->paddr;
+				l2_end = p_tmp_psram->paddr + p_tmp_psram->config.size;
+			} else {
+				if (p_tmp_psram->paddr < l2_start)
+					l2_start = p_tmp_psram->paddr;
+
+				if (p_tmp_psram->paddr + p_tmp_psram->config.size > l2_end)
+					l2_end = p_tmp_psram->paddr + p_tmp_psram->config.size;
+			}
+		}
+	}
+
+	list_for_each_entry(p_tmp_psram, &p_tcc_config->psrams, node) {
+		if (p_tmp_psram->config.type == RGN_L3) {
+			l3_start = p_tmp_psram->paddr;
+			l3_end = p_tmp_psram->paddr + p_tmp_psram->config.size;
+
+			if (l2_start <= l3_start) {
+				if (l2_end < l3_end) {
+					if (l2_end > l3_start)
+						l3_start = l2_end;
+				} else
+					l3_start = l3_end;
+			} else if (l2_start <= l3_end)
+				l3_end = l2_start;
+
+			p_tmp_psram->paddr = l3_start;
+			p_tmp_psram->config.size = l3_end - l3_start;
+
+			if (p_tmp_psram->config.size > 0) {
+				p_tmp_psram->vaddr = memremap(p_tmp_psram->paddr, p_tmp_psram->config.size, MEMREMAP_WB);
+				INIT_LIST_HEAD(&p_tmp_psram->memslots);
+
+				p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
+				if (!p_memslot)
+					return -1;
+
+				p_memslot->paddr = p_tmp_psram->paddr;
+				p_memslot->size = p_tmp_psram->config.size;
+				p_memslot->status = MEM_FREE;
+				p_memslot->minor = UNDEFINED_DEVNODE;
+				list_add_tail(&p_memslot->node, &p_tmp_psram->memslots);
+			}
+		}
+	}
+
 	return 0;
 }
 
@@ -487,6 +487,10 @@ static int tcc_buffer_open(struct inode *i, struct file *f)
 		pr_err("OPEN(): No device node %u.\n", MINOR(i->i_rdev));
 		return -ECHRNG;
 	}
+	if (p_memslot->open_count > 0) {
+		pr_err("OPEN(): This device is already open.\n");
+		return -1;
+	}
 	p_memslot->open_count++;
 	f->private_data = p_memslot;
 	return 0;
diff --git a/drivers/tcc/tcc_buffer.h b/drivers/tcc/tcc_buffer.h
new file mode 100644
index 000000000000..90ae36c62fe2
--- /dev/null
+++ b/drivers/tcc/tcc_buffer.h
@@ -0,0 +1,140 @@
+/* SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause */
+/*
+ *
+ *  This file is provided under a dual BSD/GPLv2 license.  When using or
+ *  redistributing this file, you may do so under either license.
+ *
+ *  GPL LICENSE SUMMARY
+ *
+ *  Time Coordinated Compute (TCC)
+ *  Pseudo SRAM interface support on top of Cache Allocation Technology
+ *  Copyright (C) 2020 Intel Corporation
+ *
+ *  This program is free software; you can redistribute it and/or modify
+ *  it under the terms of version 2 of the GNU General Public License as
+ *  published by the Free Software Foundation.
+ *
+ *  This program is distributed in the hope that it will be useful, but
+ *  WITHOUT ANY WARRANTY; without even the implied warranty of
+ *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
+ *  General Public License for more details.
+ *
+ *  BSD LICENSE
+ *
+ *  Time Coordinated Compute (TCC)
+ *  Pseudo SRAM interface support on top of Cache Allocation Technology
+ *  Copyright (C) 2020 Intel Corporation
+ *
+ *  Redistribution and use in source and binary forms, with or without
+ *  modification, are permitted provided that the following conditions
+ *  are met:
+ *
+ *    * Redistributions of source code must retain the above copyright
+ *      notice, this list of conditions and the following disclaimer.
+ *
+ *    * Redistributions in binary form must reproduce the above copyright
+ *      notice, this list of conditions and the following disclaimer in
+ *      the documentation and/or other materials provided with the
+ *      distribution.
+ *
+ *    * Neither the name of Intel Corporation nor the names of its
+ *      contributors may be used to endorse or promote products derived
+ *      from this software without specific prior written permission.
+ *
+ *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
+ *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
+ *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
+ *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
+ *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
+ *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
+ *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
+ *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+
+#include <linux/ioctl.h>
+
+/* TCC Device Interface */
+#define TCC_BUFFER_NAME  "/tcc/tcc_buffer"
+#define UNDEFINED_DEVNODE 256
+
+/* IOCTL MAGIC number */
+#define IOCTL_TCC_MAGIC   'T'
+
+enum tcc_buf_region_type {
+	RGN_UNKNOWN = 0,
+	RGN_L1,
+	RGN_L2,
+	RGN_L3,
+	RGN_EDRAM,
+	RGN_MALLOC, /* DRAM */
+	RGN_TOTAL_TYPES
+};
+
+/*
+ * IN:
+ * id: pseudo-SRAM region id from which user request for attribute.
+ * OUT:
+ * latency: delay in clockcycles
+ * type: the type of the memory pSRAM region
+ * size: total size in byte
+ * ways: the cache ways used to create the pSRAM region.
+ * cpu_mask_p: affinity bitmask of the logical cores available for access to the pSRAM region
+ */
+struct tcc_buf_mem_config_s {
+	unsigned int id;
+	unsigned int latency;
+	size_t size;
+	enum tcc_buf_region_type type;
+	unsigned int ways;
+	void *cpu_mask_p;
+};
+
+/*
+ * IN:
+ * id: pseudo-SRAM region id, from which user request for buffer
+ * size: buffer size (byte).
+ * OUT:
+ * devnode: driver returns device node to user
+ */
+struct tcc_buf_mem_req_s {
+	unsigned int id;
+	size_t size;
+	unsigned int devnode;
+};
+
+enum ioctl_index {
+	IOCTL_TCC_GET_REGION_COUNT = 1,
+	IOCTL_TCC_GET_MEMORY_CONFIG,
+	IOCTL_TCC_REQ_BUFFER,
+	IOCTL_TCC_QUERY_PTCT_SIZE,
+	IOCTL_TCC_GET_PTCT
+};
+
+/*
+ * User to get pseudo-SRAM region counts
+ */
+#define TCC_GET_REGION_COUNT _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGION_COUNT, unsigned int *)
+
+/*
+ * User to get memory config of selected region
+ */
+#define TCC_GET_MEMORY_CONFIG _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_MEMORY_CONFIG, struct tcc_buf_mem_config_s *)
+
+/*
+ * User to query PTCT size
+ */
+#define TCC_QUERY_PTCT_SIZE _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_QUERY_PTCT_SIZE, unsigned int *)
+
+/*
+ * User to get PTCT data
+ */
+#define TCC_GET_PTCT _IOR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_PTCT, unsigned int *)
+
+/*
+ * User to request pseudo-SRAM buffer from selected region
+ */
+#define TCC_REQ_BUFFER _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_REQ_BUFFER, struct tcc_buf_mem_req_s *)
+
-- 
2.25.1

