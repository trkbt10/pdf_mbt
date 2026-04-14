///|
test "procedure set validator accepts predefined names and rejects unknown" {
  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[pdf_name(b"ProcSet")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(pdf_name(b"PDF")),
    @objects.PdfObject::Name(pdf_name(b"Text")),
    @objects.PdfObject::Name(pdf_name(b"ImageB")),
    @objects.PdfObject::Name(pdf_name(b"ImageC")),
    @objects.PdfObject::Name(pdf_name(b"ImageI")),
  ])
  let names = parse_proc_sets(
    @content.ContentResources::from_dictionary(resources_dict),
  )
  assert_eq(names.length(), 5)
  assert_eq(names[0] == PdfProcedureSetName::PDF, true)
  assert_eq(names[4] == PdfProcedureSetName::ImageI, true)

  let bad : @objects.PdfDictionary = Map::new()
  bad[pdf_name(b"ProcSet")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(pdf_name(b"Custom")),
  ])
  let result : Result[Array[PdfProcedureSetName], PdfInterchangeError] = try? parse_proc_sets(
    @content.ContentResources::from_dictionary(bad),
  )
  match result {
    Err(InvalidProcedureSet(reason)) =>
      assert_eq(reason.contains("Custom"), true)
    _ => fail("expected unknown ProcSet failure")
  }
}

///|
test "marked content analyzer normalizes points sequences and named properties" {
  let properties : @objects.PdfDictionary = Map::new()
  let property_dict : @objects.PdfDictionary = Map::new()
  property_dict[pdf_name(b"MCID")] = @objects.PdfObject::Integer(7L)
  properties[pdf_name(b"P1")] = @objects.PdfObject::Dictionary(property_dict)
  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[pdf_name(b"Properties")] = @objects.PdfObject::Dictionary(
    properties,
  )
  let stream = @content.parse_decoded_content(
    b"/Artifact MP /Span /P1 BDC /Point null DP EMC",
    @content.ContentResources::from_dictionary(resources_dict),
  )
  let report = analyze_marked_content(stream)

  assert_eq(report.points.length(), 2)
  assert_eq(report.sequences.length(), 1)
  match report.sequences[0].property {
    Some(MarkedContentProperty::Named(name, _)) =>
      assert_eq(name == pdf_name(b"P1"), true)
    _ => fail("expected named property")
  }
  match report.points[1].property {
    Some(MarkedContentProperty::Null) => ()
    _ => fail("expected null point property")
  }
}

///|
test "marked content analyzer rejects missing properties and BT crossing" {
  let missing_stream = @content.parse_decoded_content(
    b"/Span /Missing BDC EMC",
    @content.ContentResources::empty(),
  )
  let missing : Result[MarkedContentReport, PdfInterchangeError] = try? analyze_marked_content(
    missing_stream,
  )
  match missing {
    Err(InvalidMarkedContent(_, reason)) =>
      assert_eq(reason.contains("Missing"), true)
    _ => fail("expected missing property failure")
  }

  let crossing_stream = @content.parse_decoded_content(
    b"BT /Span BMC ET EMC",
    @content.ContentResources::empty(),
  )
  let crossing : Result[MarkedContentReport, PdfInterchangeError] = try? analyze_marked_content(
    crossing_stream,
  )
  match crossing {
    Err(InvalidMarkedContent(_, reason)) =>
      assert_eq(reason.contains("crosses"), true)
    _ => fail("expected text crossing failure")
  }
}
