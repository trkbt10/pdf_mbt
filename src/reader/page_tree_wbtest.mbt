fn load_page_tree_index_from_bytes(bytes : Bytes) -> PageTreeIndex raise PdfDocumentError {
  let file = try PdfFile::open(bytes) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    file => file
  }
  let catalog = load_catalog(file)
  build_page_tree_index(file, catalog)
}

///|
test "page tree traversal returns document order and ancestry" {
  let single = load_page_tree_index_from_bytes(
    build_document_structure_single_page_fixture(),
  )
  assert_eq(single.pages.length(), 1)
  assert_eq(single.pages[0].object_id == oid(3), true)
  assert_eq(single.pages[0].index, 0)
  match single.pages[0].parent_ref {
    Some(parent_ref) => assert_eq(parent_ref == oid(2), true)
    None => fail("expected parent reference")
  }
  assert_eq(single.pages[0].ancestor_refs.length(), 1)
  assert_eq(single.pages[0].ancestor_refs[0] == oid(2), true)

  let nested = load_page_tree_index_from_bytes(
    build_document_structure_nested_page_tree_fixture(),
  )
  assert_eq(nested.pages.length(), 2)
  assert_eq(nested.pages[0].object_id == oid(4), true)
  assert_eq(nested.pages[1].object_id == oid(5), true)
  assert_eq(nested.pages[0].index, 0)
  assert_eq(nested.pages[1].index, 1)
  assert_eq(nested.pages[0].ancestor_refs.length(), 2)
  assert_eq(nested.pages[0].ancestor_refs[0] == oid(2), true)
  assert_eq(nested.pages[0].ancestor_refs[1] == oid(3), true)
  assert_eq(nested.pages[1].ancestor_refs.length(), 1)
  assert_eq(nested.pages[1].ancestor_refs[0] == oid(2), true)
}

///|
test "page tree traversal rejects malformed shapes and count mismatches" {
  let missing_kids : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_missing_kids_fixture())
  match missing_kids {
    Err(InvalidPageTree(_, reason)) => assert_eq(reason.contains("/Kids"), true)
    _ => fail("expected missing kids to be rejected")
  }

  let negative_count : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_negative_count_fixture())
  match negative_count {
    Err(InvalidPageTree(_, reason)) => assert_eq(reason.contains("non-negative"), true)
    _ => fail("expected negative count to be rejected")
  }

  let non_ref_kid : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_non_ref_kid_fixture())
  match non_ref_kid {
    Err(InvalidPageTree(_, reason)) => assert_eq(reason.contains("Kids"), true)
    _ => fail("expected non-ref kid to be rejected")
  }

  let wrong_leaf_type : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_wrong_leaf_type_fixture())
  match wrong_leaf_type {
    Err(InvalidPage(_, reason)) => assert_eq(reason.contains("/Type /Page"), true)
    _ => fail("expected wrong leaf type to be rejected")
  }

  let count_mismatch : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_count_mismatch_fixture())
  match count_mismatch {
    Err(InvalidPageTree(_, reason)) => assert_eq(reason.contains("Count"), true)
    _ => fail("expected count mismatch to be rejected")
  }

  let repeated_intermediate : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_repeated_intermediate_fixture())
  match repeated_intermediate {
    Err(InvalidPageTree(_, reason)) => assert_eq(reason.contains("repeated"), true)
    _ => fail("expected repeated intermediate node to be rejected")
  }

  let cycle : Result[PageTreeIndex, PdfDocumentError] = try?
    load_page_tree_index_from_bytes(build_page_tree_cycle_fixture())
  match cycle {
    Err(CycleDetected(_, reason)) => assert_eq(reason.contains("cycle"), true)
    _ => fail("expected cycle to be rejected")
  }
}

///|
fn build_page_tree_missing_kids_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Count 1 >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 3\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 3 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_page_tree_negative_count_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count -1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 4\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 4 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_page_tree_non_ref_kid_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 4\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 4 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_page_tree_wrong_leaf_type_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Form /Parent 2 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 4\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 4 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_page_tree_count_mismatch_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 2 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 4\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 4 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_page_tree_repeated_intermediate_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R 3 0 R] /Count 2 >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 /Parent 2 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 3 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(root_pages_offset, 0, b'n') +
  xref_entry_line(child_pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_page_tree_cycle_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [2 0 R] /Count 1 /Parent 2 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 4\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(root_pages_offset, 0, b'n') +
  xref_entry_line(child_pages_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 4 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
