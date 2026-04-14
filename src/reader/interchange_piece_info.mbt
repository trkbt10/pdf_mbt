///|
/// Resolves and validates the optional Catalog PieceInfo dictionary.
pub fn PdfDocument::piece_info(
  self : PdfDocument,
) -> @interchange.PdfPagePieceDictionary? raise PdfDocumentError {
  match self.catalog.entry(@objects.PdfName::new(b"PieceInfo")) {
    None => None
    Some(@objects.PdfObject::Null) => None
    Some(@objects.PdfObject::Ref(id)) => {
      let object = load_document_object(self.file, id)
      try
        @interchange.validate_page_piece_dictionary(object_id=Some(id), object)
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        piece_info => Some(piece_info)
      }
    }
    Some(object) =>
      try
        @interchange.validate_page_piece_dictionary(
          object_id=Some(self.catalog.object_id),
          object,
        )
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        piece_info => Some(piece_info)
      }
  }
}

///|
/// Resolves and validates the optional Page PieceInfo dictionary.
pub fn PdfPage::piece_info(
  self : PdfPage,
) -> @interchange.PdfPagePieceDictionary? raise PdfDocumentError {
  match self.entry(@objects.PdfName::new(b"PieceInfo")) {
    None => None
    Some(@objects.PdfObject::Null) => None
    Some(@objects.PdfObject::Ref(id)) => {
      let object = load_document_object(self.file, id)
      try
        @interchange.validate_page_piece_dictionary(object_id=Some(id), object)
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        piece_info => Some(piece_info)
      }
    }
    Some(object) =>
      try
        @interchange.validate_page_piece_dictionary(
          object_id=Some(self.object_id()),
          object,
        )
      catch {
        error => raise PdfDocumentError::InterchangeError(error)
      } noraise {
        piece_info => Some(piece_info)
      }
  }
}
