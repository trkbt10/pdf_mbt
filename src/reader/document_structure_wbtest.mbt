///|
test "PdfDocument::open validates catalog but leaves page tree unresolved" {
  let document = PdfDocument::open(build_document_structure_single_page_fixture())
  let catalog = document.catalog()

  assert_eq(catalog.object_id == oid(1), true)
  assert_eq(catalog.pages_ref == oid(2), true)
  assert_eq(
    catalog.entry(@objects.PdfName::new(b"Type")) ==
    Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
    true,
  )

  let page_tree_fixture = PdfDocument::open(
    build_document_structure_single_page_fixture(),
  )
  assert_eq(page_tree_fixture.catalog().pages_ref == oid(2), true)
}

///|
test "PdfFile::document exposes the same validated catalog" {
  let file = PdfFile::open(build_document_structure_single_page_fixture())
  let document = file.document()
  let catalog = document.catalog()

  assert_eq(catalog.object_id == oid(1), true)
  assert_eq(catalog.pages_ref == oid(2), true)
  assert_eq(
    catalog.entry(@objects.PdfName::new(b"Pages")) ==
    Some(@objects.PdfObject::Ref(oid(2))),
    true,
  )
}

///|
test "document creation does not require page tree traversal" {
  let document = PdfDocument::open(build_document_structure_lazy_pages_fixture())
  assert_eq(document.catalog().pages_ref == oid(2), true)
}

///|
test "document facade wraps file errors and catalog errors" {
  let invalid_header : Result[PdfDocument, PdfDocumentError] = try? PdfDocument::open(
    b"not a pdf",
  )
  match invalid_header {
    Err(ReaderError(_)) => ()
    _ => fail("expected reader error wrapper")
  }

  let file = make_reader_file(
    b"1 0 obj\n<< /Pages 2 0 R >>\nendobj",
    Map::new(),
  )
  file.xref_index[oid(1)] = ObjectLocation::Uncompressed(0L, 0)
  let missing_type : Result[PdfDocument, PdfDocumentError] = try? file.document()
  match missing_type {
    Err(InvalidCatalog(object_id, reason)) => {
      assert_eq(object_id == oid(1), true)
      assert_eq(reason.contains("/Type"), true)
    }
    _ => fail("expected invalid catalog error")
  }
}

///|
test "document pages expose zero-based identity and count" {
  let document = PdfDocument::open(build_document_structure_single_page_fixture())

  assert_eq(document.page_count(), 1)

  let page = document.page(0)
  assert_eq(page.index(), 0)
  assert_eq(page.object_id() == oid(3), true)
  match page.parent_ref() {
    Some(parent_ref) => assert_eq(parent_ref == oid(2), true)
    None => fail("expected parent reference")
  }
}

///|
test "document pages preserve order and reuse cached traversal" {
  let document = PdfDocument::open(build_document_structure_nested_page_tree_fixture())

  let first = document.pages()
  assert_eq(first.length(), 2)
  assert_eq(first[0].index(), 0)
  assert_eq(first[0].object_id() == oid(4), true)
  assert_eq(first[1].index(), 1)
  assert_eq(first[1].object_id() == oid(5), true)

  document.file.cache.clear()
  document.file.xref_index[oid(4)] = ObjectLocation::Uncompressed(0L, 0)
  document.file.xref_index[oid(5)] = ObjectLocation::Uncompressed(0L, 0)

  let second = document.pages()
  assert_eq(second.length(), 2)
  assert_eq(second[0].object_id() == oid(4), true)
  assert_eq(second[1].object_id() == oid(5), true)
  assert_eq(document.page_count(), 2)
}

///|
test "document page bounds errors include requested index and count" {
  let document = PdfDocument::open(build_document_structure_single_page_fixture())

  let negative : Result[PdfPage, PdfDocumentError] = try? document.page(-1)
  match negative {
    Err(PageIndexOutOfRange(requested, count)) => {
      assert_eq(requested, -1)
      assert_eq(count, 1)
    }
    _ => fail("expected negative index failure")
  }

  let out_of_range : Result[PdfPage, PdfDocumentError] = try? document.page(1)
  match out_of_range {
    Err(PageIndexOutOfRange(requested, count)) => {
      assert_eq(requested, 1)
      assert_eq(count, 1)
    }
    _ => fail("expected out of range failure")
  }
}

///|
fn build_document_structure_lazy_pages_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
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
