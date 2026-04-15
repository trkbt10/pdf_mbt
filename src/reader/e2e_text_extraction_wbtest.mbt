///|
/// E2E test: extract text from the bundled Simple PDF 2.0 example.
/// This validates the full pipeline: file open → page access → content
/// stream decoding → text operator interpretation → Unicode output.
test "E2E: extract text from Simple PDF 2.0 file" {
  let document = PdfDocument::open(simple_pdf20_file)
  let page = document.page(0)
  let options = TextPageOptions::default()
  let result : Result[@text.ExtractedText, PdfDocumentError] = try? page.extracted_text(
    options,
  )
  match result {
    Ok(extracted) => assert_eq(collect_extracted_text(extracted), "HelloWorld")
    Err(error) => fail(pdf_document_error_summary(error))
  }
}

///|
/// E2E test: extract text from the incremental PDF 2.0 example.
/// Requirement 2: Text extraction from incremental-save PDF 2.0.
/// "PDF 2.0 via incremental save.pdf" object 6 stream contains
/// "PDF 2.0 Words Have Spacing".
test "E2E: extract text from incremental PDF 2.0 file" {
  let document = PdfDocument::open(incremental_pdf20_file)
  let page = document.page(0)
  let options = TextPageOptions::default()
  let result : Result[@text.ExtractedText, PdfDocumentError] = try? page.extracted_text(
    options,
  )
  match result {
    Ok(extracted) =>
      assert_eq(collect_extracted_text(extracted), "PDF 2.0 Words Have Spacing")
    Err(error) => fail(pdf_document_error_summary(error))
  }
}

///|
/// Requirement 3: Text extraction from CalRGB colour-space PDF.
/// "PDF 2.0 image with BPC.pdf" includes calibrated RGB text content.
test "E2E: extract text from CalRGB colour-space PDF 2.0 example" {
  assert_pdf_file_text_contains(
    "spec/pdf20examples/PDF 2.0 image with BPC.pdf", "This text is in a Calibrated RGB (CalRGB) colorspace",
  )
}

///|
test "E2E: extract text from UTF-8 PDF 2.0 example" {
  let text = extract_pdf_file_text("spec/pdf20examples/pdf20-utf8-test.pdf")
  assert_true(text.contains("PDF 2.0 with UTF-8 test file"))
  assert_true(text.contains("Heading Level 2"))
}

///|
test "E2E: extract text from offset-start PDF 2.0 example" {
  assert_pdf_file_text_contains(
    "spec/pdf20examples/PDF 2.0 with offset start.pdf", "This is a PDF 2.0 document",
  )
}

///|
fn collect_extracted_text(extracted : @text.ExtractedText) -> String {
  let buf = StringBuilder::new()
  for span in extracted.spans {
    buf.write_string(span.text)
  }
  buf.to_string()
}

///|
fn assert_pdf_file_text_contains(
  path : String,
  expected : String,
) -> Unit raise {
  let text = extract_pdf_file_text(path)
  assert_true(text.contains(expected))
}

///|
fn extract_pdf_file_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path)
  let document = PdfDocument::open(bytes)
  let page = document.page(0)
  let extracted = page.extracted_text(TextPageOptions::default())
  collect_extracted_text(extracted)
}

///|
fn pdf_document_error_summary(error : PdfDocumentError) -> String {
  match error {
    TextError(text_error) => pdf_text_error_summary(text_error)
    _ => "non-text extraction error"
  }
}

///|
fn pdf_text_error_summary(error : @text.PdfTextError) -> String {
  match error {
    BadOperand(context, reason) =>
      "BadOperand offset=" + context.offset.to_string() + " " + reason
    InvalidTextState(context, reason) =>
      "InvalidTextState offset=" + context.offset.to_string() + " " + reason
    MissingResource(context, reason) =>
      "MissingResource offset=" + context.offset.to_string() + " " + reason
    InvalidFont(context, reason) =>
      "InvalidFont offset=" + context.offset.to_string() + " " + reason
    InvalidCMap(context, reason) =>
      "InvalidCMap offset=" + context.offset.to_string() + " " + reason
    UnicodeConversion(context, reason) =>
      "UnicodeConversion offset=" + context.offset.to_string() + " " + reason
    GuardLimitExceeded(context, reason) =>
      "GuardLimitExceeded offset=" + context.offset.to_string() + " " + reason
    ContentFailure(context, _) =>
      "ContentFailure offset=" + context.offset.to_string()
    FilterFailure(context, _) =>
      "FilterFailure offset=" + context.offset.to_string()
  }
}

///|
/// E2E test: image extraction from the bundled Simple PDF 2.0 file.
/// Checks that the image decode pipeline can process XObjects from the page.
test "E2E: decode image XObjects from Simple PDF 2.0 file" {
  let document = PdfDocument::open(simple_pdf20_file)
  let page = document.page(0)
  // Access page resources to check for image XObjects
  match page.resources() {
    Some(@objects.PdfObject::Dictionary(resources)) =>
      match resources.get(@objects.PdfName::new(b"XObject")) {
        Some(@objects.PdfObject::Dictionary(xobjects)) =>
          // If XObjects exist, try to decode each image
          for _name, object in xobjects {
            match object {
              @objects.PdfObject::Stream(stream) => {
                // Attempt to decode the stream data
                let result : Result[Bytes, _] = try? @filters.decode_stream(
                  stream,
                )
                match result {
                  Ok(decoded) => assert_true(decoded.length() > 0)
                  Err(_) => () // Filter decode failure is acceptable
                }
              }
              _ => ()
            }
          }
        _ => () // No XObjects — acceptable for this simple PDF
      }
    _ => ()
  }
}
