///|
test "page content stream returns empty instructions when Contents is absent" {
  let document = PdfDocument::open(
    build_document_structure_nested_page_tree_fixture(),
  )
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length(), 0)
}

///|
test "page content resources resolve inherited resource dictionary" {
  let document = PdfDocument::open(build_page_content_single_stream_fixture())
  let page = document.page(0)
  let resources = page.content_resources()
  assert_eq(
    resources.lookup_resource(
      @content.ResourceCategory::Font,
      @objects.PdfName::new(b"F1"),
    ) ==
    Some(@objects.PdfObject::Ref(oid(5))),
    true,
  )
}

///|
test "page content stream parses a single stream through page workflow" {
  let document = PdfDocument::open(build_page_content_single_stream_fixture())
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length(), 2)
  match content.instructions[0] {
    @content.ContentInstruction::Operation(operation) =>
      assert_eq(
        operation.operator == @content.StandardContentOperator::BeginText,
        true,
      )
    _ => fail("expected BeginText instruction")
  }
}

///|
test "page content stream resolves indirect Length before reading stream bytes" {
  let document = PdfDocument::open(
    build_page_content_indirect_length_stream_fixture(),
  )
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length(), 2)
  match content.instructions[0] {
    @content.ContentInstruction::Operation(operation) =>
      assert_eq(
        operation.operator == @content.StandardContentOperator::BeginText,
        true,
      )
    _ => fail("expected BeginText instruction")
  }
}

///|
test "page content stream concatenates array streams with LF separation" {
  let document = PdfDocument::open(build_page_content_array_stream_fixture())
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length(), 2)
  match content.instructions[1] {
    @content.ContentInstruction::Operation(operation) => {
      assert_eq(
        operation.operator ==
        @content.StandardContentOperator::RestoreGraphicsState,
        true,
      )
      assert_eq(operation.offset, 2L)
    }
    _ => fail("expected second operation from concatenated stream")
  }
}

///|
test "page content stream decodes filters before parsing" {
  let document = PdfDocument::open(build_page_content_filtered_stream_fixture())
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length(), 2)
  match content.instructions[0] {
    @content.ContentInstruction::Operation(operation) =>
      assert_eq(
        operation.operator ==
        @content.StandardContentOperator::SaveGraphicsState,
        true,
      )
    _ => fail("expected decoded q operator")
  }
}

///|
fn build_page_content_single_stream_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources << /Font << /F1 5 0 R >> >> >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(b"<< /Length 5 >>", b"BT ET")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset,
  ])
}

///|
fn build_page_content_indirect_length_stream_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(
    b"<< /Length 5 0 R >>", b"BT ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, length_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"5",
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, length_offset,
  ])
}

///|
fn build_page_content_array_stream_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents [4 0 R 5 0 R] >>",
  )
  let first_stream = build_stream_object_body(b"<< /Length 1 >>", b"q")
  let (bytes, first_offset) = append_indirect_object(
    bytes, header_base, 4, 0, first_stream,
  )
  let second_stream = build_stream_object_body(b"<< /Length 1 >>", b"Q")
  let (bytes, second_offset) = append_indirect_object(
    bytes, header_base, 5, 0, second_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, first_offset, second_offset,
  ])
}

///|
fn build_page_content_filtered_stream_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(
    b"<< /Length 9 /Filter /ASCIIHexDecode >>", b"71 20 51>",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}

///|
fn finish_page_content_fixture(
  bytes : Bytes,
  header_base : Int64,
  offsets : Array[Int64],
) -> Bytes {
  let xref_offset = object_offset(bytes, header_base)
  let mut out = bytes +
    b"xref\r\n" +
    b"0 " +
    decimal_bytes((offsets.length() + 1).to_int64()) +
    b"\r\n" +
    xref_entry_line(0L, 65535, b'f')
  for offset in offsets {
    out = out + xref_entry_line(offset, 0, b'n')
  }
  out +
  b"trailer\r\n" +
  b"<< /Size " +
  decimal_bytes((offsets.length() + 1).to_int64()) +
  b" /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
