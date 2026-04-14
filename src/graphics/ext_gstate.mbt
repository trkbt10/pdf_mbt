///|

///|
/// Standard rendering intents from ISO 32000-2 8.6.5.8 Table 69. The ri
/// operator, RI ExtGState entry, and image Intent entry identify priorities
/// for colour rendering; unknown names fall back to RelativeColorimetric.
pub(all) enum RenderingIntent {
  AbsoluteColorimetric
  RelativeColorimetric
  Saturation
  Perceptual
} derive(Eq, Debug)

///|
/// UseBlackPtComp policy from ISO 32000-2 8.6.5.9. ON applies black point
/// compensation according to ISO 18619, OFF disables it, and Default leaves
/// processor behaviour open; AbsoluteColorimetric render intent treats it as
/// OFF for effective colour conversion.
pub(all) enum BlackPointCompensation {
  BlackPointOn
  BlackPointOff
  BlackPointDefault
} derive(Eq, Debug)

///|
/// Cumulative graphics state parameter dictionary patch resolved from an
/// ExtGState resource. Known simple keys are typed; later-phase entries remain
/// raw so rendering, transparency, font, transfer, halftone, and colour
/// semantics stay deferred. Colour-related keys include RI rendering intent,
/// UseBlackPtComp black point compensation, OP/op overprint flags, and OPM
/// overprint mode, where mode 1 is the non-zero overprint mode for DeviceCMYK.
pub(all) struct ExtGStatePatch {
  line_width : Double?
  line_cap : LineCapStyle?
  line_join : LineJoinStyle?
  miter_limit : Double?
  dash_pattern : DashPattern?
  rendering_intent : RenderingIntent?
  flatness : Double?
  stroke_adjustment : Bool?
  overprint_stroking : Bool?
  overprint_nonstroking : Bool?
  overprint_mode : Int?
  blend_mode : BlendMode?
  soft_mask : SoftMaskSource?
  alpha_stroking : Double?
  alpha_nonstroking : Double?
  alpha_is_shape : Bool?
  text_knockout : Bool?
  black_point_compensation : BlackPointCompensation?
  halftone_origin : GraphicsPoint?
  raw_entries : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Resolves a named ExtGState resource from content resources and validates
/// the graphics state parameter dictionary without loading indirect objects.
pub fn resolve_ext_gstate(
  resources : @content.ContentResources,
  name : @objects.PdfName,
  offset : Int64,
) -> ExtGStatePatch raise PdfGraphicsError {
  let object = try
    resources.lookup_resource(@content.ResourceCategory::ExtGState, name)
  catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    value => value
  }
  match object {
    None =>
      raise PdfGraphicsError::ResourceFailure(
        offset,
        "missing ExtGState resource " + name.to_text(),
      )
    Some(@objects.PdfObject::Dictionary(dictionary)) =>
      parse_ext_gstate_dictionary(dictionary, offset)
    Some(_) =>
      raise PdfGraphicsError::ResourceFailure(
        offset, "ExtGState resource must be a direct dictionary",
      )
  }
}

///|
pub fn GraphicsState::apply_ext_gstate(
  self : GraphicsState,
  patch : ExtGStatePatch,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if patch.line_width is Some(value) {
    self.set_line_width(value, offset)
  }
  if patch.line_cap is Some(value) {
    self.line_cap = value
  }
  if patch.line_join is Some(value) {
    self.line_join = value
  }
  if patch.miter_limit is Some(value) {
    self.set_miter_limit(value, offset)
  }
  if patch.dash_pattern is Some(value) {
    self.dash_pattern = DashPattern::{
      array: value.array.copy(),
      phase: value.phase,
    }
  }
  if patch.rendering_intent is Some(value) {
    self.rendering_intent = value
  }
  if patch.flatness is Some(value) {
    self.set_flatness(value, offset)
  }
  if patch.stroke_adjustment is Some(value) {
    self.stroke_adjustment = value
  }
  if patch.overprint_stroking is Some(value) {
    self.overprint_stroking = value
    if patch.overprint_nonstroking is None {
      self.overprint_nonstroking = value
    }
  }
  if patch.overprint_nonstroking is Some(value) {
    self.overprint_nonstroking = value
  }
  if patch.overprint_mode is Some(value) {
    self.overprint_mode = value
  }
  if patch.blend_mode is Some(value) {
    self.blend_mode = value
  }
  if patch.soft_mask is Some(value) {
    self.soft_mask = value.establish(self.ctm)
  }
  if patch.alpha_stroking is Some(value) {
    self.alpha_stroking = value
  }
  if patch.alpha_nonstroking is Some(value) {
    self.alpha_nonstroking = value
  }
  if patch.alpha_is_shape is Some(value) {
    self.alpha_is_shape = value
  }
  if patch.text_knockout is Some(value) {
    self.text_knockout = value
  }
  if patch.black_point_compensation is Some(value) {
    self.black_point_compensation = value
  }
  if patch.halftone_origin is Some(value) {
    self.halftone_origin = Some(value)
  }
  self.deferred_entries.merge_in_place(patch.raw_entries)
}

///|
pub fn GraphicsState::apply_ext_gstate_non_colour(
  self : GraphicsState,
  patch : ExtGStatePatch,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let colourless = ExtGStatePatch::{
    line_width: patch.line_width,
    line_cap: patch.line_cap,
    line_join: patch.line_join,
    miter_limit: patch.miter_limit,
    dash_pattern: patch.dash_pattern,
    rendering_intent: None,
    flatness: patch.flatness,
    stroke_adjustment: patch.stroke_adjustment,
    overprint_stroking: None,
    overprint_nonstroking: None,
    overprint_mode: None,
    blend_mode: patch.blend_mode,
    soft_mask: patch.soft_mask,
    alpha_stroking: patch.alpha_stroking,
    alpha_nonstroking: patch.alpha_nonstroking,
    alpha_is_shape: patch.alpha_is_shape,
    text_knockout: patch.text_knockout,
    black_point_compensation: None,
    halftone_origin: patch.halftone_origin,
    raw_entries: patch.raw_entries,
  }
  self.apply_ext_gstate(colourless, offset)
}

///|
fn parse_ext_gstate_dictionary(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> ExtGStatePatch raise PdfGraphicsError {
  let raw_entries : @objects.PdfDictionary = Map::new()
  for entry in dictionary.to_array() {
    let (key, value) = entry
    if is_deferred_ext_gstate_key(key) {
      raw_entries[key] = value
    }
  }
  ExtGStatePatch::{
    line_width: optional_number(dictionary, b"LW", offset),
    line_cap: optional_line_cap(dictionary, offset),
    line_join: optional_line_join(dictionary, offset),
    miter_limit: optional_number(dictionary, b"ML", offset),
    dash_pattern: optional_dash(dictionary, offset),
    rendering_intent: optional_rendering_intent(dictionary, offset),
    flatness: optional_number(dictionary, b"FL", offset),
    stroke_adjustment: optional_bool(dictionary, b"SA", offset),
    overprint_stroking: optional_bool(dictionary, b"OP", offset),
    overprint_nonstroking: optional_bool(dictionary, b"op", offset),
    overprint_mode: optional_overprint_mode(dictionary, offset),
    blend_mode: optional_blend_mode(dictionary, offset),
    soft_mask: optional_soft_mask(dictionary, offset),
    alpha_stroking: optional_alpha(dictionary, b"CA", offset),
    alpha_nonstroking: optional_alpha(dictionary, b"ca", offset),
    alpha_is_shape: optional_bool(dictionary, b"AIS", offset),
    text_knockout: optional_bool(dictionary, b"TK", offset),
    black_point_compensation: optional_black_point_compensation(
      dictionary, offset,
    ),
    halftone_origin: optional_halftone_origin(dictionary, offset),
    raw_entries,
  }
}

///|
fn optional_number(
  dictionary : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Double? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(key)) {
    None => None
    Some(@objects.PdfObject::Integer(value)) => Some(value.to_double())
    Some(@objects.PdfObject::Real(value)) => Some(value)
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() +
        " ExtGState entry must be a number",
      )
  }
}

///|
fn optional_alpha(
  dictionary : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Double? raise PdfGraphicsError {
  match optional_number(dictionary, key, offset) {
    None => None
    Some(value) => {
      if value < 0.0 || value > 1.0 {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset,
          @objects.PdfName::new(key).to_text() +
          " ExtGState entry must be in range 0..1",
        )
      }
      Some(value)
    }
  }
}

///|
fn optional_blend_mode(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> BlendMode? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(b"BM")) {
    None => None
    Some(value) => Some(BlendMode::from_pdf_object(value, offset))
  }
}

///|
fn optional_soft_mask(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> SoftMaskSource? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(b"SMask")) {
    None => None
    Some(value) => Some(SoftMaskSource::from_pdf_object(value, offset))
  }
}

///|
fn optional_int(
  dictionary : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Int? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(key)) {
    None => None
    Some(@objects.PdfObject::Integer(value)) => Some(value.to_int())
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() +
        " ExtGState entry must be an integer",
      )
  }
}

///|
fn optional_bool(
  dictionary : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Bool? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(key)) {
    None => None
    Some(@objects.PdfObject::Boolean(value)) => Some(value)
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() +
        " ExtGState entry must be a boolean",
      )
  }
}

///|
fn optional_name(
  dictionary : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> @objects.PdfName? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(key)) {
    None => None
    Some(@objects.PdfObject::Name(value)) => Some(value)
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() + " ExtGState entry must be a name",
      )
  }
}

///|
/// Converts a rendering-intent name to the standard Table 69 value, using the
/// required RelativeColorimetric fallback for unrecognized rendering intents.
pub fn rendering_intent_from_name(name : @objects.PdfName) -> RenderingIntent {
  if name == @objects.PdfName::new(b"AbsoluteColorimetric") {
    RenderingIntent::AbsoluteColorimetric
  } else if name == @objects.PdfName::new(b"Saturation") {
    RenderingIntent::Saturation
  } else if name == @objects.PdfName::new(b"Perceptual") {
    RenderingIntent::Perceptual
  } else {
    RenderingIntent::RelativeColorimetric
  }
}

///|
/// Computes the effective UseBlackPtComp value. If the current render intent
/// is AbsoluteColorimetric, ISO 32000-2 requires black point compensation to
/// be treated as OFF even when the ExtGState value is ON or Default.
pub fn effective_black_point_compensation(
  intent : RenderingIntent,
  value : BlackPointCompensation,
) -> BlackPointCompensation {
  match intent {
    AbsoluteColorimetric => BlackPointCompensation::BlackPointOff
    _ => value
  }
}

///|
fn optional_rendering_intent(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> RenderingIntent? raise PdfGraphicsError {
  match optional_name(dictionary, b"RI", offset) {
    None => None
    Some(name) => Some(rendering_intent_from_name(name))
  }
}

///|
fn optional_black_point_compensation(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> BlackPointCompensation? raise PdfGraphicsError {
  match optional_name(dictionary, b"UseBlackPtComp", offset) {
    None => None
    Some(name) => Some(black_point_compensation_from_name(name, offset))
  }
}

///|
fn black_point_compensation_from_name(
  name : @objects.PdfName,
  offset : Int64,
) -> BlackPointCompensation raise PdfGraphicsError {
  if name == @objects.PdfName::new(b"ON") {
    BlackPointCompensation::BlackPointOn
  } else if name == @objects.PdfName::new(b"OFF") {
    BlackPointCompensation::BlackPointOff
  } else if name == @objects.PdfName::new(b"Default") {
    BlackPointCompensation::BlackPointDefault
  } else {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "UseBlackPtComp must be ON, OFF, or Default",
    )
  }
}

///|
fn optional_overprint_mode(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> Int? raise PdfGraphicsError {
  match optional_int(dictionary, b"OPM", offset) {
    None => None
    Some(value) => {
      if value != 0 && value != 1 {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "OPM ExtGState entry must be 0 or 1",
        )
      }
      Some(value)
    }
  }
}

///|
fn optional_line_cap(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> LineCapStyle? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(b"LC")) {
    None => None
    Some(@objects.PdfObject::Integer(value)) =>
      Some(LineCapStyle::from_int(value, offset))
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "LC ExtGState entry must be an integer",
      )
  }
}

///|
fn optional_line_join(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> LineJoinStyle? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(b"LJ")) {
    None => None
    Some(@objects.PdfObject::Integer(value)) =>
      Some(LineJoinStyle::from_int(value, offset))
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "LJ ExtGState entry must be an integer",
      )
  }
}

///|
fn optional_dash(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> DashPattern? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(b"D")) {
    None => None
    Some(@objects.PdfObject::Array(values)) => {
      if values.length() != 2 {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "D ExtGState entry must be [dashArray dashPhase]",
        )
      }
      let dash_values = match values[0] {
        @objects.PdfObject::Array(items) => numbers_from_array(items, offset)
        _ =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "D ExtGState dash array must be an array",
          )
      }
      let phase = object_number(values[1], offset, "D ExtGState dash phase")
      Some(DashPattern::from_values(dash_values, phase, offset))
    }
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "D ExtGState entry must be an array",
      )
  }
}

///|
fn optional_halftone_origin(
  dictionary : @objects.PdfDictionary,
  offset : Int64,
) -> GraphicsPoint? raise PdfGraphicsError {
  match dictionary.get(@objects.PdfName::new(b"HTO")) {
    None => None
    Some(@objects.PdfObject::Array(values)) => {
      if values.length() != 2 {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "HTO ExtGState entry must contain two numbers",
        )
      }
      Some(
        GraphicsPoint::new(
          object_number(values[0], offset, "HTO x"),
          object_number(values[1], offset, "HTO y"),
        ),
      )
    }
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "HTO ExtGState entry must be an array",
      )
  }
}

///|
fn numbers_from_array(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let output : Array[Double] = []
  for value in values {
    output.push(object_number(value, offset, "dash array element"))
  }
  output
}

///|
fn object_number(
  value : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise PdfGraphicsError::BadOperand(offset, label + " must be a number")
  }
}

///|
fn is_deferred_ext_gstate_key(key : @objects.PdfName) -> Bool {
  key == @objects.PdfName::new(b"Font") ||
  key == @objects.PdfName::new(b"BG") ||
  key == @objects.PdfName::new(b"BG2") ||
  key == @objects.PdfName::new(b"UCR") ||
  key == @objects.PdfName::new(b"UCR2") ||
  key == @objects.PdfName::new(b"TR") ||
  key == @objects.PdfName::new(b"TR2") ||
  key == @objects.PdfName::new(b"HT") ||
  key == @objects.PdfName::new(b"SM")
}
