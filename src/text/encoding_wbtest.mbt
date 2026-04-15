///|
test "named simple encodings resolve base glyph names and notdef fallback" {
  let standard = resolve_named_encoding(
    @objects.PdfName::new(b"StandardEncoding"),
    10L,
  )
  assert_eq(
    standard.glyph_name_for_code(65) == @objects.PdfName::new(b"A"),
    true,
  )
  assert_eq(
    standard.glyph_name_for_code(39) == @objects.PdfName::new(b"quoteright"),
    true,
  )
  assert_eq(
    standard.glyph_name_for_code(0) == @objects.PdfName::new(b".notdef"),
    true,
  )

  let win_ansi = resolve_named_encoding(
    @objects.PdfName::new(b"WinAnsiEncoding"),
    10L,
  )
  assert_eq(
    win_ansi.glyph_name_for_code(128) == @objects.PdfName::new(b"Euro"),
    true,
  )
}

///|
test "encoding dictionary applies differences in order" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"BaseEncoding")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"WinAnsiEncoding"),
  )
  dict[@objects.PdfName::new(b"Differences")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(65L),
    @objects.PdfObject::Name(@objects.PdfName::new(b"Alpha")),
    @objects.PdfObject::Name(@objects.PdfName::new(b"Beta")),
    @objects.PdfObject::Integer(128L),
    @objects.PdfObject::Name(@objects.PdfName::new(b"bullet")),
  ])

  let encoding = parse_simple_encoding(
    Some(@objects.PdfObject::Dictionary(dict)),
    22L,
  )
  assert_eq(
    encoding.glyph_name_for_code(65) == @objects.PdfName::new(b"Alpha"),
    true,
  )
  assert_eq(
    encoding.glyph_name_for_code(66) == @objects.PdfName::new(b"Beta"),
    true,
  )
  assert_eq(
    encoding.glyph_name_for_code(128) == @objects.PdfName::new(b"bullet"),
    true,
  )
  assert_eq(encoding.differences.length(), 3)
}

///|
test "encoding dictionary rejects malformed differences" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Differences")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"A")),
  ])

  let result : Result[SimpleEncoding, PdfTextError] = try? parse_simple_encoding(
    Some(@objects.PdfObject::Dictionary(dict)),
    30L,
  )
  match result {
    Err(InvalidFont(context, reason)) => {
      assert_eq(context.offset, 30L)
      assert_eq(reason.contains("start with a code"), true)
    }
    _ => fail("expected invalid font error")
  }
}
