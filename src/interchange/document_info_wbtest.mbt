///|
test "document info preserves known byte strings and trapped default" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Title")] = @objects.PdfObject::String(b"title")
  dict[pdf_name(b"CreationDate")] = @objects.PdfObject::String(b"D:20260414")
  let info = validate_document_info_dictionary(dict)

  assert_eq(info.title, Some(b"title"))
  assert_eq(info.creation_date, Some(b"D:20260414"))
  assert_eq(info.trapped == PdfTrappedStatus::Unknown, true)
  assert_eq(info.raw_dict == dict, true)
}

///|
test "document info validates trapped names and known value shapes" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Trapped")] = @objects.PdfObject::Name(pdf_name(b"True"))
  assert_eq(
    validate_document_info_dictionary(dict).trapped == PdfTrappedStatus::True,
    true,
  )

  let bad_title : @objects.PdfDictionary = Map::new()
  bad_title[pdf_name(b"Title")] = @objects.PdfObject::Name(pdf_name(b"Bad"))
  let title_result : Result[PdfDocumentInfo, PdfInterchangeError] = try? validate_document_info_dictionary(
    bad_title,
  )
  match title_result {
    Err(InvalidDocumentInfo(_, reason)) =>
      assert_eq(reason.contains("Title"), true)
    _ => fail("expected invalid Title shape")
  }

  let bad_trapped : @objects.PdfDictionary = Map::new()
  bad_trapped[pdf_name(b"Trapped")] = @objects.PdfObject::Name(
    pdf_name(b"Maybe"),
  )
  let trapped_result : Result[PdfDocumentInfo, PdfInterchangeError] = try? validate_document_info_dictionary(
    bad_trapped,
  )
  match trapped_result {
    Err(InvalidDocumentInfo(_, reason)) =>
      assert_eq(reason.contains("Trapped"), true)
    _ => fail("expected invalid Trapped name")
  }
}

///|
test "metadata diagnostics compare exact date bytes when supplied" {
  let info_dict : @objects.PdfDictionary = Map::new()
  info_dict[pdf_name(b"CreationDate")] = @objects.PdfObject::String(b"D:1")
  info_dict[pdf_name(b"ModDate")] = @objects.PdfObject::String(b"D:2")
  let info = validate_document_info_dictionary(info_dict)

  let same = metadata_source_diagnostics(
    None,
    Some(info),
    metadata_creation_date=Some(b"D:1"),
    metadata_mod_date=Some(b"D:3"),
  )
  assert_eq(same.creation_date == PdfMetadataDateComparison::Equivalent, true)
  assert_eq(same.mod_date == PdfMetadataDateComparison::Different, true)

  let unsupported = metadata_source_diagnostics(None, Some(info))
  assert_eq(
    unsupported.creation_date == PdfMetadataDateComparison::OnlyInfo,
    true,
  )
}
