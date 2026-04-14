///|
/// Interchange diagnostics for ISO 32000-2 clause 14.1 through 14.6 read-side
/// validation. Optional object identifiers name the owner object when the
/// caller has that context; shared validators never load reader-owned objects.
pub(all) suberror PdfInterchangeError {
  InvalidMetadata(@objects.ObjectId?, String)
  InvalidDocumentInfo(@objects.ObjectId?, String)
  InvalidFileIdentifier(String)
  InvalidPagePiece(@objects.ObjectId?, String)
  InvalidProcedureSet(String)
  InvalidMarkedContent(Int64, String)
  FilterError(@filters.PdfFilterError)
  ContentError(@content.PdfContentError)
} derive(Eq, Debug)
