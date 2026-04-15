///|
/// Extracts concatenated Unicode text from a page without requiring the caller
/// to understand fonts, encodings, or content stream text operators.
pub fn extract_page_text(page : PdfPage) -> String {
  extract_reader_page_text(page.inner)
}

///|
/// Implements Requirement 2.2 structured text extraction:
/// `PdfPage::text_spans() -> Array[TextSpan]` SHALL return text spans with
/// positional metadata, including text matrix and font name, for layout-aware
/// consumers.
/// The function-style alias is `text_spans(page : PdfPage) -> Array[TextSpan]`.
pub fn text_spans(page : PdfPage) -> Array[@text.TextSpan] {
  reader_page_text_spans(page.inner)
}

///|
/// Extracts text from all pages in document order and separates page output
/// with form-feed characters (`\f`), matching whole-document pdftotext-style
/// consumers.
pub fn extract_all_text(document : PdfDocument) -> String {
  let pages_result : Result[Array[PdfPage], @reader.PdfDocumentError] = try? document.pages()
  match pages_result {
    Ok(pages) => {
      let builder = StringBuilder::new()
      for index in 0..<pages.length() {
        if index > 0 {
          builder.write_string("\f")
        }
        builder.write_string(extract_page_text(pages[index]))
      }
      builder.to_string()
    }
    Err(_) => ""
  }
}

///|
/// Page-level primary entry point for concatenated Unicode text extraction.
pub fn PdfPage::extract_text(self : PdfPage) -> String {
  extract_page_text(self)
}

///|
/// Page-level structured text extraction entry point returning text spans and
/// their positioning metadata.
pub fn PdfPage::text_spans(self : PdfPage) -> Array[@text.TextSpan] {
  text_spans(self)
}

///|
/// Document-level text extraction that concatenates all pages with form-feed
/// separators.
pub fn PdfDocument::extract_all_text(self : PdfDocument) -> String {
  extract_all_text(self)
}

///|
fn extract_reader_page_text(page : @reader.PdfPage) -> String {
  let result : Result[@text.ExtractedText, @reader.PdfDocumentError] = try? page.extracted_text(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(extracted) => text_from_spans(extracted.spans)
    Err(_) => ""
  }
}

///|
fn reader_page_text_spans(page : @reader.PdfPage) -> Array[@text.TextSpan] {
  let result : Result[@text.ExtractedText, @reader.PdfDocumentError] = try? page.extracted_text(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(extracted) => extracted.spans
    Err(_) => []
  }
}

///|
fn text_from_spans(spans : Array[@text.TextSpan]) -> String {
  let builder = StringBuilder::new()
  for span in spans {
    builder.write_string(span.text)
  }
  builder.to_string()
}
