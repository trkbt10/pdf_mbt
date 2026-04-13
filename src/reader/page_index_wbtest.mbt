///|
test "page index cache is empty before traversal and reused after build" {
  let document = PdfDocument::open(
    build_document_structure_nested_page_tree_fixture(),
  )

  match document.page_index {
    None => ()
    Some(_) => fail("expected empty page index cache before traversal")
  }

  let first = ensure_page_index(document)
  assert_eq(first.pages.length(), 2)
  assert_eq(first.pages[0].object_id == oid(4), true)
  assert_eq(first.pages[1].object_id == oid(5), true)
  assert_eq(document.page_index == Some(first), true)

  document.file.cache.clear()
  document.file.xref_index[oid(4)] = ObjectLocation::Uncompressed(0L, 0)
  document.file.xref_index[oid(5)] = ObjectLocation::Uncompressed(0L, 0)

  let second = ensure_page_index(document)
  assert_eq(second == first, true)
  assert_eq(document.page_index == Some(first), true)
}

///|
test "page index cache remains empty after traversal errors" {
  let document = PdfDocument::open(build_page_tree_count_mismatch_fixture())

  let result : Result[PageTreeIndex, PdfDocumentError] = try? ensure_page_index(
    document,
  )
  match result {
    Err(InvalidPageTree(_, reason)) => assert_eq(reason.contains("Count"), true)
    _ => fail("expected page tree count mismatch")
  }

  match document.page_index {
    None => ()
    Some(_) => fail("expected no page index cache after traversal failure")
  }
}
