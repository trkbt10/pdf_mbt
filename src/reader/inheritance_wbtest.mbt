///|
test "direct inherited values win over ancestors" {
  let document = PdfDocument::open(
    build_document_structure_inheritance_precedence_fixture(),
  )
  let page = document.page(0)

  match page.inherited_entry(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      assert_eq(assert_resources_font_ref(dict, oid(6)), true)
    _ => fail("expected nearest ancestor resources")
  }

  match page.resources() {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      assert_eq(assert_resources_font_ref(dict, oid(6)), true)
    _ => fail("expected nearest ancestor resources")
  }

  match page.inherited_entry(@objects.PdfName::new(b"Rotate")) {
    Some(@objects.PdfObject::Integer(value)) => assert_eq(value, 90L)
    _ => fail("expected direct rotate value")
  }

  match page.entry(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      assert_eq(assert_resources_font_ref(dict, oid(6)), true)
    _ => fail("expected direct resources")
  }
}

///|
test "nearest ancestor wins when the page omits inherited values" {
  let document = PdfDocument::open(
    build_document_structure_inheritance_nearest_ancestor_fixture(),
  )
  let page = document.page(0)

  assert_eq(page.entry(@objects.PdfName::new(b"Resources")) is None, true)

  match page.inherited_entry(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      assert_eq(assert_resources_font_ref(dict, oid(5)), true)
    _ => fail("expected nearest ancestor resources")
  }

  match page.resources() {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      assert_eq(assert_resources_font_ref(dict, oid(5)), true)
    _ => fail("expected nearest ancestor resources")
  }

  match page.inherited_entry(@objects.PdfName::new(b"Rotate")) {
    Some(@objects.PdfObject::Integer(value)) => assert_eq(value, 270L)
    _ => fail("expected nearest ancestor rotate")
  }
}

///|
test "inherited entries return absence without raising when undefined" {
  let document = PdfDocument::open(
    build_document_structure_inherited_resources_fixture(),
  )
  let page = document.page(0)

  assert_eq(page.entry(@objects.PdfName::new(b"Resources")) is None, true)
  match page.inherited_entry(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      assert_eq(assert_resources_font_ref(dict, oid(4)), true)
    _ => fail("expected inherited resources")
  }
  assert_eq(
    page.inherited_entry(@objects.PdfName::new(b"CropBox")) is None,
    true,
  )
}

///|
test "unsupported inherited keys are rejected even when direct values exist" {
  let document = PdfDocument::open(
    build_page_access_resolution_fixture(),
  )
  let page = document.page(0)

  let direct_contents : Result[@objects.PdfObject?, PdfDocumentError] = try?
    page.inherited_entry(@objects.PdfName::new(b"Contents"))
  match direct_contents {
    Err(InvalidInheritedAttribute(object_id, key, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(key == @objects.PdfName::new(b"Contents"), true)
      assert_eq(reason.contains("unsupported"), true)
    }
    _ => fail("expected unsupported direct key to be rejected")
  }

  let direct_annots : Result[@objects.PdfObject?, PdfDocumentError] = try?
    page.inherited_entry(@objects.PdfName::new(b"Annots"))
  match direct_annots {
    Err(InvalidInheritedAttribute(object_id, key, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(key == @objects.PdfName::new(b"Annots"), true)
      assert_eq(reason.contains("unsupported"), true)
    }
    _ => fail("expected unsupported direct key to be rejected")
  }

  let absent_unsupported : Result[@objects.PdfObject?, PdfDocumentError] = try?
    page.inherited_entry(@objects.PdfName::new(b"Foo"))
  match absent_unsupported {
    Err(InvalidInheritedAttribute(object_id, key, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(key == @objects.PdfName::new(b"Foo"), true)
      assert_eq(reason.contains("unsupported"), true)
    }
    _ => fail("expected unsupported absent key to be rejected")
  }
}

///|
test "malformed parent chains and cycles are rejected during inheritance" {
  let malformed_document = PdfDocument::open(
    build_document_structure_inheritance_malformed_parent_fixture(),
  )
  let malformed_page = malformed_document.page(0)
  let malformed_result : Result[@objects.PdfObject?, PdfDocumentError] = try? malformed_page.resources()
  match malformed_result {
    Err(InvalidInheritedAttribute(object_id, key, reason)) => {
      assert_eq(object_id == oid(4), true)
      assert_eq(key == @objects.PdfName::new(b"Resources"), true)
      assert_eq(reason.contains("/Type"), true)
    }
    _ => fail("expected malformed parent to be rejected")
  }

  let cycle_document = PdfDocument::open(
    build_document_structure_inheritance_cycle_fixture(),
  )
  let cycle_page = cycle_document.page(0)
  let cycle_result : Result[@objects.PdfObject?, PdfDocumentError] = try? cycle_page.resources()
  match cycle_result {
    Err(CycleDetected(object_id, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected cycle to be rejected")
  }
}

///|
fn build_document_structure_inheritance_precedence_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources <</Font 4 0 R>> /Rotate 180 >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [5 0 R] /Count 1 /Parent 2 0 R /Resources <</Font 5 0 R>> /Rotate 270 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Page /Parent 3 0 R /Resources <</Font 6 0 R>> /Rotate 90 >>",
  )
  let (bytes, root_font_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  )
  let (bytes, child_font_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(root_pages_offset, 0, b'n') +
  xref_entry_line(child_pages_offset, 0, b'n') +
  xref_entry_line(root_font_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(child_font_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_document_structure_inheritance_nearest_ancestor_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes,
    header_base,
    2,
    0,
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources <</Font 4 0 R /ProcSet [/PDF]>> /Rotate 180 /MediaBox [0 0 612 792] >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes,
    header_base,
    3,
    0,
    b"<< /Type /Pages /Kids [5 0 R] /Count 1 /Parent 2 0 R /Resources <</Font 5 0 R>> /Rotate 270 /MediaBox [0 0 400 400] >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Page /Parent 3 0 R >>",
  )
  let (bytes, root_font_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 6\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(root_pages_offset, 0, b'n') +
  xref_entry_line(child_pages_offset, 0, b'n') +
  xref_entry_line(root_font_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 6 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
test "inherited media box comes from the nearest ancestor" {
  let document = PdfDocument::open(
    build_document_structure_inheritance_nearest_ancestor_fixture(),
  )
  let page = document.page(0)

  match page.inherited_entry(@objects.PdfName::new(b"MediaBox")) {
    Some(@objects.PdfObject::Array(values)) => {
      assert_eq(values.length(), 4)
      assert_eq(values[0] == @objects.PdfObject::Integer(0L), true)
      assert_eq(values[1] == @objects.PdfObject::Integer(0L), true)
      assert_eq(values[2] == @objects.PdfObject::Integer(400L), true)
      assert_eq(values[3] == @objects.PdfObject::Integer(400L), true)
    }
    _ => fail("expected inherited media box")
  }
}

///|
test "inherited resources are not merged with ancestor values" {
  let document = PdfDocument::open(
    build_document_structure_inheritance_nearest_ancestor_fixture(),
  )
  let page = document.page(0)

  match page.inherited_entry(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(dict)) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Font")) ==
        Some(@objects.PdfObject::Ref(oid(5))),
        true,
      )
      assert_eq(dict.get(@objects.PdfName::new(b"ProcSet")) is None, true)
    }
    _ => fail("expected inherited resources")
  }
}

///|
fn build_document_structure_inheritance_malformed_parent_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Parent 4 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R >>",
  )
  let (bytes, malformed_parent_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(malformed_parent_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_document_structure_inheritance_cycle_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Parent 3 0 R >>",
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
fn assert_resources_font_ref(
  dict : @objects.PdfDictionary,
  expected : @objects.ObjectId,
) -> Bool {
  match dict.get(@objects.PdfName::new(b"Font")) {
    Some(@objects.PdfObject::Ref(font_ref)) => font_ref == expected
    _ => false
  }
}
