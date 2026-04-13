///|
test "name tree lookup returns raw values for direct and indirect roots" {
  let direct_document = PdfDocument::open(
    build_document_structure_direct_names_fixture(),
  )
  assert_eq(
    direct_document.lookup_name(NameTreeCategory::Dests, b"direct-dest") ==
    Some(@objects.PdfObject::Ref(oid(6))),
    true,
  )
  assert_eq(
    direct_document.lookup_name(NameTreeCategory::AP, b"direct-ap") ==
    Some(@objects.PdfObject::Ref(oid(7))),
    true,
  )
  assert_eq(
    direct_document.lookup_name(NameTreeCategory::Templates, b"missing") is None,
    true,
  )

  let indirect_document = PdfDocument::open(
    build_document_structure_names_fixture(),
  )
  assert_eq(
    indirect_document.lookup_name(NameTreeCategory::Dests, b"chapter-1") ==
    Some(@objects.PdfObject::Ref(oid(12))),
    true,
  )
  assert_eq(
    indirect_document.lookup_name(NameTreeCategory::AP, b"appearance-a") ==
    Some(@objects.PdfObject::Ref(oid(20))),
    true,
  )
  assert_eq(
    indirect_document.lookup_name(NameTreeCategory::Pages, b"page-1") ==
    Some(@objects.PdfObject::Ref(oid(16))),
    true,
  )
}

///|
test "name tree lookup prunes subtrees with limits" {
  let document = PdfDocument::open(build_document_structure_names_fixture())

  assert_eq(
    document.lookup_name(NameTreeCategory::AP, b"zzzz") is None,
    true,
  )
  assert_eq(document.file.cache.get(oid(14)) is None, true)

  assert_eq(
    document.lookup_name(NameTreeCategory::AP, b"appearance-a") ==
    Some(@objects.PdfObject::Ref(oid(20))),
    true,
  )
  assert_eq(document.file.cache.get(oid(14)) is Some(_), true)
}

///|
test "name tree lookup rejects malformed names kids and limits" {
  let odd_names_document = PdfDocument::open(build_odd_names_fixture())
  let odd_names_result : Result[@objects.PdfObject?, PdfDocumentError] = try?
    odd_names_document.lookup_name(NameTreeCategory::Dests, b"chapter-1")
  match odd_names_result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Names"), true)
      assert_eq(reason.contains("pairs"), true)
    }
    _ => fail("expected odd names array to be rejected")
  }

  let non_string_document = PdfDocument::open(build_non_string_key_fixture())
  let non_string_result : Result[@objects.PdfObject?, PdfDocumentError] = try?
    non_string_document.lookup_name(NameTreeCategory::Dests, b"chapter-1")
  match non_string_result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Names"), true)
      assert_eq(reason.contains("strings"), true)
    }
    _ => fail("expected non-string names key to be rejected")
  }

  let invalid_kids_document = PdfDocument::open(build_invalid_kids_fixture())
  let invalid_kids_result : Result[@objects.PdfObject?, PdfDocumentError] = try?
    invalid_kids_document.lookup_name(NameTreeCategory::AP, b"appearance-a")
  match invalid_kids_result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Kids"), true)
      assert_eq(reason.contains("indirect references"), true)
    }
    _ => fail("expected invalid kids entry to be rejected")
  }

  let bad_limits_document = PdfDocument::open(build_bad_limits_fixture())
  let bad_limits_result : Result[@objects.PdfObject?, PdfDocumentError] = try?
    bad_limits_document.lookup_name(NameTreeCategory::AP, b"appearance-a")
  match bad_limits_result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Limits"), true)
      assert_eq(reason.contains("strings"), true)
    }
    _ => fail("expected malformed limits to be rejected")
  }
}

///|
test "name tree lookup applies node limits before validating pruned nodes" {
  let document = PdfDocument::open(build_child_limits_pruning_fixture())

  assert_eq(
    document.lookup_name(NameTreeCategory::AP, b"z-key") ==
    Some(@objects.PdfObject::Ref(oid(9))),
    true,
  )
}

///|
test "name tree lookup rejects nodes that mix names and kids" {
  let document = PdfDocument::open(build_mixed_names_and_kids_fixture())

  let result : Result[@objects.PdfObject?, PdfDocumentError] = try?
    document.lookup_name(NameTreeCategory::Dests, b"hit")
  match result {
    Err(InvalidNameTree(name, reason)) => {
      assert_eq(name == @objects.PdfName::new(b"Names"), true)
      assert_eq(reason.contains("both"), true)
    }
    _ => fail("expected mixed names and kids node to be rejected")
  }
}

///|
test "name tree lookup detects cycles" {
  let document = PdfDocument::open(build_cycle_fixture())
  let result : Result[@objects.PdfObject?, PdfDocumentError] = try?
    document.lookup_name(NameTreeCategory::AP, b"cycle-key")
  match result {
    Err(CycleDetected(object_id, reason)) => {
      assert_eq(object_id == oid(5), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected cycle to be rejected")
  }
}

///|
fn build_child_limits_pruning_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /AP 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, root_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Kids [6 0 R 8 0 R] >>",
  )
  let (bytes, pruned_child_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Limits [(a) (m)] /Names [(a-key) 10 0 R (broken)] >>",
  )
  let (bytes, unused_value_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"(unused)",
  )
  let (bytes, matching_child_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"<< /Limits [(z) (zz)] /Names [(z-key) 9 0 R] >>",
  )
  let (bytes, matching_value_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"(z-value)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 11\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(root_offset, 0, b'n') +
  xref_entry_line(pruned_child_offset, 0, b'n') +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(matching_child_offset, 0, b'n') +
  xref_entry_line(matching_value_offset, 0, b'n') +
  xref_entry_line(unused_value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 11 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_mixed_names_and_kids_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Dests 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, dests_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [(hit) 7 0 R] /Kids [6 0 R] >>",
  )
  let (bytes, child_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Names [(child) 8 0 R] >>",
  )
  let (bytes, hit_value_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"(hit-value)",
  )
  let (bytes, child_value_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"(child-value)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 9\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(dests_offset, 0, b'n') +
  xref_entry_line(child_offset, 0, b'n') +
  xref_entry_line(hit_value_offset, 0, b'n') +
  xref_entry_line(child_value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 9 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_odd_names_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Dests 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, dests_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [(chapter-1) 6 0 R (broken)] >>",
  )
  let (bytes, value_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"(destination)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(dests_offset, 0, b'n') +
  xref_entry_line(value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_non_string_key_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Dests 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, dests_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [/NotAString 6 0 R] >>",
  )
  let (bytes, value_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"(destination)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(dests_offset, 0, b'n') +
  xref_entry_line(value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_invalid_kids_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /AP 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, ap_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Kids [6] >>",
  )
  let (bytes, value_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"(appearance-a)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(ap_offset, 0, b'n') +
  xref_entry_line(value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_bad_limits_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /AP 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, ap_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Kids [6 0 R] /Limits [1 2] >>",
  )
  let (bytes, value_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Names [(appearance-a) 7 0 R] >>",
  )
  let (bytes, appearance_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"(appearance-a)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 8\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(ap_offset, 0, b'n') +
  xref_entry_line(value_offset, 0, b'n') +
  xref_entry_line(appearance_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 8 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_cycle_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /AP 5 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, root_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Kids [6 0 R] >>",
  )
  let (bytes, child_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Kids [5 0 R] >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(root_offset, 0, b'n') +
  xref_entry_line(child_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
