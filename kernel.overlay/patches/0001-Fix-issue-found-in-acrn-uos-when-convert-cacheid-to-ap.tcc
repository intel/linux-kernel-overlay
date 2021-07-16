From c3659874fc2ba321471fbcd59777be3077842755 Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Fri, 18 Jun 2021 00:38:44 +0800
Subject: [PATCH] Fix issue found in acrn uos when convert cacheid to apicid.

Output errlog buffer to proc file.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 54 ++++++++++++++++++++++++----------------
 1 file changed, 33 insertions(+), 21 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index c89d87b01f95..4dc86a8cefc8 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -74,6 +74,7 @@
 #include <linux/smp.h>
 #include <linux/list.h>
 #include <linux/mm.h>
+#include <linux/seq_file.h>
 #include "tcc_buffer.h"
 
 /*
@@ -249,7 +250,7 @@ static u32 errsize;
 static u32 tcc_init;
 static u32 ptct_format = FORMAT_V1;
 DEFINE_MUTEX(tccbuffer_mutex);
-
+static int tcc_errlog_show(struct seq_file *m, void *v);
 /****************************************************************************/
 /*These MACROs may not yet defined in previous kernel version*/
 #ifndef INTEL_FAM6_ALDERLAKE
@@ -650,25 +651,49 @@ static void tcc_get_psram_cpumask(u32 coreid, u32 num_threads_sharing, cpumask_t
 	u32 index_msb, id;
 	u32 apicid = 0;
 
+	index_msb = get_count_order(num_threads_sharing);
 	if (ptct_format == FORMAT_V2)
-		apicid = cpu_data(coreid).apicid;
+		apicid = coreid << index_msb;
 	else
 		apicid = coreid;
-
+	dprintk("apicid is %d from cacheid %d\n", apicid, coreid);
 	apicid_start = apicid & (~(num_threads_sharing - 1));
 	apicid_end = apicid_start + num_threads_sharing;
-
+	dprintk("apicid_start %d  apicid_end %d\n", apicid_start, apicid_end);
 	for_each_online_cpu(i) {
 		if ((cpu_data(i).apicid >= apicid_start) &&
 			(cpu_data(i).apicid < apicid_end))
 			cpumask_set_cpu(i, mask);
-		index_msb = get_count_order(num_threads_sharing);
 		id = cpu_data(i).apicid >> index_msb;
-		dprintk("cpu_data(%d).apicid %d\tnum_threads_sharing %d\tmsb %d\tcache_id %d\n", i, cpu_data(i).apicid, num_threads_sharing, index_msb, id);
+		dprintk("cpu_data(%d).apicid %2d\tnum_threads_sharing %d\tmsb %d\tcache_id %d\n", i, cpu_data(i).apicid, num_threads_sharing, index_msb, id);
 	}
 	dprintk("Cachel level dependent! apicid  %d  num_threads_sharing %d ==> cpumask %lx\n", apicid, num_threads_sharing, *(unsigned long *)mask);
 }
 
+static int tcc_errlog_show(struct seq_file *m, void *v)
+{
+	void *errlog_buff = NULL;
+	u32 i = 0;
+	int ret = 0;
+
+	if (errsize > 0) {
+		errlog_buff = memremap(erraddr, errsize, MEMREMAP_WB);
+		if (!errlog_buff) {
+			seq_puts(m, "System error. Fail to map this errlog kernel address.\n");
+			ret = -ENOMEM;
+		} else {
+			seq_printf(m, "errlog_addr   @ %016llx\n", erraddr);
+			seq_printf(m, "errlog_size   @ %08x\n", errsize);
+			for (i = 0; i < errsize; i += sizeof(int))
+				seq_printf(m, "%08x\n", ((u32 *)errlog_buff)[i/sizeof(int)]);
+			memunmap(errlog_buff);
+		}
+	} else
+		seq_puts(m, "No TCC Error Log Buffer.\n");
+
+	return ret;
+}
+
 static int tcc_parse_ptct(void)
 {
 	u32 *tbl_swap;
@@ -686,8 +711,6 @@ static int tcc_parse_ptct(void)
 	struct psram *p_tmp_psram;
 	struct tcc_ptct_compatibility *compatibility;
 	u64 l2_start, l2_end, l3_start, l3_end;
-	void *errlog_buff = NULL;
-	u32 i = 0;
 
 	tbl_swap = (u32 *)acpi_ptct_tbl;
 
@@ -748,18 +771,6 @@ static int tcc_parse_ptct(void)
 			entry_errlog_v2 = (struct tcc_ptct_errlog_v2 *)(tbl_swap + ENTRY_HEADER_SIZE);
 			erraddr = ((u64)(entry_errlog_v2->erraddr_hi) << 32) | entry_errlog_v2->erraddr_lo;
 			errsize = entry_errlog_v2->errsize;
-			if (errsize > 0) {
-				errlog_buff = memremap(erraddr, errsize, MEMREMAP_WB);
-				if (!errlog_buff)
-					pr_err("System error. Fail to map this errlog kernel address.");
-				else {
-					pr_err("errlog_addr   @ %016llx\n", erraddr);
-					pr_err("errlog_size   @ %08x\n", errsize);
-					for (i = 0; i < errsize; i += sizeof(int))
-						pr_err("%08x\n", ((u32 *)errlog_buff)[i/sizeof(int)]);
-					memunmap(errlog_buff);
-				}
-			}
 		}
 
 		offset += entry_size / sizeof(u32);
@@ -1591,7 +1602,7 @@ static int __init tcc_buffer_init(void)
 	}
 
 	ent = proc_create("tcc_cache_test", 0660, NULL, &testops);
-
+	proc_create_single("tcc_errlog", 0, NULL, tcc_errlog_show);
 	tcc_init = 1;
 	p_tcc_config->minor = new_minor;
 
@@ -1619,6 +1630,7 @@ static void __exit tcc_buffer_exit(void)
 		kfree(p_tcc_config);
 
 		proc_remove(ent);
+		remove_proc_entry("tcc_errlog", NULL);
 	}
 	pr_err("exit().\n");
 }
-- 
2.25.1

