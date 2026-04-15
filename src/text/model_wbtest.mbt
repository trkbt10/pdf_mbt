///|
test "text resources summarize direct content font and extgstate dictionaries" {
  let font_dict : @objects.PdfDictionary = Map::new()
  font_dict[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Dictionary(
    Map::new(),
  )
  let ext_dict : @objects.PdfDictionary = Map::new()
  ext_dict[@objects.PdfName::new(b"GS1")] = @objects.PdfObject::Dictionary(
    Map::new(),
  )
  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    font_dict,
  )
  resources_dict[@objects.PdfName::new(b"ExtGState")] = @objects.PdfObject::Dictionary(
    ext_dict,
  )
  let resources = TextResources::from_content_resources(
    @content.ContentResources::from_dictionary(resources_dict),
    0L,
  )
  assert_eq(resources.fonts.contains(@objects.PdfName::new(b"F1")), true)
  assert_eq(
    resources.ext_g_states.contains(@objects.PdfName::new(b"GS1")),
    true,
  )
}

///|
test "text program summary preserves empty strings and span mappings" {
  let source = TextSourceString::{
    bytes: b"",
    operator_offset: 7L,
    group_index: 0,
  }
  let span = TextSpan::{
    offset: 7L,
    font_name: Some(@objects.PdfName::new(b"F1")),
    text: "fi",
    mappings: [
      UnicodeMapping::Unicode("fi"),
      UnicodeMapping::Unknown(
        b"x",
        GlyphIdentifier::GlyphName(@objects.PdfName::new(b"x")),
        MissingUnicode,
      ),
    ],
    source_bytes: b"",
    text_matrix: TextMatrix::identity(),
  }
  let program = TextProgram::{
    events: [TextEvent::EmptyString(source)],
    spans: [span],
    final_state: TextState::initial(),
  }
  assert_eq(program.events.length(), 1)
  assert_eq(program.spans[0].text, "fi")
  match program.events[0] {
    EmptyString(value) => assert_eq(value.bytes, b"")
    _ => fail("expected empty string event")
  }
}

///|
test "glyph metrics resolve explicit and default widths" {
  let widths : Map[Int, Double] = Map::new()
  widths[65] = 600.0
  let explicit = GlyphMetrics::resolve_width(
    65,
    widths,
    Some(250.0),
    GlyphWidthSource::FontDescriptorMissingWidth,
  )
  assert_eq(explicit.horizontal_displacement, 600.0)
  assert_eq(explicit.width_source == GlyphWidthSource::FontDictionary, true)

  let missing = GlyphMetrics::resolve_width(
    90,
    widths,
    Some(250.0),
    GlyphWidthSource::FontDescriptorMissingWidth,
  )
  assert_eq(missing.horizontal_displacement, 250.0)
  assert_eq(
    missing.width_source == GlyphWidthSource::FontDescriptorMissingWidth,
    true,
  )
}

///|
test "glyph metrics return unknown when no width source applies" {
  let widths : Map[Int, Double] = Map::new()
  let metrics = GlyphMetrics::resolve_width(
    5,
    widths,
    None,
    GlyphWidthSource::CIDDefaultWidth,
  )
  assert_eq(metrics.horizontal_displacement, 0.0)
  assert_eq(metrics.width_source == GlyphWidthSource::UnknownWidth, true)
}
