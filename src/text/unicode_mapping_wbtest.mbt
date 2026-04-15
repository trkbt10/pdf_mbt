///|
test "glyph names map to unicode through known names and glyph-list patterns" {
  assert_eq(glyph_name_to_unicode(@objects.PdfName::new(b"A")), Some("A"))
  assert_eq(glyph_name_to_unicode(@objects.PdfName::new(b"Euro")), Some("€"))
  assert_eq(
    glyph_name_to_unicode(@objects.PdfName::new(b"uni00410042")),
    Some("AB"),
  )
  assert_eq(
    glyph_name_to_unicode(@objects.PdfName::new(b"u1F600")),
    Some("😀"),
  )
  assert_eq(glyph_name_to_unicode(@objects.PdfName::new(b".notdef")), None)
}

///|
test "glyph-name mapping preserves unknown glyph identity" {
  let mapping = map_glyph_name_to_unicode(
    b"\x01",
    GlyphIdentifier::GlyphName(@objects.PdfName::new(b"unknownGlyph")),
    GlyphFallback::MissingUnicode,
  )
  match mapping {
    Unknown(bytes, glyph, fallback) => {
      assert_eq(bytes, b"\x01")
      assert_eq(
        glyph ==
        GlyphIdentifier::GlyphName(@objects.PdfName::new(b"unknownGlyph")),
        true,
      )
      assert_eq(fallback == GlyphFallback::MissingUnicode, true)
    }
    _ => fail("expected unknown mapping")
  }
}

///|
test "utf16be decoder accepts bmp text and surrogate pairs" {
  let text = decode_utf16be_text(
    b"\x00A\x00B\xd8=\xde\x00",
    TextErrorContext::at(4L),
  )
  assert_eq(text, "AB😀")
}

///|
test "utf16be decoder rejects malformed surrogate sequences" {
  let result : Result[String, PdfTextError] = try? decode_utf16be_text(
    b"\xd8=\x00A",
    TextErrorContext::at(7L),
  )
  match result {
    Err(UnicodeConversion(context, reason)) => {
      assert_eq(context.offset, 7L)
      assert_eq(reason.contains("low surrogate"), true)
    }
    _ => fail("expected unicode conversion error")
  }
}
