///|
/// Resolves and validates the optional Catalog Metadata stream.
pub fn PdfDocument::metadata_stream(
  self : PdfDocument,
) -> @interchange.PdfMetadataStream? raise PdfDocumentError {
  match self.catalog.entry(@objects.PdfName::new(b"Metadata")) {
    None => None
    Some(@objects.PdfObject::Null) => None
    Some(@objects.PdfObject::Ref(id)) => {
      let object = resolve_indirect(self.file, @objects.PdfObject::Ref(id))
      try
        @interchange.validate_metadata_stream(object_id=Some(id), object)
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        metadata => Some(metadata)
      }
    }
    Some(object) =>
      try
        @interchange.validate_metadata_stream(
          object_id=Some(self.catalog.object_id),
          object,
        )
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        metadata => Some(metadata)
      }
  }
}

///|
/// Resolves and validates the optional trailer Info dictionary.
pub fn PdfDocument::document_info(
  self : PdfDocument,
) -> @interchange.PdfDocumentInfo? raise PdfDocumentError {
  match self.file.trailer.info {
    None => None
    Some(id) => {
      let object = resolve_indirect(self.file, @objects.PdfObject::Ref(id))
      try
        @interchange.validate_document_info(object_id=Some(id), object)
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        info => Some(info)
      }
    }
  }
}

///|
/// Returns Catalog Metadata, trailer Info, and non-mutating source diagnostics.
pub fn PdfDocument::metadata_sources(
  self : PdfDocument,
) -> @interchange.PdfDocumentMetadataSources raise PdfDocumentError {
  let metadata = self.metadata_stream()
  let info = self.document_info()
  @interchange.PdfDocumentMetadataSources::{
    metadata_stream: metadata,
    document_info: info,
    diagnostics: @interchange.metadata_source_diagnostics(metadata, info),
  }
}
