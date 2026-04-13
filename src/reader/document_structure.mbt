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
fn ensure_page_index(
  document : PdfDocument,
) -> PageTreeIndex raise PdfDocumentError {
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
pub fn PdfDocument::page_count(
  self : PdfDocument,
) -> Int raise PdfDocumentError {
  ensure_page_index(self).pages.length()
}

///|
pub fn PdfDocument::pages(
  self : PdfDocument,
) -> Array[PdfPage] raise PdfDocumentError {
  let index = ensure_page_index(self)
  let pages : Array[PdfPage] = []
  for record in index.pages {
    pages.push(PdfPage::{ file: self.file, record })
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
  PdfPage::{ file: self.file, record: page_index.pages[index] }
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

///|
pub fn PdfPage::entry(
  self : PdfPage,
  key : @objects.PdfName,
) -> @objects.PdfObject? {
  self.record.dict.get(key)
}

///|
pub fn PdfPage::contents(self : PdfPage) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Contents"))
}

///|
pub fn PdfPage::annots(self : PdfPage) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Annots"))
}

///|
pub fn PdfPage::resolve_entry(
  self : PdfPage,
  key : @objects.PdfName,
) -> @objects.PdfObject? raise PdfDocumentError {
  match self.entry(key) {
    Some(value) => Some(resolve_page_entry_value(self.file, value))
    None => None
  }
}

///|
fn resolve_page_entry_value(
  file : PdfFile,
  value : @objects.PdfObject,
) -> @objects.PdfObject raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) =>
      try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        loaded => loaded
      }
    @objects.PdfObject::Array(values) =>
      @objects.PdfObject::Array(resolve_page_entry_array(file, values))
    _ => value
  }
}

///|
fn resolve_page_entry_array(
  file : PdfFile,
  values : Array[@objects.PdfObject],
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  let resolved : Array[@objects.PdfObject] = []
  for value in values {
    match value {
      @objects.PdfObject::Ref(object_id) => {
        let loaded = try file.load_object(object_id) catch {
          error => raise PdfDocumentError::ReaderError(error)
        } noraise {
          loaded => loaded
        }
        resolved.push(loaded)
      }
      _ => resolved.push(value)
    }
  }
  resolved
}
