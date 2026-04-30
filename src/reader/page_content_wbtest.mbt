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
test "page content stream wraps malformed content as document content error" {
  let document = PdfDocument::open(build_page_content_bad_content_fixture())
  let page = document.page(0)
  let result : Result[@content.ContentStream, PdfDocumentError] = try? page.content_stream()
  match result {
    Err(ContentError(@content.PdfContentError::MalformedSyntax(offset, reason))) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("EX"), true)
    }
    _ => fail("expected malformed page content to be wrapped")
  }
}

///|
test "page content stream wraps filter failures as document content error" {
  let document = PdfDocument::open(build_page_content_bad_filter_fixture())
  let page = document.page(0)
  let result : Result[@content.ContentStream, PdfDocumentError] = try? page.content_stream()
  match result {
    Err(
      ContentError(
        @content.PdfContentError::FilterError(offset, UnsupportedFilter(name))
      )
    ) => {
      assert_eq(offset, 0L)
      assert_eq(name, "Crypt")
    }
    _ => fail("expected page content filter failure to be wrapped")
  }
}

///|
test "bundled PDF 2.0 page content emits recognized instructions" {
  let document = PdfDocument::open(simple_pdf20_file)
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length() > 0, true)
  let mut saw_text = false
  for instruction in content.instructions {
    match instruction {
      @content.ContentInstruction::Operation(operation) =>
        if operation.operator == @content.StandardContentOperator::BeginText ||
          operation.operator == @content.StandardContentOperator::ShowText {
          saw_text = true
        }
      _ => ()
    }
  }
  assert_eq(saw_text, true)
}

///|
test "synthetic page content emits one inline image instruction" {
  let document = PdfDocument::open(build_page_content_inline_image_fixture())
  let page = document.page(0)
  let content = page.content_stream()
  assert_eq(content.instructions.length(), 1)
  match content.instructions[0] {
    @content.ContentInstruction::InlineImage(image) => {
      assert_eq(image.data, b"Z")
      assert_eq(
        image.dictionary.get(@objects.PdfName::new(b"Width")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    }
    _ => fail("expected inline image instruction")
  }
}

///|
test "synthetic form xobject selects form-local resources" {
  let document = PdfDocument::open(build_page_content_form_xobject_fixture())
  let page = document.page(0)
  let parent = page.content_resources()
  match document.file.load_object(oid(5)) {
    @objects.PdfObject::Stream(form_stream) => {
      let scoped = parent.for_form_xobject(form_stream, 0L)
      assert_eq(
        scoped.lookup_resource(
          @content.ResourceCategory::Font,
          @objects.PdfName::new(b"F1"),
        ) ==
        Some(@objects.PdfObject::Integer(99L)),
        true,
      )
    }
    _ => fail("expected form xobject stream")
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
fn build_page_content_bad_content_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(b"<< /Length 2 >>", b"EX")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}

///|
fn build_page_content_bad_filter_fixture() -> Bytes {
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
    b"<< /Length 1 /Filter /Crypt >>", b"q",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}

///|
fn build_page_content_inline_image_fixture() -> Bytes {
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
  let image_content = b"BI /W 1 /H 1 /BPC 8 ID Z EI"
  let content_stream = build_stream_object_body(
    b"<< /Length " + decimal_bytes(image_content.length().to_int64()) + b" >>",
    image_content,
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}

///|
fn build_page_content_form_xobject_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 6 0 R >> /XObject << /Fm1 5 0 R >> >> /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(b"<< /Length 7 >>", b"/Fm1 Do")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let form_stream = build_stream_object_body(
    b"<< /Type /XObject /Subtype /Form /BBox [0 0 10 10] /Resources << /Font << /F1 99 >> >> /Length 1 >>",
    b"q",
  )
  let (bytes, form_offset) = append_indirect_object(
    bytes, header_base, 5, 0, form_stream,
  )
  let (bytes, parent_font_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, form_offset, parent_font_offset,
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
