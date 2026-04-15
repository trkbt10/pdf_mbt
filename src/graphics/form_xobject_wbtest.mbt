///|
test "FormXObject transformed_bbox returns Matrix-mapped bounds tuple" {
  let stream = form_xobject_test_stream(false)
  stream.dict[@objects.PdfName::new(b"Matrix")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(2L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(3L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(20L),
  ])
  let form = validate_form_xobject(None, stream, 50L)

  assert_eq(form.transformed_bbox(), (10.0, 20.0, 30.0, 50.0))
}

///|
test "FormXObject detects transparency Group metadata" {
  let transparent = validate_form_xobject(
    None,
    form_xobject_test_stream(true),
    51L,
  )
  let plain = validate_form_xobject(None, form_xobject_test_stream(false), 52L)

  assert_eq(transparent.has_transparency_group(), true)
  assert_eq(plain.has_transparency_group(), false)
}

///|
fn form_xobject_test_stream(transparent_group : Bool) -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"XObject"),
  )
  dict[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Form"),
  )
  dict[@objects.PdfName::new(b"BBox")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(10L),
  ])
  if transparent_group {
    dict[@objects.PdfName::new(b"Group")] = @objects.PdfObject::Dictionary(
      form_xobject_transparency_group_dict(),
    )
  }
  @objects.PdfStream::{ dict, data: b"" }
}

///|
fn form_xobject_transparency_group_dict() -> @objects.PdfDictionary {
  let group : @objects.PdfDictionary = Map::new()
  group[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Group"),
  )
  group[@objects.PdfName::new(b"S")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Transparency"),
  )
  group
}
