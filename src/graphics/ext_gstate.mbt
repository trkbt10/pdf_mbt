///|
/// Cumulative graphics state parameter dictionary patch resolved from an
/// ExtGState resource. Known simple keys are typed; later-phase entries remain
/// raw so rendering, transparency, font, transfer, halftone, and colour
/// semantics stay deferred.
pub(all) struct ExtGStatePatch {
  line_width : Double?
  line_cap : LineCapStyle?
  line_join : LineJoinStyle?
  miter_limit : Double?
  dash_pattern : DashPattern?
  rendering_intent : @objects.PdfName?
  flatness : Double?
  stroke_adjustment : Bool?
  overprint_stroking : Bool?
  overprint_nonstroking : Bool?
  overprint_mode : Int?
  blend_mode : @objects.PdfObject?
  soft_mask : @objects.PdfObject?
  alpha_stroking : Double?
  alpha_nonstroking : Double?
  alpha_source : Bool?
  text_knockout : Bool?
  black_point_compensation : @objects.PdfName?
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
    self.soft_mask = value
  }
  if patch.alpha_stroking is Some(value) {
    self.alpha_stroking = value
  }
  if patch.alpha_nonstroking is Some(value) {
    self.alpha_nonstroking = value
  }
  if patch.alpha_source is Some(value) {
    self.alpha_source = value
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
    rendering_intent: optional_name(dictionary, b"RI", offset),
    flatness: optional_number(dictionary, b"FL", offset),
    stroke_adjustment: optional_bool(dictionary, b"SA", offset),
    overprint_stroking: optional_bool(dictionary, b"OP", offset),
    overprint_nonstroking: optional_bool(dictionary, b"op", offset),
    overprint_mode: optional_int(dictionary, b"OPM", offset),
    blend_mode: optional_raw(dictionary, b"BM"),
    soft_mask: optional_raw(dictionary, b"SMask"),
    alpha_stroking: optional_number(dictionary, b"CA", offset),
    alpha_nonstroking: optional_number(dictionary, b"ca", offset),
    alpha_source: optional_bool(dictionary, b"AIS", offset),
    text_knockout: optional_bool(dictionary, b"TK", offset),
    black_point_compensation: optional_name(
      dictionary, b"UseBlackPtComp", offset,
    ),
    halftone_origin: optional_halftone_origin(dictionary, offset),
    raw_entries,
  }
}

///|
fn optional_raw(
  dictionary : @objects.PdfDictionary,
  key : Bytes,
) -> @objects.PdfObject? {
  dictionary.get(@objects.PdfName::new(key))
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
      Some(make_dash_pattern(dash_values, phase, offset))
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
