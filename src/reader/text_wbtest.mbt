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
