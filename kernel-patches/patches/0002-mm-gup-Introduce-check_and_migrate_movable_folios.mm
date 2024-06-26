From d081969a68f93d3ccfa290754dba2d4613d8f85d Mon Sep 17 00:00:00 2001
From: Vivek Kasireddy <vivek.kasireddy@intel.com>
Date: Thu, 4 Apr 2024 00:26:09 -0700
Subject: [PATCH 2/8] mm/gup: Introduce check_and_migrate_movable_folios()

This helper is the folio equivalent of check_and_migrate_movable_pages().
Therefore, all the rules that apply to check_and_migrate_movable_pages()
also apply to this one as well. Currently, this helper is only used by
memfd_pin_folios().

This patch also includes changes to rename and convert the internal
functions collect_longterm_unpinnable_pages() and
migrate_longterm_unpinnable_pages() to work on folios. As a result,
check_and_migrate_movable_pages() is now a wrapper around
check_and_migrate_movable_folios().

Cc: David Hildenbrand <david@redhat.com>
Cc: Matthew Wilcox <willy@infradead.org>
Cc: Christoph Hellwig <hch@infradead.org>
Cc: Jason Gunthorpe <jgg@nvidia.com>
Cc: Peter Xu <peterx@redhat.com>
Suggested-by: David Hildenbrand <david@redhat.com>
Signed-off-by: Vivek Kasireddy <vivek.kasireddy@intel.com>
Acked-by: David Hildenbrand <david@redhat.com>
---
 mm/gup.c | 122 ++++++++++++++++++++++++++++++++++++-------------------
 1 file changed, 81 insertions(+), 41 deletions(-)

diff --git a/mm/gup.c b/mm/gup.c
index b18ca6828f92..202953cfdc42 100644
--- a/mm/gup.c
+++ b/mm/gup.c
@@ -2427,19 +2427,19 @@ struct page *get_dump_page(unsigned long addr)
 
 #ifdef CONFIG_MIGRATION
 /*
- * Returns the number of collected pages. Return value is always >= 0.
+ * Returns the number of collected folios. Return value is always >= 0.
  */
-static unsigned long collect_longterm_unpinnable_pages(
-					struct list_head *movable_page_list,
-					unsigned long nr_pages,
-					struct page **pages)
+static unsigned long collect_longterm_unpinnable_folios(
+					struct list_head *movable_folio_list,
+					unsigned long nr_folios,
+					struct folio **folios)
 {
 	unsigned long i, collected = 0;
 	struct folio *prev_folio = NULL;
 	bool drain_allow = true;
 
-	for (i = 0; i < nr_pages; i++) {
-		struct folio *folio = page_folio(pages[i]);
+	for (i = 0; i < nr_folios; i++) {
+		struct folio *folio = folios[i];
 
 		if (folio == prev_folio)
 			continue;
@@ -2454,7 +2454,7 @@ static unsigned long collect_longterm_unpinnable_pages(
 			continue;
 
 		if (folio_test_hugetlb(folio)) {
-			isolate_hugetlb(folio, movable_page_list);
+			isolate_hugetlb(folio, movable_folio_list);
 			continue;
 		}
 
@@ -2466,7 +2466,7 @@ static unsigned long collect_longterm_unpinnable_pages(
 		if (!folio_isolate_lru(folio))
 			continue;
 
-		list_add_tail(&folio->lru, movable_page_list);
+		list_add_tail(&folio->lru, movable_folio_list);
 		node_stat_mod_folio(folio,
 				    NR_ISOLATED_ANON + folio_is_file_lru(folio),
 				    folio_nr_pages(folio));
@@ -2476,27 +2476,28 @@ static unsigned long collect_longterm_unpinnable_pages(
 }
 
 /*
- * Unpins all pages and migrates device coherent pages and movable_page_list.
- * Returns -EAGAIN if all pages were successfully migrated or -errno for failure
- * (or partial success).
+ * Unpins all folios and migrates device coherent folios and movable_folio_list.
+ * Returns -EAGAIN if all folios were successfully migrated or -errno for
+ * failure (or partial success).
  */
-static int migrate_longterm_unpinnable_pages(
-					struct list_head *movable_page_list,
-					unsigned long nr_pages,
-					struct page **pages)
+static int migrate_longterm_unpinnable_folios(
+					struct list_head *movable_folio_list,
+					unsigned long nr_folios,
+					struct folio **folios)
 {
 	int ret;
 	unsigned long i;
 
-	for (i = 0; i < nr_pages; i++) {
-		struct folio *folio = page_folio(pages[i]);
+	for (i = 0; i < nr_folios; i++) {
+		struct folio *folio = folios[i];
 
 		if (folio_is_device_coherent(folio)) {
 			/*
-			 * Migration will fail if the page is pinned, so convert
-			 * the pin on the source page to a normal reference.
+			 * Migration will fail if the folio is pinned, so
+			 * convert the pin on the source folio to a normal
+			 * reference.
 			 */
-			pages[i] = NULL;
+			folios[i] = NULL;
 			folio_get(folio);
 			gup_put_folio(folio, 1, FOLL_PIN);
 
@@ -2509,24 +2510,24 @@ static int migrate_longterm_unpinnable_pages(
 		}
 
 		/*
-		 * We can't migrate pages with unexpected references, so drop
+		 * We can't migrate folios with unexpected references, so drop
 		 * the reference obtained by __get_user_pages_locked().
-		 * Migrating pages have been added to movable_page_list after
+		 * Migrating folios have been added to movable_folio_list after
 		 * calling folio_isolate_lru() which takes a reference so the
-		 * page won't be freed if it's migrating.
+		 * folio won't be freed if it's migrating.
 		 */
-		unpin_user_page(pages[i]);
-		pages[i] = NULL;
+		unpin_folio(folios[i]);
+		folios[i] = NULL;
 	}
 
-	if (!list_empty(movable_page_list)) {
+	if (!list_empty(movable_folio_list)) {
 		struct migration_target_control mtc = {
 			.nid = NUMA_NO_NODE,
 			.gfp_mask = GFP_USER | __GFP_NOWARN,
 			.reason = MR_LONGTERM_PIN,
 		};
 
-		if (migrate_pages(movable_page_list, alloc_migration_target,
+		if (migrate_pages(movable_folio_list, alloc_migration_target,
 				  NULL, (unsigned long)&mtc, MIGRATE_SYNC,
 				  MR_LONGTERM_PIN, NULL)) {
 			ret = -ENOMEM;
@@ -2534,19 +2535,48 @@ static int migrate_longterm_unpinnable_pages(
 		}
 	}
 
-	putback_movable_pages(movable_page_list);
+	putback_movable_pages(movable_folio_list);
 
 	return -EAGAIN;
 
 err:
-	for (i = 0; i < nr_pages; i++)
-		if (pages[i])
-			unpin_user_page(pages[i]);
-	putback_movable_pages(movable_page_list);
+	unpin_folios(folios, nr_folios);
+	putback_movable_pages(movable_folio_list);
 
 	return ret;
 }
 
+/*
+ * Check whether all folios are *allowed* to be pinned indefinitely (longterm).
+ * Rather confusingly, all folios in the range are required to be pinned via
+ * FOLL_PIN, before calling this routine.
+ *
+ * If any folios in the range are not allowed to be pinned, then this routine
+ * will migrate those folios away, unpin all the folios in the range and return
+ * -EAGAIN. The caller should re-pin the entire range with FOLL_PIN and then
+ * call this routine again.
+ *
+ * If an error other than -EAGAIN occurs, this indicates a migration failure.
+ * The caller should give up, and propagate the error back up the call stack.
+ *
+ * If everything is OK and all folios in the range are allowed to be pinned,
+ * then this routine leaves all folios pinned and returns zero for success.
+ */
+static long check_and_migrate_movable_folios(unsigned long nr_folios,
+					     struct folio **folios)
+{
+	unsigned long collected;
+	LIST_HEAD(movable_folio_list);
+
+	collected = collect_longterm_unpinnable_folios(&movable_folio_list,
+						       nr_folios, folios);
+	if (!collected)
+		return 0;
+
+	return migrate_longterm_unpinnable_folios(&movable_folio_list,
+						  nr_folios, folios);
+}
+
 /*
  * Check whether all pages are *allowed* to be pinned. Rather confusingly, all
  * pages in the range are required to be pinned via FOLL_PIN, before calling
@@ -2566,16 +2596,20 @@ static int migrate_longterm_unpinnable_pages(
 static long check_and_migrate_movable_pages(unsigned long nr_pages,
 					    struct page **pages)
 {
-	unsigned long collected;
-	LIST_HEAD(movable_page_list);
+	struct folio **folios;
+	long i, ret;
 
-	collected = collect_longterm_unpinnable_pages(&movable_page_list,
-						nr_pages, pages);
-	if (!collected)
-		return 0;
+	folios = kmalloc_array(nr_pages, sizeof(*folios), GFP_KERNEL);
+	if (!folios)
+		return -ENOMEM;
 
-	return migrate_longterm_unpinnable_pages(&movable_page_list, nr_pages,
-						pages);
+	for (i = 0; i < nr_pages; i++)
+		folios[i] = page_folio(pages[i]);
+
+	ret = check_and_migrate_movable_folios(nr_pages, folios);
+
+	kfree(folios);
+	return ret;
 }
 #else
 static long check_and_migrate_movable_pages(unsigned long nr_pages,
@@ -2583,6 +2617,12 @@ static long check_and_migrate_movable_pages(unsigned long nr_pages,
 {
 	return 0;
 }
+
+static long check_and_migrate_movable_folios(unsigned long nr_folios,
+					     struct folio **folios)
+{
+	return 0;
+}
 #endif /* CONFIG_MIGRATION */
 
 /*
-- 
2.25.1

