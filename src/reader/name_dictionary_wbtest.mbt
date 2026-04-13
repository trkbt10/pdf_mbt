///|
test "name dictionary access returns absence without catalog names" {
  let document = PdfDocument::open(
    build_document_structure_single_page_fixture(),
  )
  assert_eq(document.names_dict() is None, true)
  assert_eq(document.name_tree_root(NameTreeCategory::Dests) is None, true)
}

///|
test "name dictionary access resolves direct and indirect catalog names" {
  let direct_document = PdfDocument::open(
    build_document_structure_direct_names_fixture(),
  )
  match direct_document.names_dict() {
    Some(dict) => assert_eq(dict.length(), 2)
    None => fail("expected direct names dictionary")
  }
  assert_eq(
    direct_document.name_tree_root(NameTreeCategory::Dests) ==
    Some(@objects.PdfObject::Ref(oid(4))),
    true,
  )
  assert_eq(
    direct_document.name_tree_root(NameTreeCategory::Pages) is None,
    true,
  )

  let indirect_document = PdfDocument::open(
    build_document_structure_names_fixture(),
  )
  match indirect_document.names_dict() {
    Some(dict) => assert_eq(dict.length(), 7)
    None => fail("expected indirect names dictionary")
  }
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::Dests) ==
    Some(@objects.PdfObject::Ref(oid(5))),
    true,
  )
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::AP) ==
    Some(@objects.PdfObject::Ref(oid(6))),
    true,
  )
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::JavaScript) ==
    Some(@objects.PdfObject::Ref(oid(7))),
    true,
  )
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::Pages) ==
    Some(@objects.PdfObject::Ref(oid(8))),
    true,
  )
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::Templates) ==
    Some(@objects.PdfObject::Ref(oid(9))),
    true,
  )
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::EmbeddedFiles) ==
    Some(@objects.PdfObject::Ref(oid(10))),
    true,
  )
  assert_eq(
    indirect_document.name_tree_root(NameTreeCategory::AlternatePresentations) ==
    Some(@objects.PdfObject::Ref(oid(11))),
    true,
  )
}

///|
test "name dictionary access rejects malformed catalog names" {
  let bad_direct_document = PdfDocument::open(
    build_document_structure_bad_names_fixture(),
  )
  let bad_direct_result : Result[@objects.PdfDictionary?, PdfDocumentError] = try? bad_direct_document.names_dict()
  match bad_direct_result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Names"), true)
      assert_eq(reason.contains("dictionary"), true)
    }
    _ => fail("expected malformed direct names dictionary to be rejected")
  }

  let bad_indirect_document = PdfDocument::open(
    build_document_structure_bad_indirect_names_fixture(),
  )
  let bad_indirect_result : Result[@objects.PdfDictionary?, PdfDocumentError] = try? bad_indirect_document.names_dict()
  match bad_indirect_result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Names"), true)
      assert_eq(reason.contains("dictionary"), true)
    }
    _ => fail("expected malformed indirect names dictionary to be rejected")
  }
}

///|
fn build_document_structure_direct_names_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names << /Dests 4 0 R /AP 5 0 R >> >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, dests_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Names [(direct-dest) 6 0 R] >>",
  )
  let (bytes, ap_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [(direct-ap) 7 0 R] >>",
  )
  let (bytes, dest_value_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"(direct-dest-value)",
  )
  let (bytes, ap_value_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"(direct-ap-value)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 8\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(dests_offset, 0, b'n') +
  xref_entry_line(ap_offset, 0, b'n') +
  xref_entry_line(dest_value_offset, 0, b'n') +
  xref_entry_line(ap_value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 8 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_document_structure_bad_names_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names /Bad >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
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
fn build_document_structure_bad_indirect_names_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, bad_names_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"(not-a-dictionary)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(bad_names_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
