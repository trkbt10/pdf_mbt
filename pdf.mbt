///|
/// High-level PDF document handle.
pub type PdfDocument = @pdfapi.PdfDocument

///|
/// High-level PDF page handle.
pub type PdfPage = @pdfapi.PdfPage

///|
/// Image XObject exposed by the high-level page API.
pub type PdfImage = @pdfapi.PdfImage

///|
/// Flattened document outline entry.
pub type OutlineItem = @pdfapi.OutlineItem

///|
/// Document capability support status.
pub type PdfCapabilityStatus = @pdfapi.PdfCapabilityStatus

///|
/// Document capability report entry.
pub type PdfCapabilityEntry = @pdfapi.PdfCapabilityEntry

///|
/// Document capability report.
pub type PdfCapabilityReport = @pdfapi.PdfCapabilityReport

///|
/// Non-fatal extraction warning.
pub type PdfWarning = @pdfapi.PdfWarning

///|
/// Opens a PDF from raw bytes through the public root package API.
pub fn open(bytes : Bytes) -> PdfDocument raise @reader.PdfDocumentError {
  @pdfapi.open(bytes)
}

///|
/// Returns the document Info dictionary Title entry when present.
pub fn document_title(document : PdfDocument) -> String? {
  @pdfapi.document_title(document)
}

///|
/// Returns the document Info dictionary Author entry when present.
pub fn document_author(document : PdfDocument) -> String? {
  @pdfapi.document_author(document)
}

///|
/// Returns the document Info dictionary Subject entry when present.
pub fn document_subject(document : PdfDocument) -> String? {
  @pdfapi.document_subject(document)
}

///|
/// Returns the document Info dictionary Creator entry when present.
pub fn document_creator(document : PdfDocument) -> String? {
  @pdfapi.document_creator(document)
}

///|
/// Extracts concatenated Unicode text from a page.
pub fn extract_page_text(page : PdfPage) -> String {
  @pdfapi.extract_page_text(page)
}

///|
/// Extracts text from all pages in document order.
pub fn extract_all_text(document : PdfDocument) -> String {
  @pdfapi.extract_all_text(document)
}

///|
/// Returns text spans with positional metadata.
pub fn text_spans(page : PdfPage) -> Array[@text.TextSpan] {
  @pdfapi.text_spans(page)
}

///|
/// Enumerates image XObjects referenced by a page.
pub fn page_images(page : PdfPage) -> Array[PdfImage] {
  @pdfapi.page_images(page)
}

///|
/// Returns the effective page width.
pub fn page_width(page : PdfPage) -> Double {
  @pdfapi.page_width(page)
}

///|
/// Returns the effective page height.
pub fn page_height(page : PdfPage) -> Double {
  @pdfapi.page_height(page)
}
