///|
fn parse_related_files(
  file : PdfFile,
  rf_dict : @objects.PdfDictionary,
  embedded_files : Map[@objects.PdfName, PdfEmbeddedFile],
  owner : @objects.ObjectId?,
) -> Map[@objects.PdfName, Array[PdfRelatedFile]] raise PdfDocumentError {
  let related : Map[@objects.PdfName, Array[PdfRelatedFile]] = Map::new()
  rf_dict.each((key, value) => {
    if !embedded_files.contains(key) {
      raise file_spec_error(owner, "related file key must exist in EF")
    }
    related[key] = parse_related_file_array(file, key, value, owner)
  })
  related
}

///|
fn parse_related_file_array(
  file : PdfFile,
  key : @objects.PdfName,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Array[PdfRelatedFile] raise PdfDocumentError {
  let resolved = resolve_file_spec_child_object(
    file, value, owner, "related files array",
  )
  let values = file_spec_array(resolved.object, owner, "related files array")
  if values.length() % 2 != 0 {
    raise file_spec_error(owner, "related files array must contain pairs")
  }
  let related : Array[PdfRelatedFile] = []
  let mut index = 0
  while index < values.length() {
    let raw_name = values[index]
    let raw_file = values[index + 1]
    let name = file_spec_string(raw_name, owner, "related file name")
    let embedded_file = parse_embedded_file_stream(file, key, raw_file, owner)
    related.push(PdfRelatedFile::{ name, embedded_file, raw_name, raw_file })
    index += 2
  }
  related
}
