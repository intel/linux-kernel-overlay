From b1215a55a673b1daa23c0afb8d9653782085089c Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Sat, 8 Aug 2020 18:02:04 +0800
Subject: [PATCH 7/9] tcc: return error code to better match varies error
 scenarios.

Remove unused but set variable.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 28 +++++++++++++---------------
 1 file changed, 13 insertions(+), 15 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index ce5d565b68ee..c83e71948579 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -222,7 +222,7 @@ static void tcc_get_psram_cpumask(u32 apicid, u32 num_threads_sharing, cpumask_t
 static int tcc_parse_ptct(void)
 {
 	u32 *tbl_swap;
-	u32 offset = 0, entry_format, entry_size, entry_type;
+	u32 offset = 0, entry_size, entry_type;
 	struct tcc_ptct_entry_header *entry_header;
 	struct tcc_ptct_mhlatency *entry_mhl;
 	struct tcc_ptct_psram *entry_psram;
@@ -244,7 +244,6 @@ static int tcc_parse_ptct(void)
 	do {
 		entry_header = (struct tcc_ptct_entry_header *)tbl_swap;
 
-		entry_format = entry_header->format;
 		entry_size = entry_header->size;
 		entry_type = entry_header->type;
 
@@ -267,7 +266,6 @@ static int tcc_parse_ptct(void)
 	do {
 		entry_header = (struct tcc_ptct_entry_header *)tbl_swap;
 
-		entry_format = entry_header->format;
 		entry_size = entry_header->size;
 		entry_type = entry_header->type;
 
@@ -279,7 +277,7 @@ static int tcc_parse_ptct(void)
 
 			p_new_psram = kzalloc(sizeof(struct psram), GFP_KERNEL);
 			if (!p_new_psram)
-				return -1;
+				return -ENOMEM;
 
 			p_new_psram->config.id = p_tcc_config->num_of_psram++;
 			p_new_psram->config.type = entry_psram->cache_level;
@@ -295,7 +293,7 @@ static int tcc_parse_ptct(void)
 
 				p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
 				if (!p_memslot)
-					return -1;
+					return -ENOMEM;
 
 				p_memslot->paddr = p_new_psram->paddr;
 				p_memslot->size = p_new_psram->config.size;
@@ -360,7 +358,7 @@ static int tcc_parse_ptct(void)
 
 				p_memslot = kzalloc(sizeof(struct memory_slot_info), GFP_KERNEL);
 				if (!p_memslot)
-					return -1;
+					return -ENOMEM;
 
 				p_memslot->paddr = p_tmp_psram->paddr;
 				p_memslot->size = p_tmp_psram->config.size;
@@ -488,7 +486,7 @@ static int tcc_buffer_open(struct inode *i, struct file *f)
 	}
 	if (p_memslot->open_count > 0) {
 		pr_err("OPEN(): This device is already open.\n");
-		return -1;
+		return -EBUSY;
 	}
 	p_memslot->open_count++;
 	f->private_data = p_memslot;
@@ -518,7 +516,7 @@ static int tcc_buffer_mmap(struct file *f, struct vm_area_struct *vma)
 
 	if (len & (PAGE_SIZE - 1)) {
 		pr_err("length must be page-aligned!");
-		return -1;
+		return -EINVAL;
 	}
 
 	if (!(vma->vm_flags & VM_SHARED))
@@ -544,7 +542,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	case TCC_GET_REGION_COUNT:
 		if (NULL == (int *)arg) {
 			pr_err("arg from user is nullptr!");
-			return -EFAULT;
+			return -EINVAL;
 		}
 		ret = copy_to_user((int *)arg, &p_tcc_config->num_of_psram, sizeof(p_tcc_config->num_of_psram));
 		if (ret != 0)
@@ -554,7 +552,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	case TCC_GET_MEMORY_CONFIG:
 		if (NULL == (struct tcc_buf_mem_config_s *)arg) {
 			pr_err("arg from user is nullptr!");
-			return -EFAULT;
+			return -EINVAL;
 		}
 
 		ret = copy_from_user(&memconfig, (struct tcc_buf_mem_config_s *)arg,
@@ -564,7 +562,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 
 		if (memconfig.cpu_mask_p == NULL) {
 			pr_err("cpu_mask_p from user is nullptr");
-			return -EFAULT;
+			return -EINVAL;
 		}
 
 		list_for_each_entry(p_psram, &p_tcc_config->psrams, node) {
@@ -588,7 +586,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	case TCC_QUERY_PTCT_SIZE:
 		if (NULL == (u32 *)arg) {
 			pr_err("arg from user is nullptr!");
-			return -EFAULT;
+			return -EINVAL;
 		}
 		ret = copy_to_user((u32 *)arg, &p_tcc_config->ptct_size, sizeof(p_tcc_config->ptct_size));
 		if (ret != 0)
@@ -598,7 +596,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 	case TCC_GET_PTCT:
 		if (NULL == (u32 *)arg) {
 			pr_err("arg from user is nullptr!");
-			return -EFAULT;
+			return -EINVAL;
 		}
 		ret = copy_to_user((u32 *)arg, acpi_ptct_tbl, p_tcc_config->ptct_size);
 		if (ret != 0)
@@ -610,7 +608,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 
 		if (NULL == (struct tcc_buf_mem_req_s *)arg) {
 			pr_err("arg from user is nullptr!");
-			return -EFAULT;
+			return -EINVAL;
 		}
 		ret = copy_from_user(&req_mem, (struct tcc_buf_mem_req_s *)arg, sizeof(req_mem));
 		if (ret != 0)
@@ -619,7 +617,7 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 		req_mem.devnode = tcc_allocate_memslot(req_mem.id, req_mem.size);
 
 		if (req_mem.devnode == UNDEFINED_DEVNODE)
-			return -EFAULT;
+			return -ENOMEM;
 
 		ret = copy_to_user((struct tcc_buf_mem_req_s *)arg, &req_mem, sizeof(req_mem));
 		if (ret != 0)
-- 
2.27.0

