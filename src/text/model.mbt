///|
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
pub(all) struct FontResourceSummary {
  resource_name : @objects.PdfName
  font_object : @objects.PdfObject
} derive(Eq, Debug)

///|
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
