///|
/// PDF writing mode used by composite-font metrics.
pub(all) enum WritingMode {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
/// Text rendering mode from ISO 32000-2 Table 105.
pub(all) enum TextRenderingMode {
  Fill
  Stroke
  FillStroke
  Invisible
  FillClip
  StrokeClip
  FillStrokeClip
  Clip
} derive(Eq, Debug)

///|
/// Renderer-independent paint intent for a glyph at one text-showing point.
pub(all) struct TextPaintIntent {
  fill : Bool
  stroke : Bool
  invisible : Bool
  clip : Bool
  type3_clip_suppressed : Bool
} derive(Eq, Debug)

///|
priv struct TextPathConstruction {
  build_glyph_path : Bool
  fill_path : Bool
  stroke_path : Bool
  add_to_clip : Bool
  suppress_type3_clip : Bool
}

///|
/// Text state parameters stored in the graphics state for clause 9.
pub(all) struct TextState {
  character_spacing : Double
  word_spacing : Double
  horizontal_scaling : Double
  leading : Double
  font_name : @objects.PdfName?
  font_size : Double?
  rendering_mode : TextRenderingMode
  text_rise : Double
  text_knockout : Bool
} derive(Eq, Debug)

///|
/// Matrices that exist only inside a text object.
pub(all) struct TextObjectState {
  text_matrix : TextMatrix
  text_line_matrix : TextMatrix
} derive(Eq, Debug)

///|
pub(all) struct TextStateSnapshot {
  state : TextState
  object_state : TextObjectState?
} derive(Eq, Debug)

///|
pub(all) struct TextStateStack {
  stack : Array[TextStateSnapshot]
} derive(Eq, Debug)

///|
pub fn TextRenderingMode::from_int(
  value : Int64,
  context : TextErrorContext,
) -> TextRenderingMode raise PdfTextError {
  match value {
    0L => Fill
    1L => Stroke
    2L => FillStroke
    3L => Invisible
    4L => FillClip
    5L => StrokeClip
    6L => FillStrokeClip
    7L => Clip
    _ =>
      raise PdfTextError::InvalidTextState(
        context, "text rendering mode must be an integer from 0 through 7",
      )
  }
}

///|
pub fn TextRenderingMode::fills(self : TextRenderingMode) -> Bool {
  match self {
    Fill | FillStroke | FillClip | FillStrokeClip => true
    _ => false
  }
}

///|
pub fn TextRenderingMode::strokes(self : TextRenderingMode) -> Bool {
  match self {
    Stroke | FillStroke | StrokeClip | FillStrokeClip => true
    _ => false
  }
}

///|
pub fn TextRenderingMode::is_invisible(self : TextRenderingMode) -> Bool {
  self == Invisible
}

///|
pub fn TextRenderingMode::clips(self : TextRenderingMode) -> Bool {
  match self {
    FillClip | StrokeClip | FillStrokeClip | Clip => true
    _ => false
  }
}

///|
pub fn TextPaintIntent::from_rendering_mode(
  mode : TextRenderingMode,
  is_type3_font : Bool,
) -> TextPaintIntent {
  let path = mode.path_construction(is_type3_font)
  TextPaintIntent::{
    fill: path.fill_path,
    stroke: path.stroke_path,
    invisible: !path.build_glyph_path,
    clip: path.add_to_clip,
    type3_clip_suppressed: path.suppress_type3_clip,
  }
}

///|
fn TextRenderingMode::path_construction(
  self : TextRenderingMode,
  is_type3_font : Bool,
) -> TextPathConstruction {
  let wants_clip = self.clips()
  let paints = self.fills() || self.strokes()
  let build_glyph_path = paints || wants_clip
  TextPathConstruction::{
    build_glyph_path,
    fill_path: self.fills(),
    stroke_path: self.strokes(),
    add_to_clip: wants_clip && !is_type3_font,
    suppress_type3_clip: wants_clip && is_type3_font,
  }
}

///|
pub fn TextState::initial() -> TextState {
  TextState::{
    character_spacing: 0.0,
    word_spacing: 0.0,
    horizontal_scaling: 1.0,
    leading: 0.0,
    font_name: None,
    font_size: None,
    rendering_mode: TextRenderingMode::Fill,
    text_rise: 0.0,
    text_knockout: true,
  }
}

///|
pub fn TextState::with_font(
  self : TextState,
  font_name : @objects.PdfName,
  font_size : Double,
) -> TextState {
  TextState::{
    character_spacing: self.character_spacing,
    word_spacing: self.word_spacing,
    horizontal_scaling: self.horizontal_scaling,
    leading: self.leading,
    font_name: Some(font_name),
    font_size: Some(font_size),
    rendering_mode: self.rendering_mode,
    text_rise: self.text_rise,
    text_knockout: self.text_knockout,
  }
}

///|
pub fn TextState::with_character_spacing(
  self : TextState,
  value : Double,
) -> TextState {
  TextState::{ ..self, character_spacing: value }
}

///|
pub fn TextState::with_word_spacing(
  self : TextState,
  value : Double,
) -> TextState {
  TextState::{ ..self, word_spacing: value }
}

///|
pub fn TextState::with_horizontal_scaling_percent(
  self : TextState,
  value : Double,
) -> TextState {
  TextState::{ ..self, horizontal_scaling: value / 100.0 }
}

///|
pub fn TextState::with_leading(self : TextState, value : Double) -> TextState {
  TextState::{ ..self, leading: value }
}

///|
pub fn TextState::with_rendering_mode(
  self : TextState,
  value : TextRenderingMode,
) -> TextState {
  TextState::{ ..self, rendering_mode: value }
}

///|
pub fn TextState::with_text_rise(self : TextState, value : Double) -> TextState {
  TextState::{ ..self, text_rise: value }
}

///|
pub fn TextState::with_text_knockout(
  self : TextState,
  value : Bool,
) -> TextState {
  TextState::{ ..self, text_knockout: value }
}

///|
fn TextState::effective_font_size(
  self : TextState,
  context : TextErrorContext,
) -> Double raise PdfTextError {
  match self.font_size {
    Some(size) => size
    None =>
      raise PdfTextError::InvalidTextState(
        context,
        "text operation requires a current font size",
      )
  }
}

///|
fn TextState::horizontal_scale_factor(self : TextState) -> Double {
  self.horizontal_scaling
}

///|
fn TextState::vertical_scale_factor(_self : TextState) -> Double {
  1.0
}

///|
fn TextState::text_state_matrix(
  self : TextState,
  context : TextErrorContext,
) -> TextMatrix raise PdfTextError {
  let size = self.effective_font_size(context)
  TextMatrix::text_state_matrix(size, self.horizontal_scale_factor(), self.text_rise)
}

///|
fn TextState::rendering_matrix(
  self : TextState,
  text_matrix : TextMatrix,
  ctm : TextMatrix,
  context : TextErrorContext,
) -> TextRenderingMatrix raise PdfTextError {
  let size = self.effective_font_size(context)
  TextRenderingMatrix::from_text_state(
    text_matrix, size, self.horizontal_scale_factor(), self.text_rise, ctm,
  )
}

///|
pub fn TextObjectState::initial() -> TextObjectState {
  TextObjectState::{
    text_matrix: TextMatrix::identity(),
    text_line_matrix: TextMatrix::identity(),
  }
}

///|
pub fn TextObjectState::move_line(
  self : TextObjectState,
  tx : Double,
  ty : Double,
) -> TextObjectState {
  let line = self.text_line_matrix.translated(tx, ty)
  TextObjectState::{ text_matrix: line, text_line_matrix: line }
}

///|
pub fn TextObjectState::set_text_matrix(
  _self : TextObjectState,
  matrix : TextMatrix,
) -> TextObjectState {
  TextObjectState::{ text_matrix: matrix, text_line_matrix: matrix }
}

///|
fn TextObjectState::apply_td(
  self : TextObjectState,
  tx : Double,
  ty : Double,
) -> TextObjectState {
  self.move_line(tx, ty)
}

///|
fn TextObjectState::apply_tm(
  self : TextObjectState,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> TextObjectState {
  self.set_text_matrix(TextMatrix::from_six(a, b, c, d, e, f))
}

///|
fn TextObjectState::apply_tstar(
  self : TextObjectState,
  leading : Double,
) -> TextObjectState {
  self.move_line(0.0, -leading)
}

///|
pub fn TextStateStack::new() -> TextStateStack {
  TextStateStack::{ stack: [] }
}

///|
pub fn TextStateStack::save(
  self : TextStateStack,
  state : TextState,
  object_state : TextObjectState?,
) -> Unit {
  self.stack.push(TextStateSnapshot::{ state, object_state })
}

///|
pub fn TextStateStack::restore(
  self : TextStateStack,
  context : TextErrorContext,
) -> TextStateSnapshot raise PdfTextError {
  match self.stack.pop() {
    Some(snapshot) => snapshot
    None =>
      raise PdfTextError::InvalidTextState(
        context, "text graphics-state stack underflow",
      )
  }
}
