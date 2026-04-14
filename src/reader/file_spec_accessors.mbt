///|
pub fn PdfFile::parse_file_spec(
  self : PdfFile,
  value : @objects.PdfObject,
) -> PdfFileSpecification raise PdfDocumentError {
  let resolved = resolve_file_spec_object(self, value, "file specification")
  match resolved.object {
    @objects.PdfObject::String(bytes) =>
      PdfFileSpecification::Simple(PdfSimpleFileSpecification::{
        raw_string: bytes,
        path: parse_file_spec_path(bytes),
        source_object_id: resolved.source_object_id,
        indirect: resolved.indirect,
        raw_object: resolved.raw_object,
      })
    @objects.PdfObject::Dictionary(_) =>
      PdfFileSpecification::Full(parse_file_spec_dictionary(self, resolved))
    _ =>
      raise file_spec_error(
        resolved.source_object_id,
        "file specification must be a string or dictionary",
      )
  }
}

///|
pub fn PdfDocument::parse_file_spec(
  self : PdfDocument,
  value : @objects.PdfObject,
) -> PdfFileSpecification raise PdfDocumentError {
  self.file.parse_file_spec(value)
}

///|
pub fn PdfDocument::embedded_files(
  self : PdfDocument,
) -> Array[PdfEmbeddedFileEntry] raise PdfDocumentError {
  let entries = self.name_tree_entries(NameTreeCategory::EmbeddedFiles)
  let out : Array[PdfEmbeddedFileEntry] = []
  for entry in entries {
    out.push(PdfEmbeddedFileEntry::{
      name: entry.key,
      file_specification: self.parse_file_spec(entry.value),
      raw_value: entry.value,
    })
  }
  out
}
