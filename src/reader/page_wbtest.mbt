///|
test "typed page accessors normalize direct page attributes" {
  let document = PdfDocument::open(build_typed_page_attributes_fixture())
  let page = document.page(0)

  match page.media_box() {
    Some(rect) => assert_rectangle(rect, 0.0, 0.0, 612.0, 792.0)
    None => fail("expected media box")
  }

  match page.crop_box() {
    Some(rect) => assert_rectangle(rect, 10.0, 20.0, 30.0, 40.0)
    None => fail("expected crop box")
  }

  match page.rotate() {
    Some(value) => assert_eq(value, 90)
    None => fail("expected rotate")
  }

  match page.user_unit() {
    Some(value) => assert_eq(value, 2.5)
    None => fail("expected user unit")
  }
}

///|
test "typed page accessors inherit nearest ancestor values" {
  let document = PdfDocument::open(build_typed_page_inheritance_fixture())
  let page = document.page(0)

  match page.media_box() {
    Some(rect) => assert_rectangle(rect, 0.0, 0.0, 400.0, 400.0)
    None => fail("expected inherited media box")
  }

  match page.crop_box() {
    Some(rect) => assert_rectangle(rect, 5.0, 6.0, 7.0, 8.0)
    None => fail("expected inherited crop box")
  }

  match page.rotate() {
    Some(value) => assert_eq(value, 270)
    None => fail("expected inherited rotate")
  }
}

///|
test "typed page boxes prefer direct page values over ancestors" {
  let document = PdfDocument::open(build_typed_page_box_precedence_fixture())
  let page = document.page(0)

  match page.media_box() {
    Some(rect) => assert_rectangle(rect, 1.0, 2.0, 3.0, 4.0)
    None => fail("expected direct media box")
  }

  match page.crop_box() {
    Some(rect) => assert_rectangle(rect, 5.0, 6.0, 7.0, 8.0)
    None => fail("expected direct crop box")
  }
}

///|
test "typed page boxes return absence when no page or ancestor defines them" {
  let document = PdfDocument::open(build_typed_page_missing_boxes_fixture())
  let page = document.page(0)

  assert_eq(page.media_box() is None, true)
  assert_eq(page.crop_box() is None, true)
}

///|
test "typed page accessors reject malformed direct and inherited values" {
  let direct_document = PdfDocument::open(
    build_malformed_direct_typed_fixture(),
  )
  let direct_page = direct_document.page(0)

  let media_box_result : Result[PdfRectangle?, PdfDocumentError] = try? direct_page.media_box()
  match media_box_result {
    Err(InvalidPage(object_id, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(reason.contains("MediaBox"), true)
      assert_eq(reason.contains("four numbers"), true)
    }
    _ => fail("expected malformed direct media box to be rejected")
  }

  let crop_box_result : Result[PdfRectangle?, PdfDocumentError] = try? direct_page.crop_box()
  match crop_box_result {
    Err(InvalidPage(object_id, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(reason.contains("CropBox"), true)
      assert_eq(reason.contains("four numbers"), true)
    }
    _ => fail("expected malformed direct crop box to be rejected")
  }

  let user_unit_result : Result[Double?, PdfDocumentError] = try? direct_page.user_unit()
  match user_unit_result {
    Err(InvalidPage(object_id, reason)) => {
      assert_eq(object_id == oid(3), true)
      assert_eq(reason.contains("UserUnit"), true)
      assert_eq(reason.contains("number"), true)
    }
    _ => fail("expected malformed direct user unit to be rejected")
  }

  let inherited_document = PdfDocument::open(
    build_malformed_inherited_rotate_fixture(),
  )
  let inherited_page = inherited_document.page(0)

  let rotate_result : Result[Int?, PdfDocumentError] = try? inherited_page.rotate()
  match rotate_result {
    Err(InvalidInheritedAttribute(object_id, key, reason)) => {
      assert_eq(object_id == oid(2), true)
      assert_eq(key == @objects.PdfName::new(b"Rotate"), true)
      assert_eq(reason.contains("inherited"), true)
      assert_eq(reason.contains("integer"), true)
    }
    _ => fail("expected malformed inherited rotate to be rejected")
  }
}

///|
fn build_typed_page_box_precedence_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 612 792] /CropBox [10 20 300 400] >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 /Parent 2 0 R /MediaBox [0 0 400 400] /CropBox [20 30 200 300] >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 3 0 R /MediaBox [1 2 3 4] /CropBox [5 6 7 8] >>",
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
fn build_typed_page_missing_boxes_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
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
fn build_typed_page_attributes_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /CropBox [10 20 30 40] /Rotate 90 /UserUnit 2.5 >>",
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
fn build_typed_page_inheritance_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 612 792] /CropBox [1 2 3 4] /Rotate 180 >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 /Parent 2 0 R /MediaBox [0 0 400 400] /CropBox [5 6 7 8] /Rotate 270 >>",
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
fn build_malformed_direct_typed_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612] /CropBox [0 0 10] /UserUnit /Bad >>",
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
fn build_malformed_inherited_rotate_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Rotate 45.5 >>",
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
fn assert_rectangle(
  rect : PdfRectangle,
  left : Double,
  bottom : Double,
  right : Double,
  top : Double,
) -> Unit raise {
  assert_eq(rect.left, left)
  assert_eq(rect.bottom, bottom)
  assert_eq(rect.right, right)
  assert_eq(rect.top, top)
}
