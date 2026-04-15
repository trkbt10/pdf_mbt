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
      GlyphMetrics::from_horizontal_width(width, GlyphWidthSource::FontDictionary)
    None =>
      match default_width {
        Some(width) => GlyphMetrics::from_horizontal_width(width, default_source)
        None => GlyphMetrics::unknown()
      }
  }
}

///|
fn load_runtime_font(
  summary : FontResourceSummary,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> RuntimeFont raise PdfTextError {
  match summary.font_object {
    @objects.PdfObject::Dictionary(dict) =>
      parse_runtime_font_dictionary(dict, offset, limits)
    _ =>
      raise PdfTextError::InvalidFont(
        TextErrorContext::with_resource(offset, summary.resource_name.to_text()),
        "font resource must be a materialized dictionary",
      )
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
        default_width,
        default_width_source: GlyphWidthSource::FontDescriptorMissingWidth,
      }
    }
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
  GlyphMetrics::resolve_width(
    code,
    font.widths,
    font.default_width,
    font.default_width_source,
  )
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
