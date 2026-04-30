///|
/// Device-independent PDF text facilities for representing characters with
/// glyphs from fonts. A text program records how content-stream text objects
/// select fonts, position glyphs, paint glyphs, and preserve extractable text
/// without executing a renderer.
pub(all) enum GlyphWidthSource {
  FontDictionary
  FontDescriptorMissingWidth
  Standard14Fallback
  CIDDefaultWidth
  CIDExplicitWidth
  Type3GlyphProgram
  UnknownWidth
} derive(Eq, Debug)

///|
pub(all) struct GlyphMetrics {
  horizontal_displacement : Double
  vertical_displacement_x : Double
  vertical_displacement_y : Double
  vertical_origin_x : Double
  vertical_origin_y : Double
  width_source : GlyphWidthSource
} derive(Eq, Debug)

///|
pub(all) enum GlyphIdentifier {
  GlyphName(@objects.PdfName)
  CharacterCode(Int)
  CID(Int)
  Notdef
} derive(Eq, Debug)

///|
pub(all) enum GlyphFallback {
  NoFallback
  NotdefGlyph
  MissingUnicode
  CIDZero
  ProcessorChoice
} derive(Eq, Debug)

///|
pub(all) struct DecodedGlyph {
  source_bytes : Bytes
  source_code : Int
  glyph : GlyphIdentifier
  metrics : GlyphMetrics
  word_spacing_eligible : Bool
  fallback : GlyphFallback
} derive(Eq, Debug)

///|
pub(all) enum UnicodeMapping {
  Unicode(String)
  Unknown(Bytes, GlyphIdentifier, GlyphFallback)
} derive(Eq, Debug)

///|
pub(all) struct TextSourceString {
  bytes : Bytes
  operator_offset : Int64
  group_index : Int
} derive(Eq, Debug)

///|
pub(all) struct TextGlyphEvent {
  offset : Int64
  source : TextSourceString
  glyph : DecodedGlyph
  unicode : UnicodeMapping
  text_matrix : TextMatrix
  rendering_matrix : TextRenderingMatrix
  paint : TextPaintIntent
} derive(Eq, Debug)

///|
pub(all) enum TextEvent {
  BeginTextObject(Int64)
  EndTextObject(Int64)
  SourceString(TextSourceString)
  EmptyString(TextSourceString)
  GlyphShown(TextGlyphEvent)
  ClippingSummary(Int64, Array[GlyphIdentifier])
} derive(Eq, Debug)

///|
pub(all) struct TextSpan {
  offset : Int64
  font_name : @objects.PdfName?
  font_size : Double
  text : String
  mappings : Array[UnicodeMapping]
  source_bytes : Bytes
  text_matrix : TextMatrix
} derive(Eq, Debug)

///|
pub(all) struct ExtractedText {
  spans : Array[TextSpan]
} derive(Eq, Debug)

///|
/// Summary of a PDF font dictionary resource. The value may describe a simple
/// font, a Type 0 composite font, a descendant CIDFont, a Type 3 glyph-stream
/// font, or embedded font program metadata that later resolution uses without
/// invoking system font lookup.
pub(all) struct FontResourceSummary {
  resource_name : @objects.PdfName
  font_object : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Materialized text resources needed to interpret show strings: font
/// dictionaries, their encodings, CIDFonts, CMaps, ToUnicode maps, and
/// ExtGState values relevant to text. Font programs remain PDF stream objects
/// and are kept distinct from the font dictionaries that reference them.
pub(all) struct TextResources {
  content_resources : @content.ContentResources
  fonts : Map[@objects.PdfName, FontResourceSummary]
  ext_g_states : Map[@objects.PdfName, @objects.PdfObject]
} derive(Eq, Debug)

///|
pub(all) struct TextInitialState {
  ctm : TextMatrix
  text_knockout : Bool
} derive(Eq, Debug)

///|
/// Clause 9.1 introduction marker for the text layer. It records that this
/// package handles PDF text facilities for representing characters with glyphs
/// from fonts, including text state, text objects and operators, and font data
/// structures, while leaving graphical glyph rendering to later layers.
pub(all) struct PdfTextFacilitiesGeneral {
  represents_characters_with_glyphs_from_fonts : Bool
  covers_text_state_parameters : Bool
  covers_text_objects_and_operators : Bool
  covers_font_data_structures : Bool
} derive(Eq, Debug)

///|
/// Clause 9.5 introduction marker for font data structures. It keeps the PDF
/// distinction between font dictionaries, simple fonts, Type 0 composite
/// fonts, descendant CIDFonts, CMaps, and embedded font program streams.
pub(all) struct PdfFontDataStructuresIntroduction {
  font_dictionary_subtype_value : @objects.PdfName?
  simple_font : Bool
  type0_composite_font : Bool
  cidfont_component : Bool
  cmap_component : Bool
  embedded_font_program_stream : Bool
} derive(Eq, Debug)

///|
pub(all) struct TextProgram {
  events : Array[TextEvent]
  spans : Array[TextSpan]
  final_state : TextState
} derive(Eq, Debug)

///|
pub fn GlyphMetrics::unknown() -> GlyphMetrics {
  GlyphMetrics::{
    horizontal_displacement: 0.0,
    vertical_displacement_x: 0.0,
    vertical_displacement_y: 0.0,
    vertical_origin_x: 0.0,
    vertical_origin_y: 0.0,
    width_source: GlyphWidthSource::UnknownWidth,
  }
}

///|
pub fn TextResources::empty() -> TextResources {
  TextResources::{
    content_resources: @content.ContentResources::empty(),
    fonts: Map::new(),
    ext_g_states: Map::new(),
  }
}

///|
pub fn TextResources::from_content_resources(
  resources : @content.ContentResources,
  offset : Int64,
) -> TextResources raise PdfTextError {
  TextResources::{
    content_resources: resources,
    fonts: collect_font_resources(resources, offset),
    ext_g_states: collect_object_resources(
      resources,
      @content.ResourceCategory::ExtGState,
      offset,
    ),
  }
}

///|
pub fn TextInitialState::default() -> TextInitialState {
  TextInitialState::{ ctm: TextMatrix::identity(), text_knockout: true }
}

///|
pub fn PdfTextFacilitiesGeneral::clause_9_1() -> PdfTextFacilitiesGeneral {
  PdfTextFacilitiesGeneral::{
    represents_characters_with_glyphs_from_fonts: true,
    covers_text_state_parameters: true,
    covers_text_objects_and_operators: true,
    covers_font_data_structures: true,
  }
}

///|
pub fn PdfFontDataStructuresIntroduction::clause_9_5(
  subtype : @objects.PdfName?,
) -> PdfFontDataStructuresIntroduction {
  PdfFontDataStructuresIntroduction::{
    font_dictionary_subtype_value: subtype,
    simple_font: true,
    type0_composite_font: true,
    cidfont_component: true,
    cmap_component: true,
    embedded_font_program_stream: true,
  }
}

///|
pub fn TextProgram::empty() -> TextProgram {
  TextProgram::{ events: [], spans: [], final_state: TextState::initial() }
}

///|
pub fn ExtractedText::from_spans(spans : Array[TextSpan]) -> ExtractedText {
  ExtractedText::{ spans: spans.copy() }
}

///|
fn collect_font_resources(
  resources : @content.ContentResources,
  offset : Int64,
) -> Map[@objects.PdfName, FontResourceSummary] raise PdfTextError {
  let fonts : Map[@objects.PdfName, FontResourceSummary] = Map::new()
  match
    resource_category_object(resources, @content.ResourceCategory::Font, offset) {
    None => fonts
    Some(@objects.PdfObject::Dictionary(dictionary)) => {
      for entry in dictionary.to_array() {
        let (name, value) = entry
        fonts[name] = FontResourceSummary::{
          resource_name: name,
          font_object: value,
        }
      }
      fonts
    }
    Some(_) =>
      raise PdfTextError::MissingResource(
        TextErrorContext::with_resource(offset, "Font"),
        "Font resources must be a dictionary",
      )
  }
}

///|
fn collect_object_resources(
  resources : @content.ContentResources,
  category : @content.ResourceCategory,
  offset : Int64,
) -> Map[@objects.PdfName, @objects.PdfObject] raise PdfTextError {
  let output : Map[@objects.PdfName, @objects.PdfObject] = Map::new()
  match resource_category_object(resources, category, offset) {
    None => output
    Some(@objects.PdfObject::Dictionary(dictionary)) => {
      for entry in dictionary.to_array() {
        let (name, value) = entry
        output[name] = value
      }
      output
    }
    Some(_) =>
      raise PdfTextError::MissingResource(
        TextErrorContext::at(offset),
        "text resource category must be a dictionary",
      )
  }
}

///|
fn resource_category_object(
  resources : @content.ContentResources,
  category : @content.ResourceCategory,
  offset : Int64,
) -> @objects.PdfObject? raise PdfTextError {
  try resources.category_object(category) catch {
    error =>
      raise PdfTextError::ContentFailure(TextErrorContext::at(offset), error)
  } noraise {
    object => object
  }
}
