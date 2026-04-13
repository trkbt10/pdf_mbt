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
pub fn PdfPage::resources(
  self : PdfPage,
) -> @objects.PdfObject? raise PdfDocumentError {
  self.inherited_entry(@objects.PdfName::new(b"Resources"))
}

///|
pub fn PdfPage::inherited_entry(
  self : PdfPage,
  key : @objects.PdfName,
) -> @objects.PdfObject? raise PdfDocumentError {
  if !is_inheritable_page_key(key) {
    raise PdfDocumentError::InvalidInheritedAttribute(
      self.object_id(),
      key,
      "unsupported inherited key",
    )
  }

  if self.entry(key) is Some(value) {
    return Some(value)
  }

  resolve_inherited_page_entry(self.file, self.record.parent_ref, key)
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

///|
fn is_inheritable_page_key(key : @objects.PdfName) -> Bool {
  key == @objects.PdfName::new(b"Resources") ||
  key == @objects.PdfName::new(b"MediaBox") ||
  key == @objects.PdfName::new(b"CropBox") ||
  key == @objects.PdfName::new(b"Rotate")
}

///|
fn resolve_inherited_page_entry(
  file : PdfFile,
  parent_ref : @objects.ObjectId?,
  key : @objects.PdfName,
) -> @objects.PdfObject? raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  let mut current = parent_ref
  while current is Some(parent_id) {
    if seen.contains(parent_id) {
      raise PdfDocumentError::CycleDetected(
        parent_id, "parent chain cycle detected",
      )
    }
    seen[parent_id] = true

    let parent_object = try file.load_object(parent_id) catch {
      error => raise PdfDocumentError::ReaderError(error)
    } noraise {
      value => value
    }

    let parent_dict = match parent_object {
      @objects.PdfObject::Dictionary(dict) => dict
      @objects.PdfObject::Null =>
        raise PdfDocumentError::InvalidInheritedAttribute(
          parent_id, key, "parent node is missing",
        )
      _ =>
        raise PdfDocumentError::InvalidInheritedAttribute(
          parent_id, key, "parent node must be a dictionary",
        )
    }

    require_pages_parent_type(parent_id, key, parent_dict)

    match parent_dict.get(key) {
      Some(value) => return Some(value)
      None => ()
    }

    current = match parent_dict.get(@objects.PdfName::new(b"Parent")) {
      Some(@objects.PdfObject::Ref(next_parent)) => Some(next_parent)
      Some(_) =>
        raise PdfDocumentError::InvalidInheritedAttribute(
          parent_id, key, "parent node /Parent entry must be an indirect reference",
        )
      None => None
    }
  }
  None
}

///|
fn require_pages_parent_type(
  parent_id : @objects.ObjectId,
  key : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> Unit raise PdfDocumentError {
  let type_key = @objects.PdfName::new(b"Type")
  let type_value = match dict.get(type_key) {
    Some(value) => value
    None =>
      raise PdfDocumentError::InvalidInheritedAttribute(
        parent_id, key, "parent node must have /Type /Pages",
      )
  }

  let type_name = match type_value {
    @objects.PdfObject::Name(value) => value
    _ =>
      raise PdfDocumentError::InvalidInheritedAttribute(
        parent_id, key, "parent node /Type entry must be a name",
      )
  }

  if type_name != @objects.PdfName::new(b"Pages") {
    raise PdfDocumentError::InvalidInheritedAttribute(
      parent_id, key, "parent node must have /Type /Pages",
    )
  }
}
