///|
test "interpret text applies simple font encoding ToUnicode and advances matrix" {
  let font = simple_font_with_to_unicode()
  let font_resources : @objects.PdfDictionary = Map::new()
  font_resources[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Dictionary(
    font,
  )
  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    font_resources,
  )
  let resources = TextResources::from_content_resources(
    @content.ContentResources::from_dictionary(resources_dict),
    0L,
  )
  let content = @content.parse_decoded_content(
    b"BT /F1 10 Tf 10 20 Td (AB) Tj ET",
    resources.content_resources,
  )

  let program = interpret_text(content, resources, TextInitialState::default())
  assert_eq(program.spans.length(), 1)
  assert_eq(program.spans[0].text, "XY")
  assert_eq(program.events.length(), 5)
  assert_eq(
    program.final_state.font_name == Some(@objects.PdfName::new(b"F1")),
    true,
  )
  match program.events[2] {
    GlyphShown(event) => {
      assert_eq(event.text_matrix.e, 10.0)
      assert_eq(event.glyph.source_code, 65)
    }
    _ => fail("expected first glyph event")
  }
  match program.events[3] {
    GlyphShown(event) => assert_eq(event.text_matrix.e, 16.0)
    _ => fail("expected second glyph event")
  }
}

///|
test "interpret TJ applies numeric adjustment between source strings" {
  let font = simple_font_with_to_unicode()
  let font_resources : @objects.PdfDictionary = Map::new()
  font_resources[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Dictionary(
    font,
  )
  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    font_resources,
  )
  let resources = TextResources::from_content_resources(
    @content.ContentResources::from_dictionary(resources_dict),
    0L,
  )
  let content = @content.parse_decoded_content(
    b"BT /F1 10 Tf 0 0 Td [(A) 120 (B)] TJ ET",
    resources.content_resources,
  )

  let program = interpret_text(content, resources, TextInitialState::default())
  assert_eq(program.spans.length(), 2)
  match program.events[4] {
    GlyphShown(event) => assert_eq(event.text_matrix.e, 4.8)
    _ => fail("expected adjusted glyph event")
  }
}

///|
test "interpret text uses Standard 14 Helvetica widths when Widths is absent" {
  let font : @objects.PdfDictionary = Map::new()
  font[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Type1"),
  )
  font[@objects.PdfName::new(b"BaseFont")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Helvetica"),
  )
  let font_resources : @objects.PdfDictionary = Map::new()
  font_resources[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Dictionary(
    font,
  )
  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    font_resources,
  )
  let resources = TextResources::from_content_resources(
    @content.ContentResources::from_dictionary(resources_dict),
    0L,
  )
  let content = @content.parse_decoded_content(
    b"BT /F1 10 Tf 10 20 Td (AV) Tj ET",
    resources.content_resources,
  )

  let program = interpret_text(content, resources, TextInitialState::default())
  match program.events[2] {
    GlyphShown(event) =>
      assert_eq(
        event.glyph.metrics.width_source == GlyphWidthSource::Standard14Fallback,
        true,
      )
    _ => fail("expected first glyph event")
  }
  match program.events[3] {
    GlyphShown(event) => assert_eq(event.text_matrix.e, 16.67)
    _ => fail("expected second glyph event")
  }
}

///|
test "interpret text rejects showing outside text object" {
  let resources = TextResources::empty()
  let content = @content.parse_decoded_content(
    b"(A) Tj",
    resources.content_resources,
  )
  let result : Result[TextProgram, PdfTextError] = try? interpret_text(
    content,
    resources,
    TextInitialState::default(),
  )
  match result {
    Err(InvalidTextState(_, reason)) =>
      assert_eq(reason.contains("active text object"), true)
    _ => fail("expected text state error")
  }
}

///|
fn simple_font_with_to_unicode() -> @objects.PdfDictionary {
  let font : @objects.PdfDictionary = Map::new()
  font[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Type1"),
  )
  font[@objects.PdfName::new(b"BaseFont")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Helvetica"),
  )
  font[@objects.PdfName::new(b"FirstChar")] = @objects.PdfObject::Integer(65L)
  font[@objects.PdfName::new(b"Widths")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(600L),
    @objects.PdfObject::Integer(500L),
  ])
  let to_unicode_dict : @objects.PdfDictionary = Map::new()
  let to_unicode = @objects.PdfStream::{
    dict: to_unicode_dict,
    data: b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n2 beginbfchar\n<41> <0058>\n<42> <0059>\nendbfchar",
  }
  font[@objects.PdfName::new(b"ToUnicode")] = @objects.PdfObject::Stream(
    to_unicode,
  )
  font
}
