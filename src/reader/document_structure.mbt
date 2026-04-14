///|
/// Opens bytes as a PdfDocument and resolves the document structure layer.
/// This is the public entry point for Catalog, Pages, Page, page count, and
/// page index access.
pub fn PdfDocument::open(input : Bytes) -> PdfDocument raise PdfDocumentError {
  let file = try PdfFile::open(input) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    file => file
  }
  file.document()
}

///|
/// Builds a PdfDocument from an already opened PdfFile, following the trailer
/// Root indirect reference to the validated Catalog dictionary.
pub fn PdfFile::document(self : PdfFile) -> PdfDocument raise PdfDocumentError {
  let catalog = load_catalog(self)
  PdfDocument::{ file: self, catalog, page_index: None }
}

///|
/// Returns the validated Catalog dictionary facade, including Type Catalog and
/// the required Pages reference to the root page tree node.
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
/// Reports the total page count by lazily traversing the Pages tree and
/// verifying Count against the discovered leaf Page objects.
pub fn PdfDocument::page_count(
  self : PdfDocument,
) -> Int raise PdfDocumentError {
  ensure_page_index(self).pages.length()
}

///|
/// Enumerates all pages in document order by recursively traversing Kids from
/// intermediate Pages nodes to leaf Page objects.
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
/// Returns the Page object for a zero-based page index and raises an error
/// when the index is outside the page count.
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
/// Returns this Page object's zero-based index in document order.
pub fn PdfPage::index(self : PdfPage) -> Int {
  self.record.index
}

///|
/// Returns the indirect object id of this leaf Page object.
pub fn PdfPage::object_id(self : PdfPage) -> @objects.ObjectId {
  self.record.object_id
}

///|
/// Returns the Parent entry reference that links this Page to its ancestor
/// Pages node, if present.
pub fn PdfPage::parent_ref(self : PdfPage) -> @objects.ObjectId? {
  self.record.parent_ref
}

///|
/// Returns a raw direct page dictionary entry without inheritance or indirect
/// reference resolution. Use inherited_entry for Resources, MediaBox, CropBox,
/// and Rotate when ancestor Pages nodes should be searched.
pub fn PdfPage::entry(
  self : PdfPage,
  key : @objects.PdfName,
) -> @objects.PdfObject? {
  self.record.dict.get(key)
}

///|
/// Returns the optional Contents entry from the Page object.
pub fn PdfPage::contents(self : PdfPage) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Contents"))
}

///|
/// Returns the optional Annots entry from the Page object.
pub fn PdfPage::annots(self : PdfPage) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Annots"))
}

///|
/// Returns the inheritable Resources entry from this Page or the nearest
/// ancestor Pages node via Parent, following Requirement 4 and ISO 32000-2
/// section 7.7.3.4.
pub fn PdfPage::resources(
  self : PdfPage,
) -> @objects.PdfObject? raise PdfDocumentError {
  self.inherited_entry(@objects.PdfName::new(b"Resources"))
}

///|
/// Returns the inheritable MediaBox entry as a four-number page boundary from
/// this Page or the nearest ancestor Pages node via Parent. If neither the page
/// nor any ancestor defines MediaBox, the entry is absent.
pub fn PdfPage::media_box(
  self : PdfPage,
) -> PdfRectangle? raise PdfDocumentError {
  resolve_typed_page_rectangle(self, @objects.PdfName::new(b"MediaBox"))
}

///|
/// Returns the inheritable CropBox entry as a four-number page boundary from
/// this Page or the nearest ancestor Pages node via Parent. If neither the page
/// nor any ancestor defines CropBox, the entry is absent.
pub fn PdfPage::crop_box(
  self : PdfPage,
) -> PdfRectangle? raise PdfDocumentError {
  resolve_typed_page_rectangle(self, @objects.PdfName::new(b"CropBox"))
}

///|
/// Returns the inheritable Rotate entry from this Page or the nearest ancestor
/// Pages node via Parent. If neither the page nor any ancestor defines Rotate,
/// the entry is absent.
pub fn PdfPage::rotate(self : PdfPage) -> Int? raise PdfDocumentError {
  resolve_typed_page_integer(self, @objects.PdfName::new(b"Rotate"))
}

///|
/// Returns the optional UserUnit entry defined directly on the Page object.
pub fn PdfPage::user_unit(self : PdfPage) -> Double? raise PdfDocumentError {
  match self.entry(@objects.PdfName::new(b"UserUnit")) {
    Some(value) =>
      Some(
        parse_typed_page_number(
          self.object_id(),
          @objects.PdfName::new(b"UserUnit"),
          value,
          "UserUnit",
          false,
        ),
      )
    None => None
  }
}

///|
/// Implements Page Attribute Inheritance for Requirement 4. When a Page object
/// lacks Resources, MediaBox, CropBox, or Rotate, the ancestor Pages nodes are
/// searched through Parent links until the nearest ancestor value is found or
/// the root is reached; missing inherited entries are returned as absent.
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

  match resolve_inherited_page_entry(self.file, self.record.parent_ref, key) {
    Some(found) => Some(found.value)
    None => None
  }
}

///|
/// Resolves indirect references inside a direct Page entry on demand, including
/// arrays used by page attributes such as Contents, Annots, and resources.
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
priv struct InheritedPageEntry {
  source_id : @objects.ObjectId
  value : @objects.PdfObject
}

///|
fn resolve_inherited_page_entry(
  file : PdfFile,
  parent_ref : @objects.ObjectId?,
  key : @objects.PdfName,
) -> InheritedPageEntry? raise PdfDocumentError {
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
      Some(value) =>
        return Some(InheritedPageEntry::{ source_id: parent_id, value })
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

///|
fn resolve_typed_page_rectangle(
  page : PdfPage,
  key : @objects.PdfName,
) -> PdfRectangle? raise PdfDocumentError {
  let label = typed_page_key_label(key)
  match page.entry(key) {
    Some(value) =>
      Some(
        parse_typed_page_rectangle(page.object_id(), key, value, label, false),
      )
    None =>
      match
        resolve_inherited_page_entry(page.file, page.record.parent_ref, key) {
        Some(found) =>
          Some(
            parse_typed_page_rectangle(
              found.source_id,
              key,
              found.value,
              label,
              true,
            ),
          )
        None => None
      }
  }
}

///|
fn resolve_typed_page_integer(
  page : PdfPage,
  key : @objects.PdfName,
) -> Int? raise PdfDocumentError {
  let label = typed_page_key_label(key)
  match page.entry(key) {
    Some(value) =>
      Some(parse_typed_page_integer(page.object_id(), key, value, label, false))
    None =>
      match
        resolve_inherited_page_entry(page.file, page.record.parent_ref, key) {
        Some(found) =>
          Some(
            parse_typed_page_integer(
              found.source_id,
              key,
              found.value,
              label,
              true,
            ),
          )
        None => None
      }
  }
}

///|
fn typed_page_key_label(key : @objects.PdfName) -> String {
  if key == @objects.PdfName::new(b"MediaBox") {
    "MediaBox"
  } else if key == @objects.PdfName::new(b"CropBox") {
    "CropBox"
  } else if key == @objects.PdfName::new(b"Rotate") {
    "Rotate"
  } else if key == @objects.PdfName::new(b"UserUnit") {
    "UserUnit"
  } else {
    "page attribute"
  }
}

///|
fn parse_typed_page_rectangle(
  page_id : @objects.ObjectId,
  key : @objects.PdfName,
  value : @objects.PdfObject,
  label : String,
  inherited : Bool,
) -> PdfRectangle raise PdfDocumentError {
  typed_page_rectangle(page_id, key, value, label, inherited)
}

///|
fn parse_typed_page_integer(
  page_id : @objects.ObjectId,
  key : @objects.PdfName,
  value : @objects.PdfObject,
  label : String,
  inherited : Bool,
) -> Int raise PdfDocumentError {
  let error = typed_page_error(
    page_id,
    key,
    label + " must be an integer",
    inherited,
  )
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ => raise error
  }
}

///|
fn parse_typed_page_number(
  page_id : @objects.ObjectId,
  key : @objects.PdfName,
  value : @objects.PdfObject,
  label : String,
  inherited : Bool,
) -> Double raise PdfDocumentError {
  let error = typed_page_error(
    page_id,
    key,
    label + " must be a number",
    inherited,
  )
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise error
  }
}

///|
fn typed_page_error(
  page_id : @objects.ObjectId,
  key : @objects.PdfName,
  reason : String,
  inherited : Bool,
) -> PdfDocumentError {
  let reason = if inherited { "inherited " + reason } else { reason }
  if inherited {
    PdfDocumentError::InvalidInheritedAttribute(page_id, key, reason)
  } else {
    PdfDocumentError::InvalidPage(page_id, reason)
  }
}
