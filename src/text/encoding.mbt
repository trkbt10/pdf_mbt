///|
pub(all) enum SimpleEncodingName {
  StandardEncoding
  WinAnsiEncoding
  MacRomanEncoding
  MacExpertEncoding
} derive(Eq, Debug)

///|
pub(all) struct SimpleEncoding {
  base : SimpleEncodingName
  differences : Map[Int, @objects.PdfName]
  names : Map[Int, @objects.PdfName]
} derive(Eq, Debug)

///|
pub fn SimpleEncoding::standard() -> SimpleEncoding {
  SimpleEncoding::from_name(StandardEncoding)
}

///|
pub fn SimpleEncoding::from_name(name : SimpleEncodingName) -> SimpleEncoding {
  let names = base_encoding_names(name)
  SimpleEncoding::{ base: name, differences: Map::new(), names }
}

///|
pub fn SimpleEncoding::glyph_name_for_code(
  self : SimpleEncoding,
  code : Int,
) -> @objects.PdfName {
  match self.names.get(code) {
    Some(name) => name
    None => @objects.PdfName::new(b".notdef")
  }
}

///|
pub fn resolve_named_encoding(
  name : @objects.PdfName,
  offset : Int64,
) -> SimpleEncoding raise PdfTextError {
  if name == @objects.PdfName::new(b"StandardEncoding") {
    SimpleEncoding::from_name(StandardEncoding)
  } else if name == @objects.PdfName::new(b"WinAnsiEncoding") {
    SimpleEncoding::from_name(WinAnsiEncoding)
  } else if name == @objects.PdfName::new(b"MacRomanEncoding") {
    SimpleEncoding::from_name(MacRomanEncoding)
  } else if name == @objects.PdfName::new(b"MacExpertEncoding") {
    SimpleEncoding::from_name(MacExpertEncoding)
  } else {
    raise PdfTextError::InvalidFont(
      TextErrorContext::at(offset),
      "unknown simple font encoding " + name.to_text(),
    )
  }
}

///|
pub fn parse_simple_encoding(
  object : @objects.PdfObject?,
  offset : Int64,
) -> SimpleEncoding raise PdfTextError {
  match object {
    None | Some(@objects.PdfObject::Null) => SimpleEncoding::standard()
    Some(@objects.PdfObject::Name(name)) => resolve_named_encoding(name, offset)
    Some(@objects.PdfObject::Dictionary(dict)) =>
      parse_encoding_dictionary(dict, offset)
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "Encoding must be a name or dictionary",
      )
  }
}

///|
fn parse_encoding_dictionary(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> SimpleEncoding raise PdfTextError {
  let base = match dict.get(@objects.PdfName::new(b"BaseEncoding")) {
    Some(@objects.PdfObject::Name(name)) => resolve_named_encoding(name, offset)
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "Encoding BaseEncoding must be a name",
      )
    None => SimpleEncoding::standard()
  }
  let names = base.names.copy()
  let differences : Map[Int, @objects.PdfName] = Map::new()
  match dict.get(@objects.PdfName::new(b"Differences")) {
    None | Some(@objects.PdfObject::Null) => ()
    Some(@objects.PdfObject::Array(values)) =>
      apply_differences(values, names, differences, offset)
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "Encoding Differences must be an array",
      )
  }
  SimpleEncoding::{ base: base.base, differences, names }
}

///|
fn apply_differences(
  values : Array[@objects.PdfObject],
  names : Map[Int, @objects.PdfName],
  differences : Map[Int, @objects.PdfName],
  offset : Int64,
) -> Unit raise PdfTextError {
  let mut current : Int? = None
  for value in values {
    match value {
      @objects.PdfObject::Integer(code) => {
        if code < 0L || code > 255L {
          raise PdfTextError::InvalidFont(
            TextErrorContext::at(offset),
            "Encoding Differences code must be from 0 through 255",
          )
        }
        current = Some(code.to_int())
      }
      @objects.PdfObject::Name(name) =>
        match current {
          None =>
            raise PdfTextError::InvalidFont(
              TextErrorContext::at(offset),
              "Encoding Differences must start with a code",
            )
          Some(code) => {
            if code > 255 {
              raise PdfTextError::InvalidFont(
                TextErrorContext::at(offset),
                "Encoding Differences name ran past code 255",
              )
            }
            names[code] = name
            differences[code] = name
            current = Some(code + 1)
          }
        }
      _ =>
        raise PdfTextError::InvalidFont(
          TextErrorContext::at(offset),
          "Encoding Differences entries must be integers or names",
        )
    }
  }
}

///|
fn base_encoding_names(name : SimpleEncodingName) -> Map[Int, @objects.PdfName] {
  let names : Map[Int, @objects.PdfName] = Map::new()
  for code in 0..<256 {
    names[code] = @objects.PdfName::new(b".notdef")
  }
  install_ascii_glyph_names(names)
  match name {
    StandardEncoding => install_standard_extra_names(names)
    WinAnsiEncoding => install_win_ansi_extra_names(names)
    MacRomanEncoding => install_mac_roman_extra_names(names)
    MacExpertEncoding => install_mac_expert_extra_names(names)
  }
  names
}

///|
fn set_glyph_name(
  names : Map[Int, @objects.PdfName],
  code : Int,
  bytes : Bytes,
) -> Unit {
  names[code] = @objects.PdfName::new(bytes)
}

///|
fn install_ascii_glyph_names(names : Map[Int, @objects.PdfName]) -> Unit {
  set_glyph_name(names, 32, b"space")
  set_glyph_name(names, 33, b"exclam")
  set_glyph_name(names, 34, b"quotedbl")
  set_glyph_name(names, 35, b"numbersign")
  set_glyph_name(names, 36, b"dollar")
  set_glyph_name(names, 37, b"percent")
  set_glyph_name(names, 38, b"ampersand")
  set_glyph_name(names, 39, b"quotesingle")
  set_glyph_name(names, 40, b"parenleft")
  set_glyph_name(names, 41, b"parenright")
  set_glyph_name(names, 42, b"asterisk")
  set_glyph_name(names, 43, b"plus")
  set_glyph_name(names, 44, b"comma")
  set_glyph_name(names, 45, b"hyphen")
  set_glyph_name(names, 46, b"period")
  set_glyph_name(names, 47, b"slash")
  set_glyph_name(names, 48, b"zero")
  set_glyph_name(names, 49, b"one")
  set_glyph_name(names, 50, b"two")
  set_glyph_name(names, 51, b"three")
  set_glyph_name(names, 52, b"four")
  set_glyph_name(names, 53, b"five")
  set_glyph_name(names, 54, b"six")
  set_glyph_name(names, 55, b"seven")
  set_glyph_name(names, 56, b"eight")
  set_glyph_name(names, 57, b"nine")
  set_glyph_name(names, 58, b"colon")
  set_glyph_name(names, 59, b"semicolon")
  set_glyph_name(names, 60, b"less")
  set_glyph_name(names, 61, b"equal")
  set_glyph_name(names, 62, b"greater")
  set_glyph_name(names, 63, b"question")
  set_glyph_name(names, 64, b"at")
  set_glyph_name(names, 65, b"A")
  set_glyph_name(names, 66, b"B")
  set_glyph_name(names, 67, b"C")
  set_glyph_name(names, 68, b"D")
  set_glyph_name(names, 69, b"E")
  set_glyph_name(names, 70, b"F")
  set_glyph_name(names, 71, b"G")
  set_glyph_name(names, 72, b"H")
  set_glyph_name(names, 73, b"I")
  set_glyph_name(names, 74, b"J")
  set_glyph_name(names, 75, b"K")
  set_glyph_name(names, 76, b"L")
  set_glyph_name(names, 77, b"M")
  set_glyph_name(names, 78, b"N")
  set_glyph_name(names, 79, b"O")
  set_glyph_name(names, 80, b"P")
  set_glyph_name(names, 81, b"Q")
  set_glyph_name(names, 82, b"R")
  set_glyph_name(names, 83, b"S")
  set_glyph_name(names, 84, b"T")
  set_glyph_name(names, 85, b"U")
  set_glyph_name(names, 86, b"V")
  set_glyph_name(names, 87, b"W")
  set_glyph_name(names, 88, b"X")
  set_glyph_name(names, 89, b"Y")
  set_glyph_name(names, 90, b"Z")
  set_glyph_name(names, 91, b"bracketleft")
  set_glyph_name(names, 92, b"backslash")
  set_glyph_name(names, 93, b"bracketright")
  set_glyph_name(names, 94, b"asciicircum")
  set_glyph_name(names, 95, b"underscore")
  set_glyph_name(names, 96, b"grave")
  set_glyph_name(names, 97, b"a")
  set_glyph_name(names, 98, b"b")
  set_glyph_name(names, 99, b"c")
  set_glyph_name(names, 100, b"d")
  set_glyph_name(names, 101, b"e")
  set_glyph_name(names, 102, b"f")
  set_glyph_name(names, 103, b"g")
  set_glyph_name(names, 104, b"h")
  set_glyph_name(names, 105, b"i")
  set_glyph_name(names, 106, b"j")
  set_glyph_name(names, 107, b"k")
  set_glyph_name(names, 108, b"l")
  set_glyph_name(names, 109, b"m")
  set_glyph_name(names, 110, b"n")
  set_glyph_name(names, 111, b"o")
  set_glyph_name(names, 112, b"p")
  set_glyph_name(names, 113, b"q")
  set_glyph_name(names, 114, b"r")
  set_glyph_name(names, 115, b"s")
  set_glyph_name(names, 116, b"t")
  set_glyph_name(names, 117, b"u")
  set_glyph_name(names, 118, b"v")
  set_glyph_name(names, 119, b"w")
  set_glyph_name(names, 120, b"x")
  set_glyph_name(names, 121, b"y")
  set_glyph_name(names, 122, b"z")
  set_glyph_name(names, 123, b"braceleft")
  set_glyph_name(names, 124, b"bar")
  set_glyph_name(names, 125, b"braceright")
  set_glyph_name(names, 126, b"asciitilde")
}

///|
fn install_standard_extra_names(names : Map[Int, @objects.PdfName]) -> Unit {
  set_glyph_name(names, 39, b"quoteright")
  set_glyph_name(names, 96, b"quoteleft")
}

///|
fn install_win_ansi_extra_names(names : Map[Int, @objects.PdfName]) -> Unit {
  set_glyph_name(names, 128, b"Euro")
  set_glyph_name(names, 130, b"quotesinglbase")
  set_glyph_name(names, 131, b"florin")
  set_glyph_name(names, 132, b"quotedblbase")
  set_glyph_name(names, 133, b"ellipsis")
  set_glyph_name(names, 134, b"dagger")
  set_glyph_name(names, 135, b"daggerdbl")
  set_glyph_name(names, 136, b"circumflex")
  set_glyph_name(names, 137, b"perthousand")
  set_glyph_name(names, 138, b"Scaron")
  set_glyph_name(names, 139, b"guilsinglleft")
  set_glyph_name(names, 140, b"OE")
  set_glyph_name(names, 142, b"Zcaron")
  set_glyph_name(names, 145, b"quoteleft")
  set_glyph_name(names, 146, b"quoteright")
  set_glyph_name(names, 147, b"quotedblleft")
  set_glyph_name(names, 148, b"quotedblright")
  set_glyph_name(names, 149, b"bullet")
  set_glyph_name(names, 150, b"endash")
  set_glyph_name(names, 151, b"emdash")
  set_glyph_name(names, 152, b"tilde")
  set_glyph_name(names, 153, b"trademark")
  set_glyph_name(names, 154, b"scaron")
  set_glyph_name(names, 155, b"guilsinglright")
  set_glyph_name(names, 156, b"oe")
  set_glyph_name(names, 158, b"zcaron")
  set_glyph_name(names, 159, b"Ydieresis")
}

///|
fn install_mac_roman_extra_names(names : Map[Int, @objects.PdfName]) -> Unit {
  set_glyph_name(names, 128, b"Adieresis")
  set_glyph_name(names, 129, b"Aring")
  set_glyph_name(names, 130, b"Ccedilla")
  set_glyph_name(names, 131, b"Eacute")
  set_glyph_name(names, 132, b"Ntilde")
  set_glyph_name(names, 133, b"Odieresis")
  set_glyph_name(names, 134, b"Udieresis")
  set_glyph_name(names, 135, b"aacute")
  set_glyph_name(names, 136, b"agrave")
  set_glyph_name(names, 137, b"acircumflex")
  set_glyph_name(names, 138, b"adieresis")
  set_glyph_name(names, 139, b"atilde")
  set_glyph_name(names, 140, b"aring")
  set_glyph_name(names, 141, b"ccedilla")
  set_glyph_name(names, 142, b"eacute")
  set_glyph_name(names, 143, b"egrave")
  set_glyph_name(names, 144, b"ecircumflex")
  set_glyph_name(names, 145, b"edieresis")
  set_glyph_name(names, 146, b"iacute")
  set_glyph_name(names, 147, b"igrave")
  set_glyph_name(names, 148, b"icircumflex")
  set_glyph_name(names, 149, b"idieresis")
  set_glyph_name(names, 150, b"ntilde")
  set_glyph_name(names, 151, b"oacute")
  set_glyph_name(names, 152, b"ograve")
  set_glyph_name(names, 153, b"ocircumflex")
  set_glyph_name(names, 154, b"odieresis")
  set_glyph_name(names, 155, b"otilde")
  set_glyph_name(names, 156, b"uacute")
  set_glyph_name(names, 157, b"ugrave")
  set_glyph_name(names, 158, b"ucircumflex")
  set_glyph_name(names, 159, b"udieresis")
}

///|
fn install_mac_expert_extra_names(names : Map[Int, @objects.PdfName]) -> Unit {
  set_glyph_name(names, 32, b"space")
  set_glyph_name(names, 33, b"exclamsmall")
  set_glyph_name(names, 34, b"Hungarumlautsmall")
  set_glyph_name(names, 35, b"centoldstyle")
  set_glyph_name(names, 36, b"dollaroldstyle")
  set_glyph_name(names, 37, b"dollarsuperior")
  set_glyph_name(names, 38, b"ampersandsmall")
}
