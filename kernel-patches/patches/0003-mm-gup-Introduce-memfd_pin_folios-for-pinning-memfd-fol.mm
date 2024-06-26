From 24115e1364d2c73e2da781952a26207632fde12b Mon Sep 17 00:00:00 2001
From: Vivek Kasireddy <vivek.kasireddy@intel.com>
Date: Thu, 4 Apr 2024 00:26:10 -0700
Subject: [PATCH 3/8] mm/gup: Introduce memfd_pin_folios() for pinning memfd
 folios

For drivers that would like to longterm-pin the folios associated
with a memfd, the memfd_pin_folios() API provides an option to
not only pin the folios via FOLL_PIN but also to check and migrate
them if they reside in movable zone or CMA block. This API
currently works with memfds but it should work with any files
that belong to either shmemfs or hugetlbfs. Files belonging to
other filesystems are rejected for now.

The folios need to be located first before pinning them via FOLL_PIN.
If they are found in the page cache, they can be immediately pinned.
Otherwise, they need to be allocated using the filesystem specific
APIs and then pinned.

(Rebased for kernel 6.8)

Signed-off-by: Dongwon Kim <dongwon.kim@intel.com>
Cc: David Hildenbrand <david@redhat.com>
Cc: Matthew Wilcox (Oracle) <willy@infradead.org>
Cc: Christoph Hellwig <hch@infradead.org>
Cc: Daniel Vetter <daniel.vetter@ffwll.ch>
Cc: Mike Kravetz <mike.kravetz@oracle.com>
Cc: Hugh Dickins <hughd@google.com>
Cc: Peter Xu <peterx@redhat.com>
Cc: Gerd Hoffmann <kraxel@redhat.com>
Cc: Dongwon Kim <dongwon.kim@intel.com>
Cc: Junxiao Chang <junxiao.chang@intel.com>
Suggested-by: Jason Gunthorpe <jgg@nvidia.com>
Reviewed-by: Jason Gunthorpe <jgg@nvidia.com> (v2)
Reviewed-by: David Hildenbrand <david@redhat.com> (v3)
Reviewed-by: Christoph Hellwig <hch@lst.de> (v6)
Signed-off-by: Vivek Kasireddy <vivek.kasireddy@intel.com>
---
 include/linux/memfd.h |   5 ++
 include/linux/mm.h    |   3 +
 mm/gup.c              | 135 ++++++++++++++++++++++++++++++++++++++++++
 mm/memfd.c            |  35 +++++++++++
 4 files changed, 178 insertions(+)

diff --git a/include/linux/memfd.h b/include/linux/memfd.h
index e7abf6fa4c52..3f2cf339ceaf 100644
--- a/include/linux/memfd.h
+++ b/include/linux/memfd.h
@@ -6,11 +6,16 @@
 
 #ifdef CONFIG_MEMFD_CREATE
 extern long memfd_fcntl(struct file *file, unsigned int cmd, unsigned int arg);
+struct folio *memfd_alloc_folio(struct file *memfd, pgoff_t idx);
 #else
 static inline long memfd_fcntl(struct file *f, unsigned int c, unsigned int a)
 {
 	return -EINVAL;
 }
+static inline struct folio *memfd_alloc_folio(struct file *memfd, pgoff_t idx)
+{
+	return ERR_PTR(-EINVAL);
+}
 #endif
 
 #endif /* __LINUX_MEMFD_H */
diff --git a/include/linux/mm.h b/include/linux/mm.h
index ac633bf2849b..20e2abe52fb6 100644
--- a/include/linux/mm.h
+++ b/include/linux/mm.h
@@ -2547,6 +2547,9 @@ long get_user_pages_unlocked(unsigned long start, unsigned long nr_pages,
 		    struct page **pages, unsigned int gup_flags);
 long pin_user_pages_unlocked(unsigned long start, unsigned long nr_pages,
 		    struct page **pages, unsigned int gup_flags);
+long memfd_pin_folios(struct file *memfd, loff_t start, loff_t end,
+		      struct folio **folios, unsigned int max_folios,
+		      pgoff_t *offset);
 
 int get_user_pages_fast(unsigned long start, int nr_pages,
 			unsigned int gup_flags, struct page **pages);
diff --git a/mm/gup.c b/mm/gup.c
index 202953cfdc42..8af28ca5404d 100644
--- a/mm/gup.c
+++ b/mm/gup.c
@@ -5,6 +5,7 @@
 #include <linux/spinlock.h>
 
 #include <linux/mm.h>
+#include <linux/memfd.h>
 #include <linux/memremap.h>
 #include <linux/pagemap.h>
 #include <linux/rmap.h>
@@ -17,6 +18,7 @@
 #include <linux/hugetlb.h>
 #include <linux/migrate.h>
 #include <linux/mm_inline.h>
+#include <linux/pagevec.h>
 #include <linux/sched/mm.h>
 #include <linux/shmem_fs.h>
 
@@ -3757,3 +3759,136 @@ long pin_user_pages_unlocked(unsigned long start, unsigned long nr_pages,
 				     &locked, gup_flags);
 }
 EXPORT_SYMBOL(pin_user_pages_unlocked);
+
+/**
+ * memfd_pin_folios() - pin folios associated with a memfd
+ * @memfd:      the memfd whose folios are to be pinned
+ * @start:      the first memfd offset
+ * @end:        the last memfd offset (inclusive)
+ * @folios:     array that receives pointers to the folios pinned
+ * @max_folios: maximum number of entries in @folios
+ * @offset:     the offset into the first folio
+ *
+ * Attempt to pin folios associated with a memfd in the contiguous range
+ * [start, end]. Given that a memfd is either backed by shmem or hugetlb,
+ * the folios can either be found in the page cache or need to be allocated
+ * if necessary. Once the folios are located, they are all pinned via
+ * FOLL_PIN and @offset is populatedwith the offset into the first folio.
+ * And, eventually, these pinned folios must be released either using
+ * unpin_folios() or unpin_folio().
+ *
+ * It must be noted that the folios may be pinned for an indefinite amount
+ * of time. And, in most cases, the duration of time they may stay pinned
+ * would be controlled by the userspace. This behavior is effectively the
+ * same as using FOLL_LONGTERM with other GUP APIs.
+ *
+ * Returns number of folios pinned, which could be less than @max_folios
+ * as it depends on the folio sizes that cover the range [start, end].
+ * If no folios were pinned, it returns -errno.
+ */
+long memfd_pin_folios(struct file *memfd, loff_t start, loff_t end,
+		      struct folio **folios, unsigned int max_folios,
+		      pgoff_t *offset)
+{
+	unsigned int flags, nr_folios, nr_found;
+	unsigned int i, pgshift = PAGE_SHIFT;
+	pgoff_t start_idx, end_idx, next_idx;
+	struct folio *folio = NULL;
+	struct folio_batch fbatch;
+	struct hstate *h;
+	long ret;
+
+	if (start > end || !max_folios)
+		return -EINVAL;
+
+	if (!memfd)
+		return -EINVAL;
+
+	if (!shmem_file(memfd) && !is_file_hugepages(memfd))
+		return -EINVAL;
+
+	if (is_file_hugepages(memfd)) {
+		h = hstate_file(memfd);
+		pgshift = huge_page_shift(h);
+	}
+
+	flags = memalloc_pin_save();
+	do {
+		nr_folios = 0;
+		start_idx = start >> pgshift;
+		end_idx = end >> pgshift;
+		if (is_file_hugepages(memfd)) {
+			start_idx <<= huge_page_order(h);
+			end_idx <<= huge_page_order(h);
+		}
+
+		folio_batch_init(&fbatch);
+		while (start_idx <= end_idx && nr_folios < max_folios) {
+			/*
+			 * In most cases, we should be able to find the folios
+			 * in the page cache. If we cannot find them for some
+			 * reason, we try to allocate them and add them to the
+			 * page cache.
+			 */
+			nr_found = filemap_get_folios_contig(memfd->f_mapping,
+							     &start_idx,
+							     end_idx,
+							     &fbatch);
+			if (folio) {
+				folio_put(folio);
+				folio = NULL;
+			}
+
+			next_idx = 0;
+			for (i = 0; i < nr_found; i++) {
+				/*
+				 * As there can be multiple entries for a
+				 * given folio in the batch returned by
+				 * filemap_get_folios_contig(), the below
+				 * check is to ensure that we pin and return a
+				 * unique set of folios between start and end.
+				 */
+				if (next_idx &&
+				    next_idx != folio_index(fbatch.folios[i]))
+					continue;
+
+				folio = try_grab_folio(&fbatch.folios[i]->page,
+						       1, FOLL_PIN);
+				if (!folio) {
+					folio_batch_release(&fbatch);
+					goto err;
+				}
+
+				if (nr_folios == 0)
+					*offset = offset_in_folio(folio, start);
+
+				folios[nr_folios] = folio;
+				next_idx = folio_next_index(folio);
+				if (++nr_folios == max_folios)
+					break;
+			}
+
+			folio = NULL;
+			folio_batch_release(&fbatch);
+			if (!nr_found) {
+				folio = memfd_alloc_folio(memfd, start_idx);
+				if (IS_ERR(folio)) {
+					ret = PTR_ERR(folio);
+					if (ret != -EEXIST)
+						goto err;
+				}
+			}
+		}
+
+		ret = check_and_migrate_movable_folios(nr_folios, folios);
+	} while (ret == -EAGAIN);
+
+	memalloc_pin_restore(flags);
+	return ret ? ret : nr_folios;
+err:
+	memalloc_pin_restore(flags);
+	unpin_folios(folios, nr_folios);
+
+	return ret;
+}
+EXPORT_SYMBOL_GPL(memfd_pin_folios);
diff --git a/mm/memfd.c b/mm/memfd.c
index 7d8d3ab3fa37..6ce2abb22c2d 100644
--- a/mm/memfd.c
+++ b/mm/memfd.c
@@ -59,6 +59,41 @@ static void memfd_tag_pins(struct xa_state *xas)
 	xas_unlock_irq(xas);
 }
 
+/*
+ * This is a helper function used by memfd_pin_user_pages() in GUP (gup.c).
+ * It is mainly called to allocate a page in a memfd when the caller
+ * (memfd_pin_folios()) cannot find a page in the page cache at a given
+ * index in the mapping.
+ */
+struct folio *memfd_alloc_folio(struct file *memfd, pgoff_t idx)
+{
+#ifdef CONFIG_HUGETLB_PAGE
+	struct folio *folio;
+	int err;
+
+	if (is_file_hugepages(memfd)) {
+		folio = alloc_hugetlb_folio_nodemask(hstate_file(memfd),
+						     NUMA_NO_NODE,
+						     NULL,
+						     GFP_USER,
+						     false);
+		if (folio && folio_try_get(folio)) {
+			err = hugetlb_add_to_page_cache(folio,
+							memfd->f_mapping,
+							idx);
+			if (err) {
+				folio_put(folio);
+				free_huge_folio(folio);
+				return ERR_PTR(err);
+			}
+			return folio;
+		}
+		return ERR_PTR(-ENOMEM);
+	}
+#endif
+	return shmem_read_folio(memfd->f_mapping, idx);
+}
+
 /*
  * Setting SEAL_WRITE requires us to verify there's no pending writer. However,
  * via get_user_pages(), drivers might have some pending I/O without any active
-- 
2.25.1

