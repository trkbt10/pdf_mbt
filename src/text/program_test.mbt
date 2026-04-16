///|
test "public text program values can be constructed without reader integration" {
  let source = TextSourceString::{
    bytes: b"A",
    operator_offset: 11L,
    group_index: 0,
  }
  let metrics = GlyphMetrics::{
    horizontal_displacement: 600.0,
    vertical_displacement_x: 0.0,
    vertical_displacement_y: 0.0,
    vertical_origin_x: 0.0,
    vertical_origin_y: 0.0,
    width_source: GlyphWidthSource::FontDictionary,
  }
  let glyph = DecodedGlyph::{
    source_bytes: b"A",
    source_code: 65,
    glyph: GlyphIdentifier::GlyphName(@objects.PdfName::new(b"A")),
    metrics,
    word_spacing_eligible: false,
    fallback: GlyphFallback::NoFallback,
  }
  let event = TextEvent::GlyphShown(TextGlyphEvent::{
    offset: 11L,
    source,
    glyph,
    unicode: UnicodeMapping::Unicode("A"),
    text_matrix: TextMatrix::identity(),
    rendering_matrix: TextRenderingMatrix::from_text_state(
      TextMatrix::identity(),
      12.0,
      1.0,
      0.0,
      TextMatrix::identity(),
    ),
    paint: TextPaintIntent::from_rendering_mode(TextRenderingMode::Fill, false),
  })
  let span = TextSpan::{
    offset: 11L,
    font_name: Some(@objects.PdfName::new(b"F1")),
    font_size: 12.0,
    text: "A",
    mappings: [UnicodeMapping::Unicode("A")],
    source_bytes: b"A",
    text_matrix: TextMatrix::identity(),
  }
  let program = TextProgram::{
    events: [event],
    spans: [span],
    final_state: TextState::initial().with_font(
      @objects.PdfName::new(b"F1"),
      12.0,
    ),
  }

  assert_eq(program.events.length(), 1)
  assert_eq(program.spans[0].text, "A")
  assert_eq(program.final_state.font_size, Some(12.0))
}
