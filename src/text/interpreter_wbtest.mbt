///|
test "interpreter caches runtime font across repeated text strings" {
  let resources = runtime_font_cache_test_resources()
  let content = @content.parse_decoded_content(
    b"BT /F1 10 Tf [(A) (B) (A)] TJ ET",
    resources.content_resources,
  )

  text_interpret_phase_reset()
  let program = interpret_text(content, resources, TextInitialState::default())
  text_interpret_phase_disable()

  assert_eq(program.spans.length(), 3)
  assert_eq(program.spans[0].text, "X")
  assert_eq(program.spans[1].text, "Y")
  assert_eq(program.spans[2].text, "X")
  assert_eq(text_interpret_font_loads.val, 1)
}

///|
test "interpreter caches each selected runtime font once" {
  let resources = runtime_font_cache_two_font_resources()
  let content = @content.parse_decoded_content(
    b"BT /F1 10 Tf (A) Tj /F2 10 Tf (A) Tj /F1 10 Tf (B) Tj ET",
    resources.content_resources,
  )

  text_interpret_phase_reset()
  let program = interpret_text(content, resources, TextInitialState::default())
  text_interpret_phase_disable()

  assert_eq(program.spans.length(), 3)
  assert_eq(program.spans[0].text, "X")
  assert_eq(program.spans[1].text, "Z")
  assert_eq(program.spans[2].text, "Y")
  assert_eq(text_interpret_font_loads.val, 2)
}

///|
fn runtime_font_cache_test_resources() -> TextResources raise {
  let fonts : @objects.PdfDictionary = Map::new()
  fonts[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Dictionary(
    runtime_font_cache_test_font(b"0058", b"0059"),
  )
  let resources : @objects.PdfDictionary = Map::new()
  resources[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    fonts,
  )
  TextResources::from_content_resources(
    @content.ContentResources::from_dictionary(resources),
    0L,
  )
}

///|
fn runtime_font_cache_two_font_resources() -> TextResources raise {
  let fonts : @objects.PdfDictionary = Map::new()
  fonts[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Dictionary(
    runtime_font_cache_test_font(b"0058", b"0059"),
  )
  fonts[@objects.PdfName::new(b"F2")] = @objects.PdfObject::Dictionary(
    runtime_font_cache_test_font(b"005A", b"005B"),
  )
  let resources : @objects.PdfDictionary = Map::new()
  resources[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    fonts,
  )
  TextResources::from_content_resources(
    @content.ContentResources::from_dictionary(resources),
    0L,
  )
}

///|
fn runtime_font_cache_test_font(
  code_65 : Bytes,
  code_66 : Bytes,
) -> @objects.PdfDictionary {
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
  let to_unicode = @objects.PdfStream::{
    dict: Map::new(),
    data: runtime_font_cache_to_unicode_cmap(code_65, code_66),
  }
  font[@objects.PdfName::new(b"ToUnicode")] = @objects.PdfObject::Stream(
    to_unicode,
  )
  font
}

///|
fn runtime_font_cache_to_unicode_cmap(code_65 : Bytes, code_66 : Bytes) -> Bytes {
  if code_65 == b"0058" && code_66 == b"0059" {
    b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n2 beginbfchar\n<41> <0058>\n<42> <0059>\nendbfchar"
  } else {
    b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n2 beginbfchar\n<41> <005A>\n<42> <005B>\nendbfchar"
  }
}
