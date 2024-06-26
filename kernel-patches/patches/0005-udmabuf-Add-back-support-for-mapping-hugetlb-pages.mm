From 446464b080080d6b9b6c1c9468bb1ebaee173124 Mon Sep 17 00:00:00 2001
From: Vivek Kasireddy <vivek.kasireddy@intel.com>
Date: Thu, 4 Apr 2024 00:26:12 -0700
Subject: [PATCH 5/8] udmabuf: Add back support for mapping hugetlb pages

A user or admin can configure a VMM (Qemu) Guest's memory to be
backed by hugetlb pages for various reasons. However, a Guest OS
would still allocate (and pin) buffers that are backed by regular
4k sized pages. In order to map these buffers and create dma-bufs
for them on the Host, we first need to find the hugetlb pages where
the buffer allocations are located and then determine the offsets
of individual chunks (within those pages) and use this information
to eventually populate a scatterlist.

Testcase: default_hugepagesz=2M hugepagesz=2M hugepages=2500 options
were passed to the Host kernel and Qemu was launched with these
relevant options: qemu-system-x86_64 -m 4096m....
-device virtio-gpu-pci,max_outputs=1,blob=true,xres=1920,yres=1080
-display gtk,gl=on
-object memory-backend-memfd,hugetlb=on,id=mem1,size=4096M
-machine memory-backend=mem1

Replacing -display gtk,gl=on with -display gtk,gl=off above would
exercise the mmap handler.

Cc: David Hildenbrand <david@redhat.com>
Cc: Daniel Vetter <daniel.vetter@ffwll.ch>
Cc: Mike Kravetz <mike.kravetz@oracle.com>
Cc: Hugh Dickins <hughd@google.com>
Cc: Peter Xu <peterx@redhat.com>
Cc: Jason Gunthorpe <jgg@nvidia.com>
Cc: Gerd Hoffmann <kraxel@redhat.com>
Cc: Dongwon Kim <dongwon.kim@intel.com>
Cc: Junxiao Chang <junxiao.chang@intel.com>
Acked-by: Mike Kravetz <mike.kravetz@oracle.com> (v2)
Signed-off-by: Vivek Kasireddy <vivek.kasireddy@intel.com>
---
 drivers/dma-buf/udmabuf.c | 122 +++++++++++++++++++++++++++++++-------
 1 file changed, 101 insertions(+), 21 deletions(-)

diff --git a/drivers/dma-buf/udmabuf.c b/drivers/dma-buf/udmabuf.c
index 820c993c8659..274defd3fa3e 100644
--- a/drivers/dma-buf/udmabuf.c
+++ b/drivers/dma-buf/udmabuf.c
@@ -10,6 +10,7 @@
 #include <linux/miscdevice.h>
 #include <linux/module.h>
 #include <linux/shmem_fs.h>
+#include <linux/hugetlb.h>
 #include <linux/slab.h>
 #include <linux/udmabuf.h>
 #include <linux/vmalloc.h>
@@ -28,6 +29,7 @@ struct udmabuf {
 	struct page **pages;
 	struct sg_table *sg;
 	struct miscdevice *device;
+	pgoff_t *offsets;
 };
 
 static vm_fault_t udmabuf_vm_fault(struct vm_fault *vmf)
@@ -41,6 +43,8 @@ static vm_fault_t udmabuf_vm_fault(struct vm_fault *vmf)
 		return VM_FAULT_SIGBUS;
 
 	pfn = page_to_pfn(ubuf->pages[pgoff]);
+	pfn += ubuf->offsets[pgoff] >> PAGE_SHIFT;
+
 	return vmf_insert_pfn(vma, vmf->address, pfn);
 }
 
@@ -90,23 +94,29 @@ static struct sg_table *get_sg_table(struct device *dev, struct dma_buf *buf,
 {
 	struct udmabuf *ubuf = buf->priv;
 	struct sg_table *sg;
+	struct scatterlist *sgl;
+	unsigned int i = 0;
 	int ret;
 
 	sg = kzalloc(sizeof(*sg), GFP_KERNEL);
 	if (!sg)
 		return ERR_PTR(-ENOMEM);
-	ret = sg_alloc_table_from_pages(sg, ubuf->pages, ubuf->pagecount,
-					0, ubuf->pagecount << PAGE_SHIFT,
-					GFP_KERNEL);
+
+	ret = sg_alloc_table(sg, ubuf->pagecount, GFP_KERNEL);
 	if (ret < 0)
-		goto err;
+		goto err_alloc;
+
+	for_each_sg(sg->sgl, sgl, ubuf->pagecount, i)
+		sg_set_page(sgl, ubuf->pages[i], PAGE_SIZE, ubuf->offsets[i]);
+
 	ret = dma_map_sgtable(dev, sg, direction, 0);
 	if (ret < 0)
-		goto err;
+		goto err_map;
 	return sg;
 
-err:
+err_map:
 	sg_free_table(sg);
+err_alloc:
 	kfree(sg);
 	return ERR_PTR(ret);
 }
@@ -143,6 +153,7 @@ static void release_udmabuf(struct dma_buf *buf)
 
 	for (pg = 0; pg < ubuf->pagecount; pg++)
 		put_page(ubuf->pages[pg]);
+	kfree(ubuf->offsets);
 	kfree(ubuf->pages);
 	kfree(ubuf);
 }
@@ -196,17 +207,77 @@ static const struct dma_buf_ops udmabuf_ops = {
 #define SEALS_WANTED (F_SEAL_SHRINK)
 #define SEALS_DENIED (F_SEAL_WRITE)
 
+static int handle_hugetlb_pages(struct udmabuf *ubuf, struct file *memfd,
+				pgoff_t offset, pgoff_t pgcnt,
+				pgoff_t *pgbuf)
+{
+	struct hstate *hpstate = hstate_file(memfd);
+	pgoff_t mapidx = offset >> huge_page_shift(hpstate);
+	pgoff_t subpgoff = (offset & ~huge_page_mask(hpstate)) >> PAGE_SHIFT;
+	pgoff_t maxsubpgs = huge_page_size(hpstate) >> PAGE_SHIFT;
+	struct page *hpage = NULL;
+	struct folio *folio;
+	pgoff_t pgidx;
+
+	mapidx <<= huge_page_order(hpstate);
+	for (pgidx = 0; pgidx < pgcnt; pgidx++) {
+		if (!hpage) {
+			folio = __filemap_get_folio(memfd->f_mapping,
+						    mapidx,
+						    FGP_ACCESSED, 0);
+			if (IS_ERR(folio))
+				return PTR_ERR(folio);
+
+			hpage = &folio->page;
+		}
+
+		get_page(hpage);
+		ubuf->pages[*pgbuf] = hpage;
+		ubuf->offsets[*pgbuf] = subpgoff << PAGE_SHIFT;
+		(*pgbuf)++;
+		if (++subpgoff == maxsubpgs) {
+			put_page(hpage);
+			hpage = NULL;
+			subpgoff = 0;
+			mapidx += pages_per_huge_page(hpstate);
+		}
+	}
+
+	if (hpage)
+		put_page(hpage);
+
+	return 0;
+}
+
+static int handle_shmem_pages(struct udmabuf *ubuf, struct file *memfd,
+			      pgoff_t offset, pgoff_t pgcnt,
+			      pgoff_t *pgbuf)
+{
+	pgoff_t pgidx, pgoff = offset >> PAGE_SHIFT;
+	struct page *page;
+
+	for (pgidx = 0; pgidx < pgcnt; pgidx++) {
+		page = shmem_read_mapping_page(memfd->f_mapping,
+					       pgoff + pgidx);
+		if (IS_ERR(page))
+			return PTR_ERR(page);
+
+		ubuf->pages[*pgbuf] = page;
+		(*pgbuf)++;
+	}
+
+	return 0;
+}
+
 static long udmabuf_create(struct miscdevice *device,
 			   struct udmabuf_create_list *head,
 			   struct udmabuf_create_item *list)
 {
 	DEFINE_DMA_BUF_EXPORT_INFO(exp_info);
 	struct file *memfd = NULL;
-	struct address_space *mapping = NULL;
 	struct udmabuf *ubuf;
 	struct dma_buf *buf;
-	pgoff_t pgoff, pgcnt, pgidx, pgbuf = 0, pglimit;
-	struct page *page;
+	pgoff_t pgcnt, pgbuf = 0, pglimit;
 	int seals, ret = -EINVAL;
 	u32 i, flags;
 
@@ -234,6 +305,12 @@ static long udmabuf_create(struct miscdevice *device,
 		ret = -ENOMEM;
 		goto err;
 	}
+	ubuf->offsets = kcalloc(ubuf->pagecount, sizeof(*ubuf->offsets),
+				GFP_KERNEL);
+	if (!ubuf->offsets) {
+		ret = -ENOMEM;
+		goto err;
+	}
 
 	pgbuf = 0;
 	for (i = 0; i < head->count; i++) {
@@ -241,8 +318,7 @@ static long udmabuf_create(struct miscdevice *device,
 		memfd = fget(list[i].memfd);
 		if (!memfd)
 			goto err;
-		mapping = memfd->f_mapping;
-		if (!shmem_mapping(mapping))
+		if (!shmem_file(memfd) && !is_file_hugepages(memfd))
 			goto err;
 		seals = memfd_fcntl(memfd, F_GET_SEALS, 0);
 		if (seals == -EINVAL)
@@ -251,16 +327,19 @@ static long udmabuf_create(struct miscdevice *device,
 		if ((seals & SEALS_WANTED) != SEALS_WANTED ||
 		    (seals & SEALS_DENIED) != 0)
 			goto err;
-		pgoff = list[i].offset >> PAGE_SHIFT;
-		pgcnt = list[i].size   >> PAGE_SHIFT;
-		for (pgidx = 0; pgidx < pgcnt; pgidx++) {
-			page = shmem_read_mapping_page(mapping, pgoff + pgidx);
-			if (IS_ERR(page)) {
-				ret = PTR_ERR(page);
-				goto err;
-			}
-			ubuf->pages[pgbuf++] = page;
-		}
+
+		pgcnt = list[i].size >> PAGE_SHIFT;
+		if (is_file_hugepages(memfd))
+			ret = handle_hugetlb_pages(ubuf, memfd,
+						   list[i].offset,
+						   pgcnt, &pgbuf);
+		else
+			ret = handle_shmem_pages(ubuf, memfd,
+						 list[i].offset,
+						 pgcnt, &pgbuf);
+		if (ret < 0)
+			goto err;
+
 		fput(memfd);
 		memfd = NULL;
 	}
@@ -287,6 +366,7 @@ static long udmabuf_create(struct miscdevice *device,
 		put_page(ubuf->pages[--pgbuf]);
 	if (memfd)
 		fput(memfd);
+	kfree(ubuf->offsets);
 	kfree(ubuf->pages);
 	kfree(ubuf);
 	return ret;
-- 
2.25.1

