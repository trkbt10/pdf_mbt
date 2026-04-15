///|
pub(all) struct PdfDocument {
  inner : @reader.PdfDocument
}

///|
pub(all) struct PdfPage {
  inner : @reader.PdfPage
}

///|
pub fn open(bytes : Bytes) -> PdfDocument raise @reader.PdfDocumentError {
  PdfDocument::{ inner: @reader.PdfDocument::open(bytes) }
}

///|
pub fn PdfDocument::from_reader(document : @reader.PdfDocument) -> PdfDocument {
  PdfDocument::{ inner: document }
}

///|
pub fn PdfDocument::reader_document(self : PdfDocument) -> @reader.PdfDocument {
  self.inner
}

///|
pub fn PdfDocument::page_count(
  self : PdfDocument,
) -> Int raise @reader.PdfDocumentError {
  self.inner.page_count()
}

///|
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
pub fn PdfDocument::page(
  self : PdfDocument,
  index : Int,
) -> PdfPage raise @reader.PdfDocumentError {
  PdfPage::{ inner: self.inner.page(index) }
}

///|
pub fn PdfPage::from_reader(page : @reader.PdfPage) -> PdfPage {
  PdfPage::{ inner: page }
}

///|
pub fn PdfPage::reader_page(self : PdfPage) -> @reader.PdfPage {
  self.inner
}
