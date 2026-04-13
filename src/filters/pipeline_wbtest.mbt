///|
test "normalize_pipeline aligns decode parms with named filters" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"Crypt")),
    @objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode")),
  ])
  let flate_params : @objects.PdfDictionary = Map::new()
  flate_params[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(
    12L,
  )
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Array([
    @objects.PdfObject::Null,
    @objects.PdfObject::Dictionary(flate_params),
  ])

  let pipeline = normalize_pipeline(dict)
  assert_eq(pipeline.length(), 2)

  match pipeline[0].name {
    Unsupported(name) => assert_eq(name, "Crypt")
    _ => fail("expected first normalized filter to preserve name")
  }
  assert_eq(pipeline[0].params.raw is None, true)

  match pipeline[1].name {
    FlateDecode => ()
    _ => fail("expected second normalized filter to preserve name")
  }
  match pipeline[1].params.raw {
    Some(params) =>
      assert_eq(
        params.get(@objects.PdfName::new(b"Predictor")) ==
        Some(@objects.PdfObject::Integer(12L)),
        true,
      )
    None => fail("expected second filter params to be present")
  }
}

///|
test "normalize_pipeline rejects decode parms arrays with mismatched length" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"Crypt")),
    @objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode")),
  ])
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Array([
    @objects.PdfObject::Null,
  ])

  let result : Result[Array[FilterSpec], PdfFilterError] = try? normalize_pipeline(
    dict,
  )
  match result {
    Err(InvalidFilterSpec(reason)) =>
      assert_eq(reason.contains("DecodeParms"), true)
    _ => fail("expected mismatched decode parms to be rejected")
  }
}
