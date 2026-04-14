///|
test "embedded file descriptors retain stream metadata and raw payload" {
  let document = PdfDocument::open(build_file_spec_embedded_fixture())
  match document.parse_file_spec(@objects.PdfObject::Ref(oid(6))) {
    Full(full) => {
      let embedded = full.embedded_files.get(file_spec_test_name(b"F")).unwrap()
      assert_eq(embedded.source_object_id == Some(oid(7)), true)
      assert_eq(embedded.raw_stream.data, b"DATA")
      assert_eq(embedded.subtype.unwrap().to_text(), "application/octet-stream")
      assert_eq(embedded.params.unwrap().size, Some(4L))
      assert_eq(embedded.params.unwrap().checksum, Some(b"1234567890abcdef"))
      assert_eq(embedded.params.unwrap().mac is Some(_), true)
      assert_eq(full.thumbnail.unwrap().raw_stream.data, b"TH")
      assert_eq(full.collection_item.unwrap().source_object_id == oid(12), true)
      assert_eq(full.encrypted_payload.unwrap().raw_dict.length(), 1)
    }
    _ => fail("expected full file specification")
  }
}

///|
test "embedded file parser rejects malformed stream shape and checksum" {
  let document = file_spec_test_doc()
  let bad_dict : @objects.PdfDictionary = Map::new()
  bad_dict[file_spec_test_name(b"Type")] = @objects.PdfObject::Name(
    file_spec_test_name(b"EmbeddedFile"),
  )
  let params : @objects.PdfDictionary = Map::new()
  params[file_spec_test_name(b"CheckSum")] = @objects.PdfObject::String(
    b"short",
  )
  bad_dict[file_spec_test_name(b"Params")] = @objects.PdfObject::Dictionary(
    params,
  )
  let stream = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: bad_dict,
    data: b"DATA",
  })
  let checksum_result : Result[PdfEmbeddedFile, PdfDocumentError] = try? parse_embedded_file_stream(
    document.file,
    file_spec_test_name(b"F"),
    stream,
    None,
  )
  match checksum_result {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("16 bytes"), true)
    _ => fail("expected checksum length rejection")
  }

  let type_dict : @objects.PdfDictionary = Map::new()
  type_dict[file_spec_test_name(b"Type")] = @objects.PdfObject::Name(
    file_spec_test_name(b"NotEmbedded"),
  )
  let bad_type = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: type_dict,
    data: b"",
  })
  let type_result : Result[PdfEmbeddedFile, PdfDocumentError] = try? parse_embedded_file_stream(
    document.file,
    file_spec_test_name(b"F"),
    bad_type,
    None,
  )
  match type_result {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("invalid value"), true)
    _ => fail("expected embedded stream Type rejection")
  }
}
