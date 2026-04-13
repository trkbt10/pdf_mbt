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
  PdfDocument::{ file: self, catalog, page_index: None }
}

///|
pub fn PdfDocument::catalog(self : PdfDocument) -> PdfCatalog {
  let _ = self.file.root_ref()
  self.catalog
}

///|
fn ensure_page_index(document : PdfDocument) -> PageTreeIndex raise PdfDocumentError {
  match document.page_index {
    Some(index) => index
    None => {
      let index = build_page_tree_index(document.file, document.catalog)
      document.page_index = Some(index)
      index
    }
  }
}
