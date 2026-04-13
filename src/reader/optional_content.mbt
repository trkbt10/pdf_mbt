///|
pub fn PdfDocument::optional_content_state(
  self : PdfDocument,
) -> @graphics.OptionalContentState raise PdfDocumentError {
  catalog_optional_content_state(self.file, self.catalog)
}

///|
pub fn PdfPage::optional_content_state(
  self : PdfPage,
) -> @graphics.OptionalContentState raise PdfDocumentError {
  let catalog = load_catalog(self.file)
  catalog_optional_content_state(self.file, catalog)
}

///|
fn catalog_optional_content_state(
  file : PdfFile,
  catalog : PdfCatalog,
) -> @graphics.OptionalContentState raise PdfDocumentError {
  let entry = catalog.entry(@objects.PdfName::new(b"OCProperties"))
  let resolved = resolve_optional_content_object(file, entry)
  validate_ocg_references(file, resolved)
  try @graphics.parse_optional_content_properties(resolved, 0L) catch {
    error => raise PdfDocumentError::GraphicsError(error)
  } noraise {
    state => state
  }
}

///|
fn resolve_optional_content_object(
  file : PdfFile,
  object : @objects.PdfObject?,
) -> @objects.PdfObject? raise PdfDocumentError {
  match object {
    Some(@objects.PdfObject::Ref(id)) => Some(load_document_object(file, id))
    _ => object
  }
}

///|
fn validate_ocg_references(
  file : PdfFile,
  object : @objects.PdfObject?,
) -> Unit raise PdfDocumentError {
  match object {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      match dict.get(@objects.PdfName::new(b"OCGs")) {
        Some(@objects.PdfObject::Array(values)) =>
          for value in values {
            match value {
              @objects.PdfObject::Ref(id) =>
                match load_document_object(file, id) {
                  @objects.PdfObject::Dictionary(_) => ()
                  @objects.PdfObject::Null =>
                    raise PdfDocumentError::InvalidCatalog(
                      file.root_ref(),
                      "OCG reference is missing",
                    )
                  _ =>
                    raise PdfDocumentError::InvalidCatalog(
                      file.root_ref(),
                      "OCG reference must resolve to a dictionary",
                    )
                }
              @objects.PdfObject::Null => ()
              _ =>
                raise PdfDocumentError::InvalidCatalog(
                  file.root_ref(),
                  "OCGs entries must be indirect references",
                )
            }
          }
        Some(_) =>
          raise PdfDocumentError::InvalidCatalog(
            file.root_ref(),
            "OCGs must be an array",
          )
        None => ()
      }
    _ => ()
  }
}
