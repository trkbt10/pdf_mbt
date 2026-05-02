///|
test "page extracted text materializes font and ToUnicode resources" {
  let document = PdfDocument::open(build_page_text_fixture())
  let page = document.page(0)
  let extracted = page.extracted_text(TextPageOptions::default())
  assert_eq(extracted.spans.length(), 1)
  assert_eq(extracted.spans[0].text, "Hi")
}

///|
test "page extract text layout preserves line order and word gaps" {
  let document = PdfDocument::open(build_page_text_layout_fixture())
  let page = document.page(0)
  assert_eq(page.extract_text_layout(), "A B\nC")
}

///|
test "page text program wraps text failures as document errors" {
  let document = PdfDocument::open(build_page_text_missing_font_fixture())
  let page = document.page(0)
  let result : Result[@text.TextProgram, PdfDocumentError] = try? page.text_program(
    TextPageOptions::default(),
  )
  match result {
    Err(TextError(MissingResource(_, reason))) =>
      assert_eq(reason.contains("current font"), true)
    _ => fail("expected text error")
  }
}

///|
test "page extracted text falls back when font encoding is unknown" {
  let document = PdfDocument::open(build_page_text_unknown_encoding_fixture())
  let page = document.page(0)
  let result : Result[@text.ExtractedText, PdfDocumentError] = try? page.extracted_text(
    TextPageOptions::default(),
  )
  match result {
    Ok(extracted) => assert_eq(collect_reader_extracted_text(extracted), "AB")
    Err(error) => fail(pdf_document_error_summary(error))
  }
}

///|
test "page text program ignores broken embedded font program" {
  let document = PdfDocument::open(
    build_page_text_broken_font_program_fixture(),
  )
  let page = document.page(0)
  let instructions_result : Result[Array[@content.ContentInstruction], PdfDocumentError] = try? page.content_instructions()
  match instructions_result {
    Ok(instructions) => assert_eq(instructions.length() > 0, true)
    Err(error) =>
      fail("content_instructions: " + pdf_document_error_summary(error))
  }
  let resources_result : Result[@text.TextResources, PdfDocumentError] = try? page.text_resources()
  match resources_result {
    Ok(resources) =>
      assert_eq(resources.fonts.contains(@objects.PdfName::new(b"F1")), true)
    Err(error) =>
      fail("text_resources: " + pdf_document_error_summary(error))
  }
  let program_result : Result[@text.TextProgram, PdfDocumentError] = try? page.text_program(
    TextPageOptions::default(),
  )
  match program_result {
    Ok(program) =>
      assert_eq(collect_reader_spans_text(program.spans), "AB")
    Err(error) =>
      fail("text_program: " + pdf_document_error_summary(error))
  }
}

///|
test "page text program keeps ToUnicode for TrueType fallback" {
  let document = PdfDocument::open(build_page_text_truetype_fallback_fixture())
  let page = document.page(0)
  let instructions = page.content_instructions()
  assert_eq(instructions.length() > 0, true)
  let resources = page.text_resources()
  assert_eq(resources.fonts.contains(@objects.PdfName::new(b"F1")), true)
  let program = page.text_program(TextPageOptions::default())
  assert_eq(collect_reader_spans_text(program.spans), "Z")
  match program.events[2] {
    @text.TextEvent::GlyphShown(event) =>
      assert_eq(event.glyph.metrics.horizontal_displacement, 600.0)
    _ => fail("expected glyph event")
  }
}

///|
test "page extracted text raises when content parsing fails" {
  // Per the strict-or-recover SoT: a malformed content stream is a
  // structural error, not a "text was empty" outcome. The previous
  // behaviour silently substituted an empty extraction and stranded the
  // user without any signal that the document itself was corrupt — this
  // is exactly the swallow that historically hid ToUnicode FlateDecode
  // failures and silently dropped CID fonts back to Latin substitution
  // glyphs. Callers that want best-effort recovery must catch the typed
  // error explicitly.
  let document = PdfDocument::open(build_page_text_bad_content_fixture())
  let page = document.page(0)
  let result : Result[@text.ExtractedText, PdfDocumentError] = try? page.extracted_text(
    TextPageOptions::default(),
  )
  match result {
    Err(ContentError(_)) => ()
    Ok(_) => fail("expected bad content stream to raise ContentError")
    Err(error) =>
      fail(
        "expected ContentError, got " + pdf_document_error_summary(error),
      )
  }
}

///|
fn build_page_text_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(
    b"<< /Length 23 >>", b"BT /F1 10 Tf (AB) Tj ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /FirstChar 65 /Widths [600 500] /ToUnicode 6 0 R >>",
  )
  let to_unicode = build_stream_object_body(
    b"<< /Length 97 >>", b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n2 beginbfchar\n<41> <0048>\n<42> <0069>\nendbfchar",
  )
  let (bytes, unicode_offset) = append_indirect_object(
    bytes, header_base, 6, 0, to_unicode,
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset, unicode_offset,
  ])
}

///|
fn build_page_text_layout_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(
    b"<< /Length 89 >>", b"BT /F1 10 Tf 1 0 0 1 10 100 Tm (A) Tj 1 0 0 1 22 100 Tm (B) Tj 1 0 0 1 10 80 Tm (C) Tj ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /FirstChar 65 /Widths [600 600 600] /ToUnicode 6 0 R >>",
  )
  let to_unicode = build_stream_object_body(
    b"<< /Length 109 >>", b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n3 beginbfchar\n<41> <0041>\n<42> <0042>\n<43> <0043>\nendbfchar",
  )
  let (bytes, unicode_offset) = append_indirect_object(
    bytes, header_base, 6, 0, to_unicode,
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset, unicode_offset,
  ])
}

///|
fn build_page_text_unknown_encoding_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(
    b"<< /Length 23 >>", b"BT /F1 10 Tf (AB) Tj ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /OpenOfficeSubset /Encoding /OpenOfficeCustomEncoding /FirstChar 65 /Widths [600 500] >>",
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset,
  ])
}

///|
fn build_page_text_broken_font_program_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(
    b"<< /Length 23 >>", b"BT /F1 10 Tf (AB) Tj ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /FirstChar 65 /Widths [600 500] /ToUnicode 6 0 R /FontDescriptor << /MissingWidth 500 /FontFile 99 0 R >> >>",
  )
  let to_unicode = build_stream_object_body(
    b"<< /Length 97 >>", b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n2 beginbfchar\n<41> <0041>\n<42> <0042>\nendbfchar",
  )
  let (bytes, unicode_offset) = append_indirect_object(
    bytes, header_base, 6, 0, to_unicode,
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset, unicode_offset,
  ])
}

///|
fn build_page_text_truetype_fallback_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(
    b"<< /Length 22 >>", b"BT /F1 10 Tf (A) Tj ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /TrueType /BaseFont /TestCmap12 /Encoding << /BaseEncoding /NonStandardEncoding >> /ToUnicode 6 0 R /FontDescriptor 7 0 R >>",
  )
  let to_unicode_bytes = b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n1 beginbfchar\n<41> <005A>\nendbfchar"
  let to_unicode = build_stream_object_body(
    b"<< /Length " +
    decimal_bytes(to_unicode_bytes.length().to_int64()) +
    b" >>",
    to_unicode_bytes,
  )
  let (bytes, unicode_offset) = append_indirect_object(
    bytes, header_base, 6, 0, to_unicode,
  )
  let (bytes, descriptor_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /Type /FontDescriptor /FontName /TestCmap12 /Flags 4 /FontBBox [0 0 600 700] /ItalicAngle 0 /Ascent 700 /Descent 0 /CapHeight 700 /StemV 80 /FontFile2 8 0 R >>",
  )
  let ttf = reader_synthetic_truetype_font()
  let font_file = build_stream_object_body(
    b"<< /Length " + decimal_bytes(ttf.length().to_int64()) + b" >>",
    ttf,
  )
  let (bytes, font_file_offset) = append_indirect_object(
    bytes, header_base, 8, 0, font_file,
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset, unicode_offset,
    descriptor_offset, font_file_offset,
  ])
}

///|
fn build_page_text_bad_content_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(b"<< /Length 2 >>", b"EX")
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
fn build_page_text_missing_font_fixture() -> Bytes {
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
    b"<< /Length 23 >>", b"BT /F1 10 Tf (AB) Tj ET",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}

///|
fn collect_reader_extracted_text(extracted : @text.ExtractedText) -> String {
  let builder = StringBuilder::new()
  for span in extracted.spans {
    builder.write_string(span.text)
  }
  builder.to_string()
}

///|
fn collect_reader_spans_text(spans : Array[@text.TextSpan]) -> String {
  let builder = StringBuilder::new()
  for span in spans {
    builder.write_string(span.text)
  }
  builder.to_string()
}

///|
fn reader_synthetic_truetype_font() -> Bytes {
  try! @fs.read_file_to_bytes(
    ".mooncakes/mizchi/font/fixtures/minimal-cmap12.ttf",
  )
}
