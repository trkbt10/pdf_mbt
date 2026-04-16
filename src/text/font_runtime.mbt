///|
priv enum RuntimeFontKind {
  Simple(SimpleEncoding)
  Composite(CMap)
}

///|
priv struct RuntimeFont {
  kind : RuntimeFontKind
  to_unicode : ToUnicodeCMap?
  widths : Map[Int, Double]
  standard_widths : Map[Int, Double]
  default_width : Double?
  default_width_source : GlyphWidthSource
}

///|
priv struct RuntimeGlyph {
  glyph : DecodedGlyph
  unicode : UnicodeMapping
}

///|
fn GlyphMetrics::from_horizontal_width(
  width : Double,
  source : GlyphWidthSource,
) -> GlyphMetrics {
  GlyphMetrics::{
    horizontal_displacement: width,
    vertical_displacement_x: 0.0,
    vertical_displacement_y: width,
    vertical_origin_x: 0.0,
    vertical_origin_y: 0.0,
    width_source: source,
  }
}

///|
fn GlyphMetrics::resolve_width(
  code : Int,
  widths : Map[Int, Double],
  default_width : Double?,
  default_source : GlyphWidthSource,
) -> GlyphMetrics {
  match widths.get(code) {
    Some(width) =>
      GlyphMetrics::from_horizontal_width(
        width,
        GlyphWidthSource::FontDictionary,
      )
    None =>
      match default_width {
        Some(width) =>
          GlyphMetrics::from_horizontal_width(width, default_source)
        None => GlyphMetrics::unknown()
      }
  }
}

///|
fn load_runtime_font(
  summary : FontResourceSummary,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> RuntimeFont {
  match summary.font_object {
    @objects.PdfObject::Dictionary(dict) =>
      parse_runtime_font_dictionary(dict, offset, limits)
    _ => fallback_runtime_font(Map::new(), offset)
  }
}

///|
fn decode_runtime_font_string(
  font : RuntimeFont,
  bytes : Bytes,
  offset : Int64,
) -> Array[RuntimeGlyph] raise PdfTextError {
  match font.kind {
    Simple(encoding) => decode_simple_font_string(font, encoding, bytes, offset)
    Composite(cmap) => decode_composite_font_string(font, cmap, bytes, offset)
  }
}

///|
fn parse_runtime_font_dictionary(
  dict : @objects.PdfDictionary,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> RuntimeFont {
  let parsed : Result[RuntimeFont, PdfTextError] = try? parse_runtime_font_dictionary_strict(
    dict, offset, limits,
  )
  match parsed {
    Ok(font) => font
    Err(_) => fallback_runtime_font(dict, offset)
  }
}

///|
fn parse_runtime_font_dictionary_strict(
  dict : @objects.PdfDictionary,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> RuntimeFont raise PdfTextError {
  let subtype = optional_name_entry(dict, b"Subtype")
  let to_unicode = parse_optional_to_unicode(dict, offset, limits)
  let widths = parse_widths(dict, offset)
  let default_width = font_descriptor_missing_width(dict, offset)
  match subtype {
    Some(name) if name == @objects.PdfName::new(b"Type0") => {
      let cmap = parse_type0_encoding(dict, offset, limits)
      RuntimeFont::{
        kind: Composite(cmap),
        to_unicode,
        widths,
        standard_widths: Map::new(),
        default_width: Some(1000.0),
        default_width_source: GlyphWidthSource::CIDDefaultWidth,
      }
    }
    _ => {
      let encoding = parse_simple_encoding(
        dict.get(@objects.PdfName::new(b"Encoding")),
        offset,
      )
      RuntimeFont::{
        kind: Simple(encoding),
        to_unicode,
        widths,
        standard_widths: standard14_simple_widths(dict, encoding, widths),
        default_width,
        default_width_source: GlyphWidthSource::FontDescriptorMissingWidth,
      }
    }
  }
}

///|
fn fallback_runtime_font(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> RuntimeFont {
  let encoding = SimpleEncoding::standard()
  let widths = fallback_widths(dict, offset)
  RuntimeFont::{
    kind: Simple(encoding),
    to_unicode: None,
    widths,
    standard_widths: standard14_simple_widths(dict, encoding, widths),
    default_width: fallback_missing_width(dict, offset),
    default_width_source: GlyphWidthSource::FontDescriptorMissingWidth,
  }
}

///|
fn fallback_widths(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Map[Int, Double] {
  let parsed : Result[Map[Int, Double], PdfTextError] = try? parse_widths(
    dict, offset,
  )
  match parsed {
    Ok(widths) => widths
    Err(_) => Map::new()
  }
}

///|
fn fallback_missing_width(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Double? {
  let parsed : Result[Double?, PdfTextError] = try? font_descriptor_missing_width(
    dict, offset,
  )
  match parsed {
    Ok(width) => width
    Err(_) => Some(500.0)
  }
}

///|
fn parse_type0_encoding(
  dict : @objects.PdfDictionary,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> CMap raise PdfTextError {
  match dict.get(@objects.PdfName::new(b"Encoding")) {
    Some(@objects.PdfObject::Name(name)) =>
      resolve_predefined_cmap(name, offset)
    Some(@objects.PdfObject::Stream(stream)) =>
      parse_cmap_stream(stream, offset, limits)
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "Type 0 Encoding must be a CMap name or stream",
      )
    None =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "Type 0 font requires an Encoding CMap",
      )
  }
}

///|
fn parse_optional_to_unicode(
  dict : @objects.PdfDictionary,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> ToUnicodeCMap? raise PdfTextError {
  match dict.get(@objects.PdfName::new(b"ToUnicode")) {
    Some(@objects.PdfObject::Stream(stream)) =>
      Some(parse_to_unicode_stream(stream, offset, limits))
    Some(@objects.PdfObject::Null) | None => None
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "ToUnicode must be a materialized stream",
      )
  }
}

///|
fn parse_widths(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Map[Int, Double] raise PdfTextError {
  let widths : Map[Int, Double] = Map::new()
  let first = match dict.get(@objects.PdfName::new(b"FirstChar")) {
    Some(@objects.PdfObject::Integer(value)) => value.to_int()
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "FirstChar must be an integer",
      )
    None => 0
  }
  match dict.get(@objects.PdfName::new(b"Widths")) {
    Some(@objects.PdfObject::Array(values)) =>
      for index in 0..<values.length() {
        widths[first + index] = object_number(values[index], "width", offset)
      }
    Some(@objects.PdfObject::Null) | None => ()
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "Widths must be an array",
      )
  }
  widths
}

///|
fn decode_simple_font_string(
  font : RuntimeFont,
  encoding : SimpleEncoding,
  bytes : Bytes,
  _offset : Int64,
) -> Array[RuntimeGlyph] {
  let output : Array[RuntimeGlyph] = []
  for index in 0..<bytes.length() {
    let source = copy_bytes_range(bytes, index, 1)
    let code = bytes[index].to_int()
    let name = encoding.glyph_name_for_code(code)
    let glyph = DecodedGlyph::{
      source_bytes: source,
      source_code: code,
      glyph: if name == @objects.PdfName::new(b".notdef") {
        GlyphIdentifier::Notdef
      } else {
        GlyphIdentifier::GlyphName(name)
      },
      metrics: glyph_metrics_for_code(font, code),
      word_spacing_eligible: code == 32,
      fallback: if name == @objects.PdfName::new(b".notdef") {
        GlyphFallback::NotdefGlyph
      } else {
        GlyphFallback::NoFallback
      },
    }
    output.push(RuntimeGlyph::{ glyph, unicode: unicode_for_glyph(font, glyph) })
  }
  output
}

///|
fn decode_composite_font_string(
  font : RuntimeFont,
  cmap : CMap,
  bytes : Bytes,
  offset : Int64,
) -> Array[RuntimeGlyph] raise PdfTextError {
  let output : Array[RuntimeGlyph] = []
  let mut index = 0
  while index < bytes.length() {
    let decoded = cmap.decode_next(bytes, index)
    let glyph = DecodedGlyph::{
      source_bytes: decoded.source_bytes,
      source_code: decoded.source_code,
      glyph: GlyphIdentifier::CID(decoded.cid),
      metrics: glyph_metrics_for_code(font, decoded.cid),
      word_spacing_eligible: false,
      fallback: decoded.fallback,
    }
    output.push(RuntimeGlyph::{ glyph, unicode: unicode_for_glyph(font, glyph) })
    if decoded.consumed <= 0 {
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(offset),
        "CMap decoder consumed no bytes",
      )
    }
    index += decoded.consumed
  }
  output
}

///|
fn glyph_metrics_for_code(font : RuntimeFont, code : Int) -> GlyphMetrics {
  match font.widths.get(code) {
    Some(width) =>
      GlyphMetrics::from_horizontal_width(
        width,
        GlyphWidthSource::FontDictionary,
      )
    None =>
      match font.standard_widths.get(code) {
        Some(width) =>
          GlyphMetrics::from_horizontal_width(
            width,
            GlyphWidthSource::Standard14Fallback,
          )
        None =>
          match font.default_width {
            Some(width) =>
              GlyphMetrics::from_horizontal_width(
                width,
                font.default_width_source,
              )
            None => GlyphMetrics::unknown()
          }
      }
  }
}

///|
fn standard14_simple_widths(
  dict : @objects.PdfDictionary,
  encoding : SimpleEncoding,
  explicit_widths : Map[Int, Double],
) -> Map[Int, Double] {
  let output : Map[Int, Double] = Map::new()
  if explicit_widths.length() > 0 {
    return output
  }
  match font_dict_base_font(dict) {
    Some(base_font) =>
      for code in 0..<256 {
        let glyph_name = encoding.glyph_name_for_code(code)
        match standard14_width(base_font, glyph_name) {
          Some(width) => output[code] = width
          None => ()
        }
      }
    None => ()
  }
  output
}

///|
fn font_dict_base_font(dict : @objects.PdfDictionary) -> @objects.PdfName? {
  match dict.get(@objects.PdfName::new(b"BaseFont")) {
    Some(@objects.PdfObject::Name(name)) => Some(strip_subset_font_tag(name))
    _ => None
  }
}

///|
fn strip_subset_font_tag(name : @objects.PdfName) -> @objects.PdfName {
  let bytes = name.bytes
  if bytes.length() > 7 && bytes[6] == b'+' && is_subset_font_tag_prefix(bytes) {
    let out : Array[Byte] = []
    for index in 7..<bytes.length() {
      out.push(bytes[index])
    }
    @objects.PdfName::new(Bytes::from_array(out))
  } else {
    name
  }
}

///|
fn is_subset_font_tag_prefix(bytes : Bytes) -> Bool {
  let mut ok = true
  for index in 0..<6 {
    let byte = bytes[index]
    if byte < b'A' || byte > b'Z' {
      ok = false
    }
  }
  ok
}

///|
fn standard14_width(
  base_font : @objects.PdfName,
  glyph_name : @objects.PdfName,
) -> Double? {
  if is_standard14_courier(base_font) {
    if glyph_name == @objects.PdfName::new(b".notdef") {
      None
    } else {
      Some(600.0)
    }
  } else if is_standard14_helvetica(base_font) {
    helvetica_glyph_width(glyph_name)
  } else {
    None
  }
}

///|
fn is_standard14_courier(name : @objects.PdfName) -> Bool {
  name == @objects.PdfName::new(b"Courier") ||
  name == @objects.PdfName::new(b"Courier-Bold") ||
  name == @objects.PdfName::new(b"Courier-Oblique") ||
  name == @objects.PdfName::new(b"Courier-BoldOblique")
}

///|
fn is_standard14_helvetica(name : @objects.PdfName) -> Bool {
  name == @objects.PdfName::new(b"Helvetica") ||
  name == @objects.PdfName::new(b"Helvetica-Bold") ||
  name == @objects.PdfName::new(b"Helvetica-Oblique") ||
  name == @objects.PdfName::new(b"Helvetica-BoldOblique")
}

///|
fn helvetica_glyph_width(name : @objects.PdfName) -> Double? {
  if name == @objects.PdfName::new(b"space") {
    Some(278.0)
  } else if name == @objects.PdfName::new(b"exclam") {
    Some(278.0)
  } else if name == @objects.PdfName::new(b"quotedbl") {
    Some(355.0)
  } else if name == @objects.PdfName::new(b"numbersign") {
    Some(556.0)
  } else if name == @objects.PdfName::new(b"dollar") {
    Some(556.0)
  } else if name == @objects.PdfName::new(b"percent") {
    Some(889.0)
  } else if name == @objects.PdfName::new(b"ampersand") {
    Some(667.0)
  } else if name == @objects.PdfName::new(b"quotesingle") ||
    name == @objects.PdfName::new(b"quoteright") ||
    name == @objects.PdfName::new(b"quoteleft") ||
    name == @objects.PdfName::new(b"grave") {
    Some(222.0)
  } else {
    helvetica_glyph_width_ascii_tail(name)
  }
}

///|
fn helvetica_glyph_width_ascii_tail(name : @objects.PdfName) -> Double? {
  if name == @objects.PdfName::new(b"parenleft") ||
    name == @objects.PdfName::new(b"parenright") ||
    name == @objects.PdfName::new(b"bracketleft") ||
    name == @objects.PdfName::new(b"bracketright") ||
    name == @objects.PdfName::new(b"hyphen") {
    Some(333.0)
  } else if name == @objects.PdfName::new(b"asterisk") {
    Some(389.0)
  } else if name == @objects.PdfName::new(b"plus") ||
    name == @objects.PdfName::new(b"less") ||
    name == @objects.PdfName::new(b"equal") ||
    name == @objects.PdfName::new(b"greater") ||
    name == @objects.PdfName::new(b"asciitilde") {
    Some(584.0)
  } else if name == @objects.PdfName::new(b"comma") ||
    name == @objects.PdfName::new(b"period") ||
    name == @objects.PdfName::new(b"slash") ||
    name == @objects.PdfName::new(b"colon") ||
    name == @objects.PdfName::new(b"semicolon") ||
    name == @objects.PdfName::new(b"backslash") ||
    name == @objects.PdfName::new(b"f") ||
    name == @objects.PdfName::new(b"t") {
    Some(278.0)
  } else if helvetica_glyph_is_digit(name) {
    Some(556.0)
  } else if name == @objects.PdfName::new(b"question") {
    Some(556.0)
  } else {
    helvetica_glyph_width_letters(name)
  }
}

///|
fn helvetica_glyph_is_digit(name : @objects.PdfName) -> Bool {
  name == @objects.PdfName::new(b"zero") ||
  name == @objects.PdfName::new(b"one") ||
  name == @objects.PdfName::new(b"two") ||
  name == @objects.PdfName::new(b"three") ||
  name == @objects.PdfName::new(b"four") ||
  name == @objects.PdfName::new(b"five") ||
  name == @objects.PdfName::new(b"six") ||
  name == @objects.PdfName::new(b"seven") ||
  name == @objects.PdfName::new(b"eight") ||
  name == @objects.PdfName::new(b"nine")
}

///|
fn helvetica_glyph_width_letters(name : @objects.PdfName) -> Double? {
  if name == @objects.PdfName::new(b"at") {
    Some(1015.0)
  } else if name == @objects.PdfName::new(b"A") ||
    name == @objects.PdfName::new(b"B") ||
    name == @objects.PdfName::new(b"V") ||
    name == @objects.PdfName::new(b"X") {
    Some(667.0)
  } else if name == @objects.PdfName::new(b"C") ||
    name == @objects.PdfName::new(b"D") ||
    name == @objects.PdfName::new(b"H") ||
    name == @objects.PdfName::new(b"N") ||
    name == @objects.PdfName::new(b"R") ||
    name == @objects.PdfName::new(b"U") {
    Some(722.0)
  } else if name == @objects.PdfName::new(b"E") ||
    name == @objects.PdfName::new(b"K") ||
    name == @objects.PdfName::new(b"P") ||
    name == @objects.PdfName::new(b"Y") {
    Some(667.0)
  } else {
    helvetica_glyph_width_letters_tail(name)
  }
}

///|
fn helvetica_glyph_width_letters_tail(name : @objects.PdfName) -> Double? {
  if name == @objects.PdfName::new(b"F") ||
    name == @objects.PdfName::new(b"T") ||
    name == @objects.PdfName::new(b"Z") {
    Some(611.0)
  } else if name == @objects.PdfName::new(b"G") ||
    name == @objects.PdfName::new(b"O") ||
    name == @objects.PdfName::new(b"Q") {
    Some(778.0)
  } else if name == @objects.PdfName::new(b"I") {
    Some(278.0)
  } else if name == @objects.PdfName::new(b"J") {
    Some(500.0)
  } else if name == @objects.PdfName::new(b"L") {
    Some(556.0)
  } else if name == @objects.PdfName::new(b"M") ||
    name == @objects.PdfName::new(b"m") {
    Some(833.0)
  } else if name == @objects.PdfName::new(b"S") {
    Some(667.0)
  } else if name == @objects.PdfName::new(b"W") {
    Some(944.0)
  } else {
    helvetica_glyph_width_lowercase(name)
  }
}

///|
fn helvetica_glyph_width_lowercase(name : @objects.PdfName) -> Double? {
  if name == @objects.PdfName::new(b"a") ||
    name == @objects.PdfName::new(b"b") ||
    name == @objects.PdfName::new(b"d") ||
    name == @objects.PdfName::new(b"e") ||
    name == @objects.PdfName::new(b"g") ||
    name == @objects.PdfName::new(b"h") ||
    name == @objects.PdfName::new(b"n") ||
    name == @objects.PdfName::new(b"o") ||
    name == @objects.PdfName::new(b"p") ||
    name == @objects.PdfName::new(b"q") ||
    name == @objects.PdfName::new(b"u") {
    Some(556.0)
  } else if name == @objects.PdfName::new(b"c") ||
    name == @objects.PdfName::new(b"k") ||
    name == @objects.PdfName::new(b"s") ||
    name == @objects.PdfName::new(b"v") ||
    name == @objects.PdfName::new(b"x") ||
    name == @objects.PdfName::new(b"y") ||
    name == @objects.PdfName::new(b"z") {
    Some(500.0)
  } else if name == @objects.PdfName::new(b"i") ||
    name == @objects.PdfName::new(b"j") ||
    name == @objects.PdfName::new(b"l") {
    Some(222.0)
  } else if name == @objects.PdfName::new(b"r") {
    Some(333.0)
  } else if name == @objects.PdfName::new(b"w") {
    Some(722.0)
  } else if name == @objects.PdfName::new(b"asciicircum") {
    Some(469.0)
  } else if name == @objects.PdfName::new(b"underscore") {
    Some(556.0)
  } else if name == @objects.PdfName::new(b"braceleft") ||
    name == @objects.PdfName::new(b"braceright") {
    Some(334.0)
  } else if name == @objects.PdfName::new(b"bar") {
    Some(260.0)
  } else {
    None
  }
}

///|
fn unicode_for_glyph(
  font : RuntimeFont,
  glyph : DecodedGlyph,
) -> UnicodeMapping {
  match font.to_unicode {
    Some(to_unicode) =>
      match to_unicode.map_source_code(glyph.source_bytes) {
        Some(text) => UnicodeMapping::Unicode(text)
        None =>
          map_glyph_name_to_unicode(
            glyph.source_bytes,
            glyph.glyph,
            GlyphFallback::MissingUnicode,
          )
      }
    None =>
      map_glyph_name_to_unicode(
        glyph.source_bytes,
        glyph.glyph,
        GlyphFallback::MissingUnicode,
      )
  }
}

///|
fn optional_name_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> @objects.PdfName? {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Name(name)) => Some(name)
    _ => None
  }
}

///|
fn object_number(
  object : @objects.PdfObject,
  label : String,
  offset : Int64,
) -> Double raise PdfTextError {
  match object {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        label + " must be numeric",
      )
  }
}

///|
fn font_descriptor_missing_width(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Double? raise PdfTextError {
  match dict.get(@objects.PdfName::new(b"FontDescriptor")) {
    Some(@objects.PdfObject::Dictionary(descriptor)) =>
      match descriptor.get(@objects.PdfName::new(b"MissingWidth")) {
        Some(@objects.PdfObject::Null) | None => None
        Some(object) => Some(object_number(object, "MissingWidth", offset))
      }
    Some(@objects.PdfObject::Null) | None => None
    Some(_) =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::at(offset),
        "FontDescriptor must be a dictionary",
      )
  }
}
