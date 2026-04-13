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

///|
pub fn PdfDocument::page_count(self : PdfDocument) -> Int raise PdfDocumentError {
  ensure_page_index(self).pages.length()
}

///|
pub fn PdfDocument::pages(self : PdfDocument) -> Array[PdfPage] raise PdfDocumentError {
  let index = ensure_page_index(self)
  let pages : Array[PdfPage] = []
  for record in index.pages {
    pages.push(PdfPage::{ record })
  }
  pages
}

///|
pub fn PdfDocument::page(
  self : PdfDocument,
  index : Int,
) -> PdfPage raise PdfDocumentError {
  let page_index = ensure_page_index(self)
  let count = page_index.pages.length()
  if index < 0 || index >= count {
    raise PdfDocumentError::PageIndexOutOfRange(index, count)
  }
  PdfPage::{ record: page_index.pages[index] }
}

///|
pub fn PdfPage::index(self : PdfPage) -> Int {
  self.record.index
}

///|
pub fn PdfPage::object_id(self : PdfPage) -> @objects.ObjectId {
  self.record.object_id
}

///|
pub fn PdfPage::parent_ref(self : PdfPage) -> @objects.ObjectId? {
  self.record.parent_ref
}
