///|
/// Returns the validated trailer file identifier pair when present.
pub fn PdfFile::file_id(self : PdfFile) -> PdfFileId? {
  self.trailer.id
}

///|
/// Compares this file identifier against a caller-supplied reference by exact
/// byte equality of both identifier strings.
pub fn PdfFileId::compare_reference(
  self : PdfFileId,
  reference : PdfFileId,
) -> @interchange.PdfFileIdMatch {
  @interchange.compare_file_identifier_bytes(
    self.first,
    self.second,
    reference.first,
    reference.second,
  )
}

///|
/// Compares an optional current identifier against a reference and reports
/// missing current identifiers distinctly.
pub fn compare_file_id_reference(
  current : PdfFileId?,
  reference : PdfFileId,
) -> @interchange.PdfFileIdMatch {
  match current {
    Some(value) => value.compare_reference(reference)
    None => @interchange.PdfFileIdMatch::MissingCurrentIdentifier
  }
}

///|
/// Convenience comparison over the current file's trailer identifier.
pub fn PdfFile::compare_file_id_reference(
  self : PdfFile,
  reference : PdfFileId,
) -> @interchange.PdfFileIdMatch {
  compare_file_id_reference(self.file_id(), reference)
}
