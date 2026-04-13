///|
fn load_catalog(file : PdfFile) -> PdfCatalog raise PdfDocumentError {
  let root_ref = file.root_ref()
  let root_object = try file.load_object(root_ref) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    object => object
  }

  let dict = match root_object {
    @objects.PdfObject::Dictionary(dict) => dict
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidCatalog(
        root_ref,
        "catalog object is missing",
      )
    _ =>
      raise PdfDocumentError::InvalidCatalog(
        root_ref,
        "catalog object must be a dictionary",
      )
  }

  require_catalog_type(root_ref, dict)
  let pages_ref = require_catalog_pages_ref(root_ref, dict)
  PdfCatalog::{ object_id: root_ref, dict, pages_ref }
}

///|
pub fn PdfCatalog::entry(
  self : PdfCatalog,
  key : @objects.PdfName,
) -> @objects.PdfObject? {
  self.dict.get(key)
}

///|
pub fn PdfCatalog::names_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Names"))
}

///|
fn require_catalog_type(
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
) -> Unit raise PdfDocumentError {
  let type_key = @objects.PdfName::new(b"Type")
  let type_value = match dict.get(type_key) {
    Some(value) => value
    None =>
      raise PdfDocumentError::InvalidCatalog(
        object_id,
        "catalog dictionary is missing /Type /Catalog",
      )
  }

  let type_name = match type_value {
    @objects.PdfObject::Name(value) => value
    _ =>
      raise PdfDocumentError::InvalidCatalog(
        object_id,
        "catalog /Type entry must be a name",
      )
  }

  if type_name != @objects.PdfName::new(b"Catalog") {
    raise PdfDocumentError::InvalidCatalog(
      object_id,
      "catalog /Type entry must be /Catalog",
    )
  }
}

///|
fn require_catalog_pages_ref(
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
) -> @objects.ObjectId raise PdfDocumentError {
  let pages_key = @objects.PdfName::new(b"Pages")
  let pages_value = match dict.get(pages_key) {
    Some(value) => value
    None =>
      raise PdfDocumentError::InvalidCatalog(
        object_id,
        "catalog dictionary is missing /Pages",
      )
  }

  match pages_value {
    @objects.PdfObject::Ref(value) => value
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidCatalog(
        object_id,
        "/Pages entry must be an indirect reference",
      )
    _ =>
      raise PdfDocumentError::InvalidCatalog(
        object_id,
        "/Pages entry must be an indirect reference",
      )
  }
}
