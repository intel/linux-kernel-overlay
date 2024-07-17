From 00833bd9e4c20f0d52fbc74ec8fc98517f274f0d Mon Sep 17 00:00:00 2001
From: Vivek Kasireddy <vivek.kasireddy@intel.com>
Date: Thu, 4 Apr 2024 00:26:13 -0700
Subject: [PATCH 6/8] udmabuf: Convert udmabuf driver to use folios

This is mainly a preparatory patch to use memfd_pin_folios() API
for pinning folios. Using folios instead of pages makes sense as
the udmabuf driver needs to handle both shmem and hugetlb cases.
However, the function vmap_udmabuf() still needs a list of pages;
so, we collect all the head pages into a local array in this case.

Other changes in this patch include the addition of helpers for
checking the memfd seals and exporting dmabuf. Moving code from
udmabuf_create() into these helpers improves readability given
that udmabuf_create() is a bit long.

Cc: David Hildenbrand <david@redhat.com>
Cc: Matthew Wilcox <willy@infradead.org>
Cc: Daniel Vetter <daniel.vetter@ffwll.ch>
Cc: Mike Kravetz <mike.kravetz@oracle.com>
Cc: Hugh Dickins <hughd@google.com>
Cc: Peter Xu <peterx@redhat.com>
Cc: Jason Gunthorpe <jgg@nvidia.com>
Cc: Gerd Hoffmann <kraxel@redhat.com>
Cc: Dongwon Kim <dongwon.kim@intel.com>
Cc: Junxiao Chang <junxiao.chang@intel.com>
Signed-off-by: Vivek Kasireddy <vivek.kasireddy@intel.com>
---
 drivers/dma-buf/udmabuf.c | 140 ++++++++++++++++++++++----------------
 1 file changed, 83 insertions(+), 57 deletions(-)

diff --git a/drivers/dma-buf/udmabuf.c b/drivers/dma-buf/udmabuf.c
index 274defd3fa3e..a8f3af61f7f2 100644
--- a/drivers/dma-buf/udmabuf.c
+++ b/drivers/dma-buf/udmabuf.c
@@ -26,7 +26,7 @@ MODULE_PARM_DESC(size_limit_mb, "Max size of a dmabuf, in megabytes. Default is
 
 struct udmabuf {
 	pgoff_t pagecount;
-	struct page **pages;
+	struct folio **folios;
 	struct sg_table *sg;
 	struct miscdevice *device;
 	pgoff_t *offsets;
@@ -42,7 +42,7 @@ static vm_fault_t udmabuf_vm_fault(struct vm_fault *vmf)
 	if (pgoff >= ubuf->pagecount)
 		return VM_FAULT_SIGBUS;
 
-	pfn = page_to_pfn(ubuf->pages[pgoff]);
+	pfn = folio_pfn(ubuf->folios[pgoff]);
 	pfn += ubuf->offsets[pgoff] >> PAGE_SHIFT;
 
 	return vmf_insert_pfn(vma, vmf->address, pfn);
@@ -68,11 +68,21 @@ static int mmap_udmabuf(struct dma_buf *buf, struct vm_area_struct *vma)
 static int vmap_udmabuf(struct dma_buf *buf, struct iosys_map *map)
 {
 	struct udmabuf *ubuf = buf->priv;
+	struct page **pages;
 	void *vaddr;
+	pgoff_t pg;
 
 	dma_resv_assert_held(buf->resv);
 
-	vaddr = vm_map_ram(ubuf->pages, ubuf->pagecount, -1);
+	pages = kmalloc_array(ubuf->pagecount, sizeof(*pages), GFP_KERNEL);
+	if (!pages)
+		return -ENOMEM;
+
+	for (pg = 0; pg < ubuf->pagecount; pg++)
+		pages[pg] = &ubuf->folios[pg]->page;
+
+	vaddr = vm_map_ram(pages, ubuf->pagecount, -1);
+	kfree(pages);
 	if (!vaddr)
 		return -EINVAL;
 
@@ -107,7 +117,8 @@ static struct sg_table *get_sg_table(struct device *dev, struct dma_buf *buf,
 		goto err_alloc;
 
 	for_each_sg(sg->sgl, sgl, ubuf->pagecount, i)
-		sg_set_page(sgl, ubuf->pages[i], PAGE_SIZE, ubuf->offsets[i]);
+		sg_set_folio(sgl, ubuf->folios[i], PAGE_SIZE,
+			     ubuf->offsets[i]);
 
 	ret = dma_map_sgtable(dev, sg, direction, 0);
 	if (ret < 0)
@@ -152,9 +163,9 @@ static void release_udmabuf(struct dma_buf *buf)
 		put_sg_table(dev, ubuf->sg, DMA_BIDIRECTIONAL);
 
 	for (pg = 0; pg < ubuf->pagecount; pg++)
-		put_page(ubuf->pages[pg]);
+		folio_put(ubuf->folios[pg]);
 	kfree(ubuf->offsets);
-	kfree(ubuf->pages);
+	kfree(ubuf->folios);
 	kfree(ubuf);
 }
 
@@ -215,36 +226,33 @@ static int handle_hugetlb_pages(struct udmabuf *ubuf, struct file *memfd,
 	pgoff_t mapidx = offset >> huge_page_shift(hpstate);
 	pgoff_t subpgoff = (offset & ~huge_page_mask(hpstate)) >> PAGE_SHIFT;
 	pgoff_t maxsubpgs = huge_page_size(hpstate) >> PAGE_SHIFT;
-	struct page *hpage = NULL;
-	struct folio *folio;
+	struct folio *folio = NULL;
 	pgoff_t pgidx;
 
 	mapidx <<= huge_page_order(hpstate);
 	for (pgidx = 0; pgidx < pgcnt; pgidx++) {
-		if (!hpage) {
+		if (!folio) {
 			folio = __filemap_get_folio(memfd->f_mapping,
 						    mapidx,
 						    FGP_ACCESSED, 0);
 			if (IS_ERR(folio))
 				return PTR_ERR(folio);
-
-			hpage = &folio->page;
 		}
 
-		get_page(hpage);
-		ubuf->pages[*pgbuf] = hpage;
+		folio_get(folio);
+		ubuf->folios[*pgbuf] = folio;
 		ubuf->offsets[*pgbuf] = subpgoff << PAGE_SHIFT;
 		(*pgbuf)++;
 		if (++subpgoff == maxsubpgs) {
-			put_page(hpage);
-			hpage = NULL;
+			folio_put(folio);
+			folio = NULL;
 			subpgoff = 0;
 			mapidx += pages_per_huge_page(hpstate);
 		}
 	}
 
-	if (hpage)
-		put_page(hpage);
+	if (folio)
+		folio_put(folio);
 
 	return 0;
 }
@@ -254,31 +262,69 @@ static int handle_shmem_pages(struct udmabuf *ubuf, struct file *memfd,
 			      pgoff_t *pgbuf)
 {
 	pgoff_t pgidx, pgoff = offset >> PAGE_SHIFT;
-	struct page *page;
+	struct folio *folio = NULL;
 
 	for (pgidx = 0; pgidx < pgcnt; pgidx++) {
-		page = shmem_read_mapping_page(memfd->f_mapping,
-					       pgoff + pgidx);
-		if (IS_ERR(page))
-			return PTR_ERR(page);
+		folio = shmem_read_folio(memfd->f_mapping, pgoff + pgidx);
+		if (IS_ERR(folio))
+			return PTR_ERR(folio);
 
-		ubuf->pages[*pgbuf] = page;
+		ubuf->folios[*pgbuf] = folio;
 		(*pgbuf)++;
 	}
 
 	return 0;
 }
 
+static int check_memfd_seals(struct file *memfd)
+{
+	int seals;
+
+	if (!memfd)
+		return -EBADFD;
+
+	if (!shmem_file(memfd) && !is_file_hugepages(memfd))
+		return -EBADFD;
+
+	seals = memfd_fcntl(memfd, F_GET_SEALS, 0);
+	if (seals == -EINVAL)
+		return -EBADFD;
+
+	if ((seals & SEALS_WANTED) != SEALS_WANTED ||
+	    (seals & SEALS_DENIED) != 0)
+		return -EINVAL;
+
+	return 0;
+}
+
+static int export_udmabuf(struct udmabuf *ubuf,
+			  struct miscdevice *device,
+			  u32 flags)
+{
+	DEFINE_DMA_BUF_EXPORT_INFO(exp_info);
+	struct dma_buf *buf;
+
+	ubuf->device = device;
+	exp_info.ops  = &udmabuf_ops;
+	exp_info.size = ubuf->pagecount << PAGE_SHIFT;
+	exp_info.priv = ubuf;
+	exp_info.flags = O_RDWR;
+
+	buf = dma_buf_export(&exp_info);
+	if (IS_ERR(buf))
+		return PTR_ERR(buf);
+
+	return dma_buf_fd(buf, flags);
+}
+
 static long udmabuf_create(struct miscdevice *device,
 			   struct udmabuf_create_list *head,
 			   struct udmabuf_create_item *list)
 {
-	DEFINE_DMA_BUF_EXPORT_INFO(exp_info);
+	pgoff_t pgcnt, pgbuf = 0, pglimit;
 	struct file *memfd = NULL;
 	struct udmabuf *ubuf;
-	struct dma_buf *buf;
-	pgoff_t pgcnt, pgbuf = 0, pglimit;
-	int seals, ret = -EINVAL;
+	int ret = -EINVAL;
 	u32 i, flags;
 
 	ubuf = kzalloc(sizeof(*ubuf), GFP_KERNEL);
@@ -299,9 +345,9 @@ static long udmabuf_create(struct miscdevice *device,
 	if (!ubuf->pagecount)
 		goto err;
 
-	ubuf->pages = kmalloc_array(ubuf->pagecount, sizeof(*ubuf->pages),
+	ubuf->folios = kmalloc_array(ubuf->pagecount, sizeof(*ubuf->folios),
 				    GFP_KERNEL);
-	if (!ubuf->pages) {
+	if (!ubuf->folios) {
 		ret = -ENOMEM;
 		goto err;
 	}
@@ -314,18 +360,9 @@ static long udmabuf_create(struct miscdevice *device,
 
 	pgbuf = 0;
 	for (i = 0; i < head->count; i++) {
-		ret = -EBADFD;
 		memfd = fget(list[i].memfd);
-		if (!memfd)
-			goto err;
-		if (!shmem_file(memfd) && !is_file_hugepages(memfd))
-			goto err;
-		seals = memfd_fcntl(memfd, F_GET_SEALS, 0);
-		if (seals == -EINVAL)
-			goto err;
-		ret = -EINVAL;
-		if ((seals & SEALS_WANTED) != SEALS_WANTED ||
-		    (seals & SEALS_DENIED) != 0)
+		ret = check_memfd_seals(memfd);
+		if (ret < 0)
 			goto err;
 
 		pgcnt = list[i].size >> PAGE_SHIFT;
@@ -341,33 +378,22 @@ static long udmabuf_create(struct miscdevice *device,
 			goto err;
 
 		fput(memfd);
-		memfd = NULL;
 	}
 
-	exp_info.ops  = &udmabuf_ops;
-	exp_info.size = ubuf->pagecount << PAGE_SHIFT;
-	exp_info.priv = ubuf;
-	exp_info.flags = O_RDWR;
-
-	ubuf->device = device;
-	buf = dma_buf_export(&exp_info);
-	if (IS_ERR(buf)) {
-		ret = PTR_ERR(buf);
+	flags = head->flags & UDMABUF_FLAGS_CLOEXEC ? O_CLOEXEC : 0;
+	ret = export_udmabuf(ubuf, device, flags);
+	if (ret < 0)
 		goto err;
-	}
 
-	flags = 0;
-	if (head->flags & UDMABUF_FLAGS_CLOEXEC)
-		flags |= O_CLOEXEC;
-	return dma_buf_fd(buf, flags);
+	return ret;
 
 err:
 	while (pgbuf > 0)
-		put_page(ubuf->pages[--pgbuf]);
+		folio_put(ubuf->folios[--pgbuf]);
 	if (memfd)
 		fput(memfd);
 	kfree(ubuf->offsets);
-	kfree(ubuf->pages);
+	kfree(ubuf->folios);
 	kfree(ubuf);
 	return ret;
 }
-- 
2.25.1

