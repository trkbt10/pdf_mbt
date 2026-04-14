///|
test "related files enforce EF key consistency and pair shape" {
  let document = PdfDocument::open(build_file_spec_embedded_fixture())
  match document.parse_file_spec(@objects.PdfObject::Ref(oid(6))) {
    Full(full) => {
      let related = full.related_files.get(file_spec_test_name(b"UF")).unwrap()
      assert_eq(related.length(), 1)
      assert_eq(related[0].name, b"related.bin")
      assert_eq(
        related[0].embedded_file.source_object_id == Some(oid(11)),
        true,
      )
      assert_eq(related[0].embedded_file.raw_stream.data, b"REL")
    }
    _ => fail("expected full file specification")
  }

  let rf_dict : @objects.PdfDictionary = Map::new()
  rf_dict[file_spec_test_name(b"Missing")] = @objects.PdfObject::Array([])
  let empty_ef : Map[@objects.PdfName, PdfEmbeddedFile] = Map::new()
  let bad_key : Result[
    Map[@objects.PdfName, Array[PdfRelatedFile]],
    PdfDocumentError,
  ] = try? parse_related_files(document.file, rf_dict, empty_ef, Some(oid(6)))
  match bad_key {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("EF"), true)
    _ => fail("expected missing EF key rejection")
  }

  let bad_array : Result[Array[PdfRelatedFile], PdfDocumentError] = try? parse_related_file_array(
    document.file,
    file_spec_test_name(b"UF"),
    @objects.PdfObject::Array([@objects.PdfObject::String(b"lonely")]),
    Some(oid(6)),
  )
  match bad_array {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("pairs"), true)
    _ => fail("expected malformed related array rejection")
  }
}
