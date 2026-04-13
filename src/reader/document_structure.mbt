///|
pub fn PdfDocument::open(input : Bytes) -> PdfDocument raise PdfDocumentError {
  let file = try PdfFile::open(input) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    file => file
  }
  file.document()
}

///|
pub fn PdfFile::document(self : PdfFile) -> PdfDocument raise PdfDocumentError {
  let catalog = load_catalog(self)
  PdfDocument::{ file: self, catalog }
}

///|
pub fn PdfDocument::catalog(self : PdfDocument) -> PdfCatalog {
  let _ = self.file.root_ref()
  self.catalog
}
