///|
test "TrueType fallback keeps ToUnicode and uses FontFile2 metrics" {
  let font = truetype_font_with_invalid_encoding()
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
    b"BT /F1 10 Tf (A) Tj ET",
    resources.content_resources,
  )

  let program = interpret_text(content, resources, TextInitialState::default())
  assert_eq(program.spans.length(), 1)
  assert_eq(program.spans[0].text, "Z")
  match program.events[2] {
    GlyphShown(event) => {
      assert_eq(event.glyph.metrics.horizontal_displacement, 600.0)
      assert_eq(
        event.glyph.metrics.width_source == GlyphWidthSource::FontDictionary,
        true,
      )
    }
    _ => fail("expected glyph event")
  }
}

///|
fn truetype_font_with_invalid_encoding() -> @objects.PdfDictionary {
  let font : @objects.PdfDictionary = Map::new()
  font[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"TrueType"),
  )
  font[@objects.PdfName::new(b"BaseFont")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"TestCmap12"),
  )
  let encoding : @objects.PdfDictionary = Map::new()
  encoding[@objects.PdfName::new(b"BaseEncoding")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"NonStandardEncoding"),
  )
  font[@objects.PdfName::new(b"Encoding")] = @objects.PdfObject::Dictionary(
    encoding,
  )
  let descriptor : @objects.PdfDictionary = Map::new()
  descriptor[@objects.PdfName::new(b"FontFile2")] = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: Map::new(),
    data: synthetic_truetype_font(),
  })
  font[@objects.PdfName::new(b"FontDescriptor")] = @objects.PdfObject::Dictionary(
    descriptor,
  )
  font[@objects.PdfName::new(b"ToUnicode")] = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: Map::new(),
    data: b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n1 beginbfchar\n<41> <005A>\nendbfchar",
  })
  font
}

///|
fn synthetic_truetype_font() -> Bytes {
  try! @fs.read_file_to_bytes(
    ".mooncakes/mizchi/font/fixtures/minimal-cmap12.ttf",
  )
}
