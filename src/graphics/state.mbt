///|
/// Line cap styles from ISO 32000-2 Table 53.
pub(all) enum LineCapStyle {
  ButtCap
  RoundCap
  ProjectingSquareCap
} derive(Eq, Debug)

///|
/// Line join styles from ISO 32000-2 Table 54.
pub(all) enum LineJoinStyle {
  MiterJoin
  RoundJoin
  BevelJoin
} derive(Eq, Debug)

///|
/// Current line dash array and normalized phase.
pub(all) struct DashPattern {
  array : Array[Double]
  phase : Double
} derive(Eq, Debug)

///|
/// Caller-supplied initial page graphics state inputs. Device-specific CTM
/// construction is kept outside the graphics package.
pub(all) struct GraphicsInitialState {
  ctm : GraphicsMatrix
  initial_clip : GraphicsPath?
  user_unit : Double
  page_rotate : Int
} derive(Eq, Debug)

///|
/// Stored graphics state parameters from ISO 32000-2 section 8.4. Current
/// path and pending clipping are intentionally excluded from this state.
pub(all) struct GraphicsState {
  mut ctm : GraphicsMatrix
  mut clipping_path : ClipState
  mut stroking_color_space : @objects.PdfObject
  mut nonstroking_color_space : @objects.PdfObject
  mut stroking_color : @objects.PdfObject
  mut nonstroking_color : @objects.PdfObject
  mut line_width : Double
  mut line_cap : LineCapStyle
  mut line_join : LineJoinStyle
  mut miter_limit : Double
  mut dash_pattern : DashPattern
  mut rendering_intent : @objects.PdfName
  mut flatness : Double
  mut stroke_adjustment : Bool
  mut overprint_stroking : Bool
  mut overprint_nonstroking : Bool
  mut overprint_mode : Int
  mut blend_mode : @objects.PdfObject
  mut soft_mask : @objects.PdfObject
  mut alpha_stroking : Double
  mut alpha_nonstroking : Double
  mut alpha_source : Bool
  mut text_knockout : Bool
  mut black_point_compensation : @objects.PdfName
  mut halftone_origin : GraphicsPoint?
  mut deferred_entries : @objects.PdfDictionary
  user_unit : Double
  page_rotate : Int
} derive(Eq, Debug)

///|
pub(all) struct GraphicsStateStack {
  mut stack : Array[GraphicsState]
} derive(Eq, Debug)

///|
pub fn DashPattern::solid() -> DashPattern {
  DashPattern::{ array: [], phase: 0.0 }
}

///|
pub fn make_dash_pattern(
  values : Array[Double],
  phase : Double,
  offset : Int64,
) -> DashPattern raise PdfGraphicsError {
  if phase < 0.0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "dash phase must be nonnegative",
    )
  }
  let mut total = 0.0
  for value in values {
    if value < 0.0 {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "dash array elements must be nonnegative",
      )
    }
    total += value
  }
  if values.length() > 0 && total == 0.0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "nonempty dash array must not be all zero",
    )
  }
  let normalized = if total > 0.0 { phase % total } else { phase }
  DashPattern::{ array: values.copy(), phase: normalized }
}

///|
pub fn GraphicsInitialState::default() -> GraphicsInitialState {
  GraphicsInitialState::{
    ctm: GraphicsMatrix::identity(),
    initial_clip: None,
    user_unit: 1.0,
    page_rotate: 0,
  }
}

///|
pub fn GraphicsInitialState::from_clip(
  clip : GraphicsPath,
  user_unit : Double,
  page_rotate : Int,
) -> GraphicsInitialState {
  GraphicsInitialState::{
    ctm: GraphicsMatrix::identity(),
    initial_clip: Some(clip.copy()),
    user_unit,
    page_rotate,
  }
}

///|
pub fn GraphicsState::initial(initial : GraphicsInitialState) -> GraphicsState {
  GraphicsState::{
    ctm: initial.ctm,
    clipping_path: ClipState::new(initial.initial_clip),
    stroking_color_space: @objects.PdfObject::Name(
      @objects.PdfName::new(b"DeviceGray"),
    ),
    nonstroking_color_space: @objects.PdfObject::Name(
      @objects.PdfName::new(b"DeviceGray"),
    ),
    stroking_color: @objects.PdfObject::Integer(0L),
    nonstroking_color: @objects.PdfObject::Integer(0L),
    line_width: 1.0,
    line_cap: LineCapStyle::ButtCap,
    line_join: LineJoinStyle::MiterJoin,
    miter_limit: 10.0,
    dash_pattern: DashPattern::solid(),
    rendering_intent: @objects.PdfName::new(b"RelativeColorimetric"),
    flatness: 1.0,
    stroke_adjustment: false,
    overprint_stroking: false,
    overprint_nonstroking: false,
    overprint_mode: 0,
    blend_mode: @objects.PdfObject::Name(@objects.PdfName::new(b"Normal")),
    soft_mask: @objects.PdfObject::Name(@objects.PdfName::new(b"None")),
    alpha_stroking: 1.0,
    alpha_nonstroking: 1.0,
    alpha_source: false,
    text_knockout: true,
    black_point_compensation: @objects.PdfName::new(b"Default"),
    halftone_origin: None,
    deferred_entries: Map::new(),
    user_unit: initial.user_unit,
    page_rotate: initial.page_rotate,
  }
}

///|
pub fn GraphicsState::copy(self : GraphicsState) -> GraphicsState {
  GraphicsState::{
    ctm: self.ctm,
    clipping_path: self.clipping_path.copy(),
    stroking_color_space: self.stroking_color_space,
    nonstroking_color_space: self.nonstroking_color_space,
    stroking_color: self.stroking_color,
    nonstroking_color: self.nonstroking_color,
    line_width: self.line_width,
    line_cap: self.line_cap,
    line_join: self.line_join,
    miter_limit: self.miter_limit,
    dash_pattern: DashPattern::{
      array: self.dash_pattern.array.copy(),
      phase: self.dash_pattern.phase,
    },
    rendering_intent: self.rendering_intent,
    flatness: self.flatness,
    stroke_adjustment: self.stroke_adjustment,
    overprint_stroking: self.overprint_stroking,
    overprint_nonstroking: self.overprint_nonstroking,
    overprint_mode: self.overprint_mode,
    blend_mode: self.blend_mode,
    soft_mask: self.soft_mask,
    alpha_stroking: self.alpha_stroking,
    alpha_nonstroking: self.alpha_nonstroking,
    alpha_source: self.alpha_source,
    text_knockout: self.text_knockout,
    black_point_compensation: self.black_point_compensation,
    halftone_origin: self.halftone_origin,
    deferred_entries: self.deferred_entries.copy(),
    user_unit: self.user_unit,
    page_rotate: self.page_rotate,
  }
}

///|
pub fn GraphicsState::concat_ctm(
  self : GraphicsState,
  transform : GraphicsMatrix,
) -> Unit {
  self.ctm = GraphicsMatrix::concat(transform, self.ctm)
}

///|
pub fn GraphicsState::set_line_width(
  self : GraphicsState,
  width : Double,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if width < 0.0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "line width must be nonnegative",
    )
  }
  self.line_width = width
}

///|
pub fn LineCapStyle::from_int(
  value : Int64,
  offset : Int64,
) -> LineCapStyle raise PdfGraphicsError {
  match value {
    0L => LineCapStyle::ButtCap
    1L => LineCapStyle::RoundCap
    2L => LineCapStyle::ProjectingSquareCap
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "line cap must be 0, 1, or 2",
      )
  }
}

///|
pub fn LineJoinStyle::from_int(
  value : Int64,
  offset : Int64,
) -> LineJoinStyle raise PdfGraphicsError {
  match value {
    0L => LineJoinStyle::MiterJoin
    1L => LineJoinStyle::RoundJoin
    2L => LineJoinStyle::BevelJoin
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "line join must be 0, 1, or 2",
      )
  }
}

///|
pub fn GraphicsState::set_miter_limit(
  self : GraphicsState,
  limit : Double,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if limit < 1.0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "miter limit must be at least 1",
    )
  }
  self.miter_limit = limit
}

///|
pub fn GraphicsState::set_flatness(
  self : GraphicsState,
  flatness : Double,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if flatness < 0.0 || flatness > 100.0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "flatness must be in range 0..100",
    )
  }
  self.flatness = flatness
}

///|
pub fn GraphicsStateStack::new() -> GraphicsStateStack {
  GraphicsStateStack::{ stack: [] }
}

///|
pub fn GraphicsStateStack::save(
  self : GraphicsStateStack,
  state : GraphicsState,
) -> Unit {
  self.stack.push(state.copy())
}

///|
pub fn GraphicsStateStack::restore(
  self : GraphicsStateStack,
  offset : Int64,
) -> GraphicsState raise PdfGraphicsError {
  match self.stack.pop() {
    Some(state) => state.copy()
    None => raise PdfGraphicsError::GraphicsStackUnderflow(offset)
  }
}
