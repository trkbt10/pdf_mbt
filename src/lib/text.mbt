///|
pub fn extract_page_text(page : PdfPage) -> String {
  extract_reader_page_text(page.inner)
}

///|
pub fn text_spans(page : PdfPage) -> Array[@text.TextSpan] {
  reader_page_text_spans(page.inner)
}

///|
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
pub fn PdfPage::extract_text(self : PdfPage) -> String {
  extract_page_text(self)
}

///|
pub fn PdfPage::text_spans(self : PdfPage) -> Array[@text.TextSpan] {
  text_spans(self)
}

///|
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
