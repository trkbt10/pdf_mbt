///|
pub fn glyph_name_to_unicode(name : @objects.PdfName) -> String? {
  match known_glyph_unicode(name) {
    Some(text) => Some(text)
    None => glyph_name_unicode_pattern(name.bytes)
  }
}

///|
pub fn map_glyph_name_to_unicode(
  source_bytes : Bytes,
  glyph : GlyphIdentifier,
  fallback : GlyphFallback,
) -> UnicodeMapping {
  match glyph {
    GlyphName(name) =>
      match glyph_name_to_unicode(name) {
        Some(text) => UnicodeMapping::Unicode(text)
        None => UnicodeMapping::Unknown(source_bytes, glyph, fallback)
      }
    _ => UnicodeMapping::Unknown(source_bytes, glyph, fallback)
  }
}

///|
pub fn decode_utf16be_text(
  bytes : Bytes,
  context : TextErrorContext,
) -> String raise PdfTextError {
  if bytes.length() % 2 != 0 {
    raise PdfTextError::UnicodeConversion(
      context, "UTF-16BE text must contain an even number of bytes",
    )
  }
  let builder = StringBuilder::new(size_hint=bytes.length() / 2)
  let mut index = 0
  while index < bytes.length() {
    let unit = read_u16be(bytes, index)
    if unit >= 0xd800 && unit <= 0xdbff {
      if index + 3 >= bytes.length() {
        raise PdfTextError::UnicodeConversion(
          context, "UTF-16BE high surrogate must be followed by a low surrogate",
        )
      }
      let low = read_u16be(bytes, index + 2)
      if low < 0xdc00 || low > 0xdfff {
        raise PdfTextError::UnicodeConversion(
          context, "UTF-16BE high surrogate must be followed by a low surrogate",
        )
      }
      let codepoint = 0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00)
      write_codepoint(builder, codepoint, context)
      index += 4
    } else if unit >= 0xdc00 && unit <= 0xdfff {
      raise PdfTextError::UnicodeConversion(
        context, "UTF-16BE low surrogate cannot appear without a high surrogate",
      )
    } else {
      write_codepoint(builder, unit, context)
      index += 2
    }
  }
  builder.to_string()
}

///|
fn write_codepoint(
  builder : StringBuilder,
  codepoint : Int,
  context : TextErrorContext,
) -> Unit raise PdfTextError {
  match codepoint.to_char() {
    Some(char) => builder.write_char(char)
    None =>
      raise PdfTextError::UnicodeConversion(
        context, "invalid Unicode scalar value",
      )
  }
}

///|
fn read_u16be(bytes : Bytes, index : Int) -> Int {
  bytes[index].to_int() * 256 + bytes[index + 1].to_int()
}

///|
fn known_glyph_unicode(name : @objects.PdfName) -> String? {
  if name == @objects.PdfName::new(b".notdef") {
    None
  } else if name == @objects.PdfName::new(b"space") {
    Some(" ")
  } else if name == @objects.PdfName::new(b"exclam") {
    Some("!")
  } else if name == @objects.PdfName::new(b"quotedbl") {
    Some("\"")
  } else if name == @objects.PdfName::new(b"numbersign") {
    Some("#")
  } else if name == @objects.PdfName::new(b"dollar") {
    Some("$")
  } else if name == @objects.PdfName::new(b"percent") {
    Some("%")
  } else if name == @objects.PdfName::new(b"ampersand") {
    Some("&")
  } else if name == @objects.PdfName::new(b"quotesingle") ||
    name == @objects.PdfName::new(b"quoteright") {
    Some("'")
  } else if name == @objects.PdfName::new(b"quoteleft") {
    Some("'")
  } else if name == @objects.PdfName::new(b"parenleft") {
    Some("(")
  } else if name == @objects.PdfName::new(b"parenright") {
    Some(")")
  } else if name == @objects.PdfName::new(b"asterisk") {
    Some("*")
  } else if name == @objects.PdfName::new(b"plus") {
    Some("+")
  } else if name == @objects.PdfName::new(b"comma") {
    Some(",")
  } else if name == @objects.PdfName::new(b"hyphen") {
    Some("-")
  } else if name == @objects.PdfName::new(b"period") {
    Some(".")
  } else if name == @objects.PdfName::new(b"slash") {
    Some("/")
  } else if name == @objects.PdfName::new(b"zero") {
    Some("0")
  } else if name == @objects.PdfName::new(b"one") {
    Some("1")
  } else if name == @objects.PdfName::new(b"two") {
    Some("2")
  } else if name == @objects.PdfName::new(b"three") {
    Some("3")
  } else if name == @objects.PdfName::new(b"four") {
    Some("4")
  } else if name == @objects.PdfName::new(b"five") {
    Some("5")
  } else if name == @objects.PdfName::new(b"six") {
    Some("6")
  } else if name == @objects.PdfName::new(b"seven") {
    Some("7")
  } else if name == @objects.PdfName::new(b"eight") {
    Some("8")
  } else if name == @objects.PdfName::new(b"nine") {
    Some("9")
  } else if name == @objects.PdfName::new(b"colon") {
    Some(":")
  } else if name == @objects.PdfName::new(b"semicolon") {
    Some(";")
  } else if name == @objects.PdfName::new(b"less") {
    Some("<")
  } else if name == @objects.PdfName::new(b"equal") {
    Some("=")
  } else if name == @objects.PdfName::new(b"greater") {
    Some(">")
  } else if name == @objects.PdfName::new(b"question") {
    Some("?")
  } else if name == @objects.PdfName::new(b"at") {
    Some("@")
  } else if name.bytes.length() == 1 {
    let code = name.bytes[0].to_int()
    if (code >= b'A'.to_int() && code <= b'Z'.to_int()) ||
      (code >= b'a'.to_int() && code <= b'z'.to_int()) {
      Some(String::from_array([name.bytes[0].to_char()]))
    } else {
      None
    }
  } else if name == @objects.PdfName::new(b"bracketleft") {
    Some("[")
  } else if name == @objects.PdfName::new(b"backslash") {
    Some("\\")
  } else if name == @objects.PdfName::new(b"bracketright") {
    Some("]")
  } else if name == @objects.PdfName::new(b"asciicircum") {
    Some("^")
  } else if name == @objects.PdfName::new(b"underscore") {
    Some("_")
  } else if name == @objects.PdfName::new(b"grave") {
    Some("`")
  } else if name == @objects.PdfName::new(b"braceleft") {
    Some("{")
  } else if name == @objects.PdfName::new(b"bar") {
    Some("|")
  } else if name == @objects.PdfName::new(b"braceright") {
    Some("}")
  } else if name == @objects.PdfName::new(b"asciitilde") {
    Some("~")
  } else if name == @objects.PdfName::new(b"fi") {
    Some("fi")
  } else if name == @objects.PdfName::new(b"fl") {
    Some("fl")
  } else if name == @objects.PdfName::new(b"Euro") {
    Some("€")
  } else if name == @objects.PdfName::new(b"bullet") {
    Some("•")
  } else if name == @objects.PdfName::new(b"endash") {
    Some("–")
  } else if name == @objects.PdfName::new(b"emdash") {
    Some("—")
  } else if name == @objects.PdfName::new(b"ellipsis") {
    Some("…")
  } else if name == @objects.PdfName::new(b"trademark") {
    Some("™")
  } else {
    None
  }
}

///|
fn glyph_name_unicode_pattern(bytes : Bytes) -> String? {
  if bytes.length() >= 7 &&
    bytes[0] == b'u' &&
    bytes[1] == b'n' &&
    bytes[2] == b'i' &&
    bytes.length() % 4 == 3 {
    let builder = StringBuilder::new(size_hint=(bytes.length() - 3) / 4)
    let mut index = 3
    while index < bytes.length() {
      match parse_hex_codepoint(bytes, index, 4) {
        Some(codepoint) =>
          match codepoint.to_char() {
            Some(char) => builder.write_char(char)
            None => return None
          }
        None => return None
      }
      index += 4
    }
    Some(builder.to_string())
  } else if bytes.length() >= 5 && bytes[0] == b'u' {
    match parse_hex_codepoint(bytes, 1, bytes.length() - 1) {
      Some(codepoint) =>
        match codepoint.to_char() {
          Some(char) => Some(String::from_array([char]))
          None => None
        }
      None => None
    }
  } else {
    None
  }
}

///|
fn parse_hex_codepoint(bytes : Bytes, start : Int, length : Int) -> Int? {
  if length < 4 || length > 6 || start + length > bytes.length() {
    return None
  }
  let mut value = 0
  for index in start..<(start + length) {
    match @filters.hex_digit_value(bytes[index]) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  Some(value)
}
