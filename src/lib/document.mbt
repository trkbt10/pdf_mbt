///|
/// High-level document handle exported from the single-import public API
/// package. Callers can open raw bytes, inspect pages, metadata, outline
/// bookmarks, and capability reports without importing internal subpackages.
pub(all) struct PdfDocument {
  inner : @reader.PdfDocument
}

///|
/// High-level page handle returned by `PdfDocument::pages()` and
/// `PdfDocument::page(index)`. It exposes text extraction, image extraction,
/// page geometry, and page-level warnings without exposing internal
/// subpackages.
pub(all) struct PdfPage {
  inner : @reader.PdfPage
}

///|
/// Opens a PDF from raw bytes through the public API and returns a
/// `PdfDocument` for page access, metadata queries, and structure traversal.
pub fn open(bytes : Bytes) -> PdfDocument raise @reader.PdfDocumentError {
  PdfDocument::{ inner: @reader.PdfDocument::open(bytes) }
}

///|
/// Wraps an internal reader document so applications can bridge from lower
/// level parser code into the high-level API.
pub fn PdfDocument::from_reader(document : @reader.PdfDocument) -> PdfDocument {
  PdfDocument::{ inner: document }
}

///|
/// Returns the underlying reader document for advanced callers that need
/// internal subpackage access outside the high-level public API.
pub fn PdfDocument::reader_document(self : PdfDocument) -> @reader.PdfDocument {
  self.inner
}

///|
/// Returns the total page count after validating and traversing the document
/// page tree.
pub fn PdfDocument::page_count(
  self : PdfDocument,
) -> Int raise @reader.PdfDocumentError {
  self.inner.page_count()
}

///|
/// Enumerates every `PdfPage` in document order for whole-document access.
pub fn PdfDocument::pages(
  self : PdfDocument,
) -> Array[PdfPage] raise @reader.PdfDocumentError {
  let pages : Array[PdfPage] = []
  for page in self.inner.pages() {
    pages.push(PdfPage::{ inner: page })
  }
  pages
}

///|
/// Returns one zero-based indexed `PdfPage`; out-of-range indexes raise the
/// reader document error used by the public API.
pub fn PdfDocument::page(
  self : PdfDocument,
  index : Int,
) -> PdfPage raise @reader.PdfDocumentError {
  PdfPage::{ inner: self.inner.page(index) }
}

///|
/// Wraps an internal reader page so applications can bridge from lower level
/// document-structure code into the high-level page API.
pub fn PdfPage::from_reader(page : @reader.PdfPage) -> PdfPage {
  PdfPage::{ inner: page }
}

///|
/// Returns the underlying reader page for advanced callers while keeping the
/// high-level API as the single-import entry point for page access, text
/// extraction, image extraction, metadata, and structure traversal.
/// The bridge signature is `PdfPage::reader_page() -> reader.PdfPage`.
pub fn PdfPage::reader_page(self : PdfPage) -> @reader.PdfPage {
  self.inner
}
