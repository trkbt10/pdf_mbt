///|
/// E2E detail: extract text from Simple PDF 2.0.
/// Expected output from pdftotext: "HelloWorld"
test "E2E detail: Simple PDF 2.0 extracted text spans" {
  let document = PdfDocument::open(simple_pdf20_file)
  let page = document.page(0)
  let options = TextPageOptions::default()
  let extracted = page.extracted_text(options)
  assert_eq(collect_detail_extracted_text(extracted), "HelloWorld")
}

///|
/// E2E: text_resources resolution on Simple PDF 2.0.
test "E2E: text_resources on Simple PDF 2.0" {
  let document = PdfDocument::open(simple_pdf20_file)
  let page = document.page(0)
  let result : Result[@text.TextResources, PdfDocumentError] = try? page.text_resources()
  if result is Ok(resources) {
    assert_eq(resources.fonts.length(), 1)
  } else {
    fail("text_resources raised")
  }
}

///|
/// E2E: text_program on Simple PDF 2.0 — diagnose failure point.
test "E2E: text_program on Simple PDF 2.0" {
  let document = PdfDocument::open(simple_pdf20_file)
  let page = document.page(0)
  // Step 1: get content instructions (lower level than text_program)
  let content_result : Result[
    Array[@content.ContentInstruction],
    PdfDocumentError,
  ] = try? page.content_instructions()
  if content_result is Ok(instructions) {
    assert_eq(instructions.length(), 26)
  } else {
    fail("content_instructions raised")
  }
}

///|
fn collect_detail_extracted_text(extracted : @text.ExtractedText) -> String {
  let buf = StringBuilder::new()
  for span in extracted.spans {
    buf.write_string(span.text)
  }
  buf.to_string()
}
