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
        root_ref, "catalog object is missing",
      )
    _ =>
      raise PdfDocumentError::InvalidCatalog(
        root_ref, "catalog object must be a dictionary",
      )
  }

  require_catalog_type(root_ref, dict)
  let pages_ref = require_catalog_pages_ref(root_ref, dict)
  PdfCatalog::{ object_id: root_ref, dict, pages_ref }
}

///|
/// Returns a Catalog dictionary entry such as Type, Pages, PageLabels, Names,
/// Outlines, Metadata, MarkInfo, StructTreeRoot, or Lang.
pub fn PdfCatalog::entry(
  self : PdfCatalog,
  key : @objects.PdfName,
) -> @objects.PdfObject? {
  self.dict.get(key)
}

///|
/// Returns the optional Names entry from the Catalog dictionary for name
/// dictionary access.
pub fn PdfCatalog::names_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Names"))
}

///|
/// Returns the optional AcroForm entry as raw Catalog data. Typed form
/// traversal is layered on top of this entry by the form reader.
pub fn PdfCatalog::acro_form_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"AcroForm"))
}

///|
/// Returns the optional Perms entry from the Catalog dictionary for 12.8.6
/// permissions dictionaries, including DocMDP and deprecated UR3 signatures.
pub fn PdfCatalog::permissions_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Perms"))
}

///|
/// Returns the optional Legal entry from Catalog Table 29 for 12.8.7 legal
/// content attestation dictionaries.
pub fn PdfCatalog::legal_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Legal"))
}

///|
/// Returns the optional DSS entry from the Catalog dictionary for 12.8.4
/// document security store and VRI long term validation data.
pub fn PdfCatalog::dss_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"DSS"))
}

///|
/// Returns the optional Requirements entry from the Catalog dictionary for
/// 12.11 requirement dictionaries evaluated before ECMAScripts.
pub fn PdfCatalog::requirements_entry(self : PdfCatalog) -> @objects.PdfObject? {
  self.entry(@objects.PdfName::new(b"Requirements"))
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
        object_id, "catalog dictionary is missing /Type /Catalog",
      )
  }

  let type_name = match type_value {
    @objects.PdfObject::Name(value) => value
    _ =>
      raise PdfDocumentError::InvalidCatalog(
        object_id, "catalog /Type entry must be a name",
      )
  }

  if type_name != @objects.PdfName::new(b"Catalog") {
    raise PdfDocumentError::InvalidCatalog(
      object_id, "catalog /Type entry must be /Catalog",
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
        object_id, "catalog dictionary is missing /Pages",
      )
  }

  match pages_value {
    @objects.PdfObject::Ref(value) => value
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidCatalog(
        object_id, "/Pages entry must be an indirect reference",
      )
    _ =>
      raise PdfDocumentError::InvalidCatalog(
        object_id, "/Pages entry must be an indirect reference",
      )
  }
}
