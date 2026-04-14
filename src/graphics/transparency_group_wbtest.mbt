///|
test "Transparency group parser separates non-transparency group metadata" {
  let stream = form_stream_with_group(pdf_name(b"Reference"), b"")
  let form = validate_form_xobject(Some(pdf_name(b"Fm")), stream, 20L)
  match form.group {
    Some(group) => {
      assert_eq(group.subtype == Some(pdf_name(b"Reference")), true)
      assert_eq(group.transparency is None, true)
    }
    None => fail("expected group metadata")
  }
}

///|
test "Transparency group validates colour spaces and page defaults" {
  let group : @objects.PdfDictionary = Map::new()
  group[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"Group"))
  group[pdf_name(b"S")] = @objects.PdfObject::Name(pdf_name(b"Transparency"))
  group[pdf_name(b"CS")] = @objects.PdfObject::Name(pdf_name(b"DeviceRGB"))
  let parsed = parse_transparency_group_dictionary(
    group,
    TransparencyGroupContext::FormTransparencyGroup,
    21L,
  )
  assert_eq(parsed.blending_colour_space is Some(_), true)
  assert_eq(parsed.isolated, false)
  assert_eq(parsed.knockout, false)

  group[pdf_name(b"I")] = @objects.PdfObject::Boolean(false)
  group[pdf_name(b"K")] = @objects.PdfObject::Boolean(true)
  let page = parse_transparency_group_dictionary(
    group,
    TransparencyGroupContext::PageTransparencyGroup,
    22L,
  )
  assert_eq(page.isolated, true)
  assert_eq(page.knockout, false)

  let invalid : @objects.PdfDictionary = Map::new()
  invalid[pdf_name(b"S")] = @objects.PdfObject::Name(pdf_name(b"Transparency"))
  invalid[pdf_name(b"CS")] = @objects.PdfObject::Name(pdf_name(b"Pattern"))
  let result : Result[TransparencyGroup, PdfGraphicsError] = try? parse_transparency_group_dictionary(
    invalid,
    TransparencyGroupContext::FormTransparencyGroup,
    23L,
  )
  match result {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 23L)
      assert_eq(reason.contains("CS"), true)
    }
    _ => fail("expected invalid transparency group colour space")
  }
}

///|
fn form_stream_with_group(
  subtype : @objects.PdfName,
  data : Bytes,
) -> @objects.PdfStream {
  let group : @objects.PdfDictionary = Map::new()
  group[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"Group"))
  group[pdf_name(b"S")] = @objects.PdfObject::Name(subtype)
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"XObject"))
  dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"Form"))
  dict[pdf_name(b"BBox")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(10L),
  ])
  dict[pdf_name(b"Group")] = @objects.PdfObject::Dictionary(group)
  @objects.PdfStream::{ dict, data }
}
