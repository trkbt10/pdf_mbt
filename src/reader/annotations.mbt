///|
fn annotation_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn annotation_error(
  object_id : @objects.ObjectId?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidAnnotation(object_id, reason)
}

///|
fn annotation_load_object(
  file : PdfFile,
  object_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    loaded => loaded
  }
}

///|
fn resolve_annotation_object(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  context : String,
  seen : Map[@objects.ObjectId, Bool],
) -> @objects.PdfObject raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id,
          context + " indirect-object cycle detected",
        )
      }
      seen[object_id] = true
      resolve_annotation_object(
        file,
        annotation_load_object(file, object_id),
        owner,
        context,
        seen,
      )
    }
    _ => {
      let _ = owner
      value
    }
  }
}

///|
fn resolve_annotation_direct(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  context : String,
) -> @objects.PdfObject raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  resolve_annotation_object(file, value, owner, context, seen)
}

///|
fn resolve_annotation_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  context : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match resolve_annotation_direct(file, value, owner, context) {
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise annotation_error(owner, context + " must be a dictionary")
  }
}

///|
fn annotation_number(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Double raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise annotation_error(owner, label + " must be a number")
  }
}

///|
fn annotation_int(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Int raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ => raise annotation_error(owner, label + " must be an integer")
  }
}

///|
fn annotation_bool(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bool raise PdfDocumentError {
  match value {
    @objects.PdfObject::Boolean(value) => value
    _ => raise annotation_error(owner, label + " must be a boolean")
  }
}

///|
fn annotation_name(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ => raise annotation_error(owner, label + " must be a name")
  }
}

///|
fn annotation_string(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ => raise annotation_error(owner, label + " must be a string")
  }
}

///|
fn annotation_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) => values
    _ => raise annotation_error(owner, label + " must be an array")
  }
}

///|
fn annotation_optional_bool(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
  default : Bool,
) -> Bool raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => annotation_bool(value, owner, label)
    None => default
  }
}

///|
fn annotation_optional_name(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(annotation_name(value, owner, label))
    None => None
  }
}

///|
fn annotation_optional_string(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(annotation_string(value, owner, label))
    None => None
  }
}

///|
fn annotation_rectangle(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfRectangle raise PdfDocumentError {
  let values = annotation_array(value, owner, label)
  if values.length() != 4 {
    raise annotation_error(owner, label + " must contain four numbers")
  }
  PdfRectangle::{
    left: annotation_number(values[0], owner, label),
    bottom: annotation_number(values[1], owner, label),
    right: annotation_number(values[2], owner, label),
    top: annotation_number(values[3], owner, label),
  }
}

///|
fn annotation_color(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[Double] raise PdfDocumentError {
  let values = annotation_array(value, owner, label)
  if values.length() > 4 {
    raise annotation_error(owner, label + " has too many components")
  }
  let components : Array[Double] = []
  for item in values {
    let component = annotation_number(item, owner, label)
    if component < 0.0 || component > 1.0 {
      raise annotation_error(owner, label + " components must be in 0..1")
    }
    components.push(component)
  }
  components
}

///|
fn annotation_optional_color(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[Double] raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => annotation_color(value, owner, label)
    None => []
  }
}

///|
fn annotation_opacity(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Double raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => {
      let number = annotation_number(value, owner, label)
      if number < 0.0 || number > 1.0 {
        raise annotation_error(owner, label + " must be in 0..1")
      }
      number
    }
    None => 1.0
  }
}

///|
fn annotation_point_pair(
  values : Array[@objects.PdfObject],
  index : Int,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfPoint raise PdfDocumentError {
  PdfPoint::{
    x: annotation_number(values[index], owner, label),
    y: annotation_number(values[index + 1], owner, label),
  }
}

///|
fn annotation_points_from_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[PdfPoint] raise PdfDocumentError {
  let values = annotation_array(value, owner, label)
  if values.length() % 2 != 0 {
    raise annotation_error(owner, label + " must contain coordinate pairs")
  }
  let points : Array[PdfPoint] = []
  let mut index = 0
  while index < values.length() {
    points.push(annotation_point_pair(values, index, owner, label))
    index = index + 2
  }
  points
}

///|
fn parse_quad_points(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[PdfQuadPoints] raise PdfDocumentError {
  let values = annotation_array(value, owner, label)
  if values.length() == 0 || values.length() % 8 != 0 {
    raise annotation_error(
      owner,
      label + " must contain groups of eight numbers",
    )
  }
  let quads : Array[PdfQuadPoints] = []
  let mut index = 0
  while index < values.length() {
    quads.push(PdfQuadPoints::{
      points: [
        annotation_point_pair(values, index, owner, label),
        annotation_point_pair(values, index + 2, owner, label),
        annotation_point_pair(values, index + 4, owner, label),
        annotation_point_pair(values, index + 6, owner, label),
      ],
    })
    index = index + 8
  }
  quads
}

///|
fn parse_optional_quad_points(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
) -> Array[PdfQuadPoints] raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => parse_quad_points(value, owner, key.to_text())
    None => []
  }
}

///|
fn parse_path_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[PdfAnnotationPath] raise PdfDocumentError {
  let values = annotation_array(value, owner, label)
  let paths : Array[PdfAnnotationPath] = []
  for item in values {
    paths.push(PdfAnnotationPath::{
      points: annotation_points_from_array(item, owner, label),
    })
  }
  paths
}

///|
fn parse_line_coordinates(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfLineCoordinates raise PdfDocumentError {
  let values = annotation_array(value, owner, "L")
  if values.length() != 4 {
    raise annotation_error(owner, "L must contain four numbers")
  }
  PdfLineCoordinates::{
    start: annotation_point_pair(values, 0, owner, "L"),
    end: annotation_point_pair(values, 2, owner, "L"),
  }
}

///|
fn parse_callout(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfAnnotationCallout raise PdfDocumentError {
  let points = annotation_points_from_array(value, owner, "CL")
  if points.length() != 2 && points.length() != 3 {
    raise annotation_error(owner, "CL must contain four or six numbers")
  }
  PdfAnnotationCallout::{ points, }
}

///|
fn parse_optional_rectangle(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfRectangle? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(annotation_rectangle(value, owner, label))
    None => None
  }
}

///|
fn parse_subtype_name(name : @objects.PdfName) -> PdfAnnotationSubtype {
  if name == annotation_key(b"Text") {
    Text
  } else if name == annotation_key(b"Link") {
    Link
  } else if name == annotation_key(b"FreeText") {
    FreeText
  } else if name == annotation_key(b"Line") {
    Line
  } else if name == annotation_key(b"Square") {
    Square
  } else if name == annotation_key(b"Circle") {
    Circle
  } else if name == annotation_key(b"Polygon") {
    Polygon
  } else if name == annotation_key(b"PolyLine") {
    PolyLine
  } else if name == annotation_key(b"Highlight") {
    Highlight
  } else if name == annotation_key(b"Underline") {
    Underline
  } else if name == annotation_key(b"Squiggly") {
    Squiggly
  } else if name == annotation_key(b"StrikeOut") {
    StrikeOut
  } else if name == annotation_key(b"Caret") {
    Caret
  } else if name == annotation_key(b"Stamp") {
    Stamp
  } else if name == annotation_key(b"Ink") {
    Ink
  } else if name == annotation_key(b"Popup") {
    Popup
  } else if name == annotation_key(b"FileAttachment") {
    FileAttachment
  } else if name == annotation_key(b"Sound") {
    Sound
  } else if name == annotation_key(b"Movie") {
    Movie
  } else if name == annotation_key(b"Screen") {
    Screen
  } else if name == annotation_key(b"Widget") {
    Widget
  } else if name == annotation_key(b"PrinterMark") {
    PrinterMark
  } else if name == annotation_key(b"TrapNet") {
    TrapNet
  } else if name == annotation_key(b"Watermark") {
    Watermark
  } else if name == annotation_key(b"Redact") {
    Redact
  } else if name == annotation_key(b"Projection") {
    Projection
  } else if name == annotation_key(b"3D") {
    ThreeD
  } else if name == annotation_key(b"RichMedia") {
    RichMedia
  } else {
    Unknown(name)
  }
}

///|
fn parse_line_ending_style(name : @objects.PdfName) -> PdfLineEndingStyle {
  if name == annotation_key(b"Square") {
    Square
  } else if name == annotation_key(b"Circle") {
    Circle
  } else if name == annotation_key(b"Diamond") {
    Diamond
  } else if name == annotation_key(b"OpenArrow") {
    OpenArrow
  } else if name == annotation_key(b"ClosedArrow") {
    ClosedArrow
  } else if name == annotation_key(b"None") {
    None
  } else if name == annotation_key(b"Butt") {
    Butt
  } else if name == annotation_key(b"ROpenArrow") {
    ROpenArrow
  } else if name == annotation_key(b"RClosedArrow") {
    RClosedArrow
  } else if name == annotation_key(b"Slash") {
    Slash
  } else {
    Unknown(name)
  }
}

///|
fn parse_line_endings(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> Array[PdfLineEndingStyle] raise PdfDocumentError {
  match dict.get(annotation_key(b"LE")) {
    Some(value) => {
      let values = annotation_array(value, owner, "LE")
      if values.length() != 2 {
        raise annotation_error(owner, "LE must contain two names")
      }
      [
        parse_line_ending_style(annotation_name(values[0], owner, "LE")),
        parse_line_ending_style(annotation_name(values[1], owner, "LE")),
      ]
    }
    None => [PdfLineEndingStyle::None, PdfLineEndingStyle::None]
  }
}

///|
fn parse_highlight_mode(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfHighlightMode raise PdfDocumentError {
  match dict.get(annotation_key(b"H")) {
    Some(value) => {
      let name = annotation_name(value, owner, "H")
      if name == annotation_key(b"N") {
        PdfHighlightMode::None
      } else if name == annotation_key(b"I") {
        Invert
      } else if name == annotation_key(b"O") {
        Outline
      } else if name == annotation_key(b"P") {
        Push
      } else {
        Unknown(name)
      }
    }
    None => Invert
  }
}

///|
fn parse_justification(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfJustification raise PdfDocumentError {
  match dict.get(annotation_key(b"Q")) {
    Some(value) => {
      let number = annotation_int(value, owner, "Q")
      if number == 0 {
        Left
      } else if number == 1 {
        Center
      } else if number == 2 {
        Right
      } else {
        Unknown(number)
      }
    }
    None => Left
  }
}

///|
fn parse_annotation_flags(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfAnnotationFlags raise PdfDocumentError {
  match dict.get(annotation_key(b"F")) {
    Some(value) => {
      let bits = annotation_int(value, owner, "F")
      if bits < 0 {
        raise annotation_error(owner, "F must not be negative")
      }
      if bits > 0x3ff {
        raise annotation_error(owner, "F contains reserved annotation flags")
      }
      PdfAnnotationFlags::{ bits, }
    }
    None => PdfAnnotationFlags::{ bits: 0 }
  }
}

///|
/// True when ISO 32000-2 Table 167 bit 1 Invisible is set.
pub fn PdfAnnotationFlags::invisible(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x001) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 2 Hidden is set.
pub fn PdfAnnotationFlags::hidden(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x002) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 3 Print is set.
pub fn PdfAnnotationFlags::print(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x004) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 4 NoZoom is set.
pub fn PdfAnnotationFlags::no_zoom(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x008) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 5 NoRotate is set.
pub fn PdfAnnotationFlags::no_rotate(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x010) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 6 NoView is set.
pub fn PdfAnnotationFlags::no_view(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x020) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 7 ReadOnly is set.
pub fn PdfAnnotationFlags::read_only(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x040) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 8 Locked is set.
pub fn PdfAnnotationFlags::locked(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x080) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 9 ToggleNoView is set.
pub fn PdfAnnotationFlags::toggle_no_view(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x100) != 0
}

///|
/// True when ISO 32000-2 Table 167 bit 10 LockedContents is set.
pub fn PdfAnnotationFlags::locked_contents(self : PdfAnnotationFlags) -> Bool {
  (self.bits & 0x200) != 0
}

///|
/// Structural screen visibility predicate for annotation flags from
/// ISO 32000-2 12.5.3. Hidden, NoView, or Invisible suppress screen display.
pub fn PdfAnnotationFlags::screen_visible(self : PdfAnnotationFlags) -> Bool {
  !self.hidden() && !self.no_view() && !self.invisible()
}

///|
/// Structural print eligibility predicate for annotation flags from
/// ISO 32000-2 12.5.3. Print must be set and Hidden/Invisible must be clear.
pub fn PdfAnnotationFlags::print_eligible(self : PdfAnnotationFlags) -> Bool {
  self.print() && !self.hidden() && !self.invisible()
}

///|
/// Effective NoZoom predicate. ISO 32000-2 12.5.6.4 text annotations behave
/// as if the NoZoom annotation flag from Table 167 were always set.
pub fn PdfAnnotation::no_zoom(self : PdfAnnotation) -> Bool {
  self.common.flags.no_zoom() ||
  self.common.subtype == PdfAnnotationSubtype::Text
}

///|
/// Effective NoRotate predicate. ISO 32000-2 12.5.6.4 text annotations behave
/// as if the NoRotate annotation flag from Table 167 were always set.
pub fn PdfAnnotation::no_rotate(self : PdfAnnotation) -> Bool {
  self.common.flags.no_rotate() ||
  self.common.subtype == PdfAnnotationSubtype::Text
}

///|
fn parse_border_style_name(name : @objects.PdfName) -> PdfBorderStyle {
  if name == annotation_key(b"S") {
    Solid
  } else if name == annotation_key(b"D") {
    Dashed
  } else if name == annotation_key(b"B") {
    Beveled
  } else if name == annotation_key(b"I") {
    Inset
  } else if name == annotation_key(b"U") {
    Underline
  } else {
    Unknown(name)
  }
}

///|
fn parse_border_effect_style(name : @objects.PdfName) -> PdfBorderEffectStyle {
  if name == annotation_key(b"S") {
    None
  } else if name == annotation_key(b"C") {
    Cloudy
  } else {
    Unknown(name)
  }
}

///|
fn parse_border_effect(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfBorderEffect raise PdfDocumentError {
  let style = match dict.get(annotation_key(b"S")) {
    Some(value) =>
      parse_border_effect_style(annotation_name(value, owner, "BE S"))
    None => PdfBorderEffectStyle::None
  }
  let intensity = match dict.get(annotation_key(b"I")) {
    Some(value) => {
      let number = annotation_number(value, owner, "BE I")
      if number < 0.0 || number > 2.0 {
        raise annotation_error(owner, "BE I must be in 0..2")
      }
      number
    }
    None => 0.0
  }
  PdfBorderEffect::{ style, intensity, raw_dict: dict }
}

///|
fn parse_dash_pattern(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[Double] raise PdfDocumentError {
  let values = annotation_array(value, owner, label)
  if values.length() == 0 {
    raise annotation_error(owner, label + " must not be empty")
  }
  let pattern : Array[Double] = []
  for item in values {
    let number = annotation_number(item, owner, label)
    if number < 0.0 {
      raise annotation_error(owner, label + " values must not be negative")
    }
    pattern.push(number)
  }
  pattern
}

///|
fn parse_annotation_border(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfAnnotationBorder raise PdfDocumentError {
  let effect = match dict.get(annotation_key(b"BE")) {
    Some(@objects.PdfObject::Dictionary(be)) =>
      Some(parse_border_effect(be, owner))
    Some(_) => raise annotation_error(owner, "BE must be a dictionary")
    None => None
  }
  match dict.get(annotation_key(b"BS")) {
    Some(@objects.PdfObject::Dictionary(bs)) => {
      let width = match bs.get(annotation_key(b"W")) {
        Some(value) => annotation_number(value, owner, "BS W")
        None => 1.0
      }
      let style = match bs.get(annotation_key(b"S")) {
        Some(value) =>
          parse_border_style_name(annotation_name(value, owner, "BS S"))
        None => Solid
      }
      let dash_pattern = match bs.get(annotation_key(b"D")) {
        Some(value) => parse_dash_pattern(value, owner, "BS D")
        None => [3.0]
      }
      PdfAnnotationBorder::{
        horizontal_corner_radius: 0.0,
        vertical_corner_radius: 0.0,
        width,
        dash_pattern,
        style,
        effect,
        raw_border: dict.get(annotation_key(b"Border")),
        raw_style: Some(bs),
      }
    }
    Some(_) => raise annotation_error(owner, "BS must be a dictionary")
    None =>
      match dict.get(annotation_key(b"Border")) {
        Some(value) => {
          let values = annotation_array(value, owner, "Border")
          if values.length() < 3 || values.length() > 4 {
            raise annotation_error(
              owner, "Border must contain three or four entries",
            )
          }
          let dash_pattern = if values.length() == 4 {
            parse_dash_pattern(values[3], owner, "Border dash")
          } else {
            []
          }
          PdfAnnotationBorder::{
            horizontal_corner_radius: annotation_number(
              values[0],
              owner,
              "Border",
            ),
            vertical_corner_radius: annotation_number(
              values[1],
              owner,
              "Border",
            ),
            width: annotation_number(values[2], owner, "Border"),
            dash_pattern,
            style: Solid,
            effect,
            raw_border: Some(value),
            raw_style: None,
          }
        }
        None =>
          PdfAnnotationBorder::{
            horizontal_corner_radius: 0.0,
            vertical_corner_radius: 0.0,
            width: 1.0,
            dash_pattern: [],
            style: Solid,
            effect,
            raw_border: None,
            raw_style: None,
          }
      }
  }
}

///|
fn parse_appearance_entry(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfAppearanceEntry raise PdfDocumentError {
  let resolved = resolve_annotation_direct(file, value, owner, label)
  match resolved {
    @objects.PdfObject::Stream(stream) => Stream(stream)
    @objects.PdfObject::Dictionary(dict) => {
      dict.each((_, state_value) => {
        match resolve_annotation_direct(file, state_value, owner, label) {
          @objects.PdfObject::Stream(_) => ()
          _ => raise annotation_error(owner, label + " state must be a stream")
        }
      })
      StateMap(dict)
    }
    _ =>
      raise annotation_error(owner, label + " must be a stream or dictionary")
  }
}

///|
fn parse_annotation_appearance(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfAnnotationAppearance? raise PdfDocumentError {
  match dict.get(annotation_key(b"AP")) {
    Some(@objects.PdfObject::Dictionary(ap)) =>
      match ap.get(annotation_key(b"N")) {
        Some(normal_value) => {
          let normal = parse_appearance_entry(file, normal_value, owner, "AP N")
          let rollover = match ap.get(annotation_key(b"R")) {
            Some(value) => parse_appearance_entry(file, value, owner, "AP R")
            None => normal
          }
          let down = match ap.get(annotation_key(b"D")) {
            Some(value) => parse_appearance_entry(file, value, owner, "AP D")
            None => normal
          }
          Some(PdfAnnotationAppearance::{
            normal,
            rollover,
            down,
            selected_state: annotation_optional_name(
              dict,
              annotation_key(b"AS"),
              owner,
              "AS",
            ),
            raw_dict: ap,
          })
        }
        None => raise annotation_error(owner, "AP dictionary is missing N")
      }
    Some(_) => raise annotation_error(owner, "AP must be a dictionary")
    None => None
  }
}

///|
fn parse_markup_state_model(name : @objects.PdfName) -> PdfAnnotationStateModel {
  if name == annotation_key(b"Marked") {
    Marked
  } else if name == annotation_key(b"Review") {
    Review
  } else {
    Unknown(name)
  }
}

///|
fn parse_markup_state(name : @objects.PdfName) -> PdfAnnotationState {
  if name == annotation_key(b"Marked") {
    Marked
  } else if name == annotation_key(b"Unmarked") {
    Unmarked
  } else if name == annotation_key(b"Accepted") {
    Accepted
  } else if name == annotation_key(b"Rejected") {
    Rejected
  } else if name == annotation_key(b"Cancelled") {
    Cancelled
  } else if name == annotation_key(b"Completed") {
    Completed
  } else if name == annotation_key(b"None") {
    None
  } else {
    Unknown(name)
  }
}

///|
fn parse_markup_external_data(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfMarkupExternalData raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) =>
      PdfMarkupExternalData::{
        subtype: annotation_optional_name(
          dict,
          annotation_key(b"Subtype"),
          owner,
          "ExData Subtype",
        ),
        raw_dict: dict,
      }
    _ => raise annotation_error(owner, "ExData must be a dictionary")
  }
}

///|
fn is_markup_subtype(subtype : PdfAnnotationSubtype) -> Bool {
  match subtype {
    Text
    | FreeText
    | Line
    | Square
    | Circle
    | Polygon
    | PolyLine
    | Highlight
    | Underline
    | Squiggly
    | StrikeOut
    | Caret
    | Stamp
    | Ink
    | FileAttachment
    | Sound
    | Redact
    | Projection => true
    _ => false
  }
}

///|
fn parse_markup_annotation(
  dict : @objects.PdfDictionary,
  subtype : PdfAnnotationSubtype,
  owner : @objects.ObjectId?,
) -> PdfMarkupAnnotation? raise PdfDocumentError {
  if !is_markup_subtype(subtype) {
    return None
  }
  let external_data = match dict.get(annotation_key(b"ExData")) {
    Some(value) => Some(parse_markup_external_data(value, owner))
    None => None
  }
  let state_model = match dict.get(annotation_key(b"StateModel")) {
    Some(value) =>
      Some(
        parse_markup_state_model(annotation_name(value, owner, "StateModel")),
      )
    None => None
  }
  let state = match dict.get(annotation_key(b"State")) {
    Some(value) =>
      Some(parse_markup_state(annotation_name(value, owner, "State")))
    None => None
  }
  match dict.get(annotation_key(b"IRT")) {
    Some(_) =>
      match dict.get(annotation_key(b"RT")) {
        Some(@objects.PdfObject::Name(_)) | None => ()
        Some(_) => raise annotation_error(owner, "RT must be a name")
      }
    None =>
      match dict.get(annotation_key(b"RT")) {
        Some(_) => raise annotation_error(owner, "RT requires IRT")
        None => ()
      }
  }
  Some(PdfMarkupAnnotation::{
    title: annotation_optional_string(dict, annotation_key(b"T"), owner, "T"),
    popup: dict.get(annotation_key(b"Popup")),
    rich_contents: annotation_optional_string(
      dict,
      annotation_key(b"RC"),
      owner,
      "RC",
    ),
    creation_date: dict.get(annotation_key(b"CreationDate")),
    in_reply_to: dict.get(annotation_key(b"IRT")),
    reply_type: annotation_optional_name(
      dict,
      annotation_key(b"RT"),
      owner,
      "RT",
    ),
    subject: annotation_optional_string(
      dict,
      annotation_key(b"Subj"),
      owner,
      "Subj",
    ),
    intent: annotation_optional_name(dict, annotation_key(b"IT"), owner, "IT"),
    external_data,
    state,
    state_model,
  })
}

///|
fn parse_annotation_common(
  file : PdfFile,
  page : PdfPage,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> PdfAnnotationCommon raise PdfDocumentError {
  match dict.get(annotation_key(b"Type")) {
    Some(@objects.PdfObject::Name(name)) =>
      if name != annotation_key(b"Annot") {
        raise annotation_error(object_id, "Type must be Annot")
      }
    Some(_) => raise annotation_error(object_id, "Type must be a name")
    None => ()
  }
  let subtype_name = match dict.get(annotation_key(b"Subtype")) {
    Some(value) => annotation_name(value, object_id, "Subtype")
    None => raise annotation_error(object_id, "Subtype is required")
  }
  let rect = match dict.get(annotation_key(b"Rect")) {
    Some(value) => annotation_rectangle(value, object_id, "Rect")
    None => raise annotation_error(object_id, "Rect is required")
  }
  let page_ref = match dict.get(annotation_key(b"P")) {
    Some(@objects.PdfObject::Ref(id)) => Some(id)
    Some(_) =>
      raise annotation_error(object_id, "P must be an indirect reference")
    None => None
  }
  let _ = page
  PdfAnnotationCommon::{
    subtype: parse_subtype_name(subtype_name),
    subtype_name,
    rect,
    contents: annotation_optional_string(
      dict,
      annotation_key(b"Contents"),
      object_id,
      "Contents",
    ),
    page_ref,
    name: annotation_optional_string(
      dict,
      annotation_key(b"NM"),
      object_id,
      "NM",
    ),
    modified: dict.get(annotation_key(b"M")),
    flags: parse_annotation_flags(dict, object_id),
    appearance: parse_annotation_appearance(file, dict, object_id),
    appearance_state: annotation_optional_name(
      dict,
      annotation_key(b"AS"),
      object_id,
      "AS",
    ),
    border: parse_annotation_border(dict, object_id),
    color: annotation_optional_color(dict, annotation_key(b"C"), object_id, "C"),
    struct_parent: match dict.get(annotation_key(b"StructParent")) {
      Some(value) => Some(annotation_int(value, object_id, "StructParent"))
      None => None
    },
    optional_content: dict.get(annotation_key(b"OC")),
    additional_actions: dict.get(annotation_key(b"AA")),
    associated_files: match dict.get(annotation_key(b"AF")) {
      Some(value) => annotation_array(value, object_id, "AF")
      None => []
    },
    nonstroking_opacity: annotation_opacity(
      dict,
      annotation_key(b"ca"),
      object_id,
      "ca",
    ),
    stroking_opacity: annotation_opacity(
      dict,
      annotation_key(b"CA"),
      object_id,
      "CA",
    ),
    blend_mode: annotation_optional_name(
      dict,
      annotation_key(b"BM"),
      object_id,
      "BM",
    ),
    language: annotation_optional_string(
      dict,
      annotation_key(b"Lang"),
      object_id,
      "Lang",
    ),
    raw_dict: dict,
  }
}

///|
fn required_raw(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfObject raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => value
    None => raise annotation_error(owner, label + " is required")
  }
}

///|
fn parse_mk(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfWidgetAppearanceCharacteristics? raise PdfDocumentError {
  match dict.get(annotation_key(b"MK")) {
    Some(@objects.PdfObject::Dictionary(mk)) =>
      Some(PdfWidgetAppearanceCharacteristics::{
        rotation: match mk.get(annotation_key(b"R")) {
          Some(value) => annotation_int(value, owner, "MK R")
          None => 0
        },
        border_color: annotation_optional_color(
          mk,
          annotation_key(b"BC"),
          owner,
          "MK BC",
        ),
        background_color: annotation_optional_color(
          mk,
          annotation_key(b"BG"),
          owner,
          "MK BG",
        ),
        normal_caption: annotation_optional_string(
          mk,
          annotation_key(b"CA"),
          owner,
          "MK CA",
        ),
        rollover_caption: annotation_optional_string(
          mk,
          annotation_key(b"RC"),
          owner,
          "MK RC",
        ),
        alternate_caption: annotation_optional_string(
          mk,
          annotation_key(b"AC"),
          owner,
          "MK AC",
        ),
        normal_icon: mk.get(annotation_key(b"I")),
        rollover_icon: mk.get(annotation_key(b"RI")),
        alternate_icon: mk.get(annotation_key(b"IX")),
        icon_fit: mk.get(annotation_key(b"IF")),
        text_position: match mk.get(annotation_key(b"TP")) {
          Some(value) => annotation_int(value, owner, "MK TP")
          None => 0
        },
        raw_dict: mk,
      })
    Some(_) => raise annotation_error(owner, "MK must be a dictionary")
    None => None
  }
}

///|
fn parse_fixed_print(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfFixedPrint raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => {
      let matrix = match dict.get(annotation_key(b"Matrix")) {
        Some(@objects.PdfObject::Array(values)) => {
          if values.length() != 6 {
            raise annotation_error(
              owner, "FixedPrint Matrix must contain six numbers",
            )
          }
          let numbers : Array[Double] = []
          for item in values {
            numbers.push(annotation_number(item, owner, "FixedPrint Matrix"))
          }
          numbers
        }
        Some(_) =>
          raise annotation_error(owner, "FixedPrint Matrix must be an array")
        None => [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
      }
      PdfFixedPrint::{
        matrix,
        horizontal_translation: match dict.get(annotation_key(b"H")) {
          Some(item) => annotation_number(item, owner, "FixedPrint H")
          None => 0.0
        },
        vertical_translation: match dict.get(annotation_key(b"V")) {
          Some(item) => annotation_number(item, owner, "FixedPrint V")
          None => 0.0
        },
        raw_dict: dict,
      }
    }
    _ => raise annotation_error(owner, "FixedPrint must be a dictionary")
  }
}

///|
fn parse_annotation_specific(
  _file : PdfFile,
  _page : PdfPage,
  common : PdfAnnotationCommon,
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfAnnotationSpecific raise PdfDocumentError {
  match common.subtype {
    Text =>
      Text(PdfTextAnnotation::{
        open: annotation_optional_bool(
          dict,
          annotation_key(b"Open"),
          owner,
          "Open",
          false,
        ),
        icon_name: match
          annotation_optional_name(dict, annotation_key(b"Name"), owner, "Name") {
          Some(name) => name
          None => annotation_key(b"Note")
        },
      })
    Link =>
      Link(PdfLinkAnnotation::{
        action: dict.get(annotation_key(b"A")),
        previous_uri_action: dict.get(annotation_key(b"PA")),
        destination: dict.get(annotation_key(b"Dest")),
        highlight_mode: parse_highlight_mode(dict, owner),
        quad_points: parse_optional_quad_points(
          dict,
          annotation_key(b"QuadPoints"),
          owner,
        ),
      })
    FreeText =>
      FreeText(PdfFreeTextAnnotation::{
        default_appearance: match dict.get(annotation_key(b"DA")) {
          Some(value) => annotation_string(value, owner, "DA")
          None => raise annotation_error(owner, "DA is required")
        },
        justification: parse_justification(dict, owner),
        rich_text: annotation_optional_string(
          dict,
          annotation_key(b"RC"),
          owner,
          "RC",
        ),
        default_style: annotation_optional_string(
          dict,
          annotation_key(b"DS"),
          owner,
          "DS",
        ),
        callout: match dict.get(annotation_key(b"CL")) {
          Some(value) => Some(parse_callout(value, owner))
          None => None
        },
        intent: match
          annotation_optional_name(dict, annotation_key(b"IT"), owner, "IT") {
          Some(name) => name
          None => annotation_key(b"FreeText")
        },
        border_effect: common.border.effect,
        difference_rectangle: parse_optional_rectangle(
          dict,
          annotation_key(b"RD"),
          owner,
          "RD",
        ),
      })
    Line =>
      Line(PdfLineAnnotation::{
        coordinates: parse_line_coordinates(
          required_raw(dict, annotation_key(b"L"), owner, "L"),
          owner,
        ),
        line_endings: parse_line_endings(dict, owner),
        interior_color: annotation_optional_color(
          dict,
          annotation_key(b"IC"),
          owner,
          "IC",
        ),
        leader_line_length: match dict.get(annotation_key(b"LL")) {
          Some(value) => annotation_number(value, owner, "LL")
          None => 0.0
        },
        leader_line_extension: match dict.get(annotation_key(b"LLE")) {
          Some(value) => annotation_number(value, owner, "LLE")
          None => 0.0
        },
        leader_line_offset: match dict.get(annotation_key(b"LLO")) {
          Some(value) => annotation_number(value, owner, "LLO")
          None => 0.0
        },
        caption: annotation_optional_bool(
          dict,
          annotation_key(b"Cap"),
          owner,
          "Cap",
          false,
        ),
        intent: annotation_optional_name(
          dict,
          annotation_key(b"IT"),
          owner,
          "IT",
        ),
        measure: dict.get(annotation_key(b"Measure")),
        caption_offset: match dict.get(annotation_key(b"CO")) {
          Some(value) => {
            let points = annotation_points_from_array(value, owner, "CO")
            if points.length() != 1 {
              raise annotation_error(owner, "CO must contain two numbers")
            }
            Some(points[0])
          }
          None => None
        },
      })
    Square =>
      Shape(PdfShapeAnnotation::{
        kind: PdfShapeKind::Square,
        interior_color: annotation_optional_color(
          dict,
          annotation_key(b"IC"),
          owner,
          "IC",
        ),
        border_effect: common.border.effect,
        difference_rectangle: parse_optional_rectangle(
          dict,
          annotation_key(b"RD"),
          owner,
          "RD",
        ),
      })
    Circle =>
      Shape(PdfShapeAnnotation::{
        kind: PdfShapeKind::Circle,
        interior_color: annotation_optional_color(
          dict,
          annotation_key(b"IC"),
          owner,
          "IC",
        ),
        border_effect: common.border.effect,
        difference_rectangle: parse_optional_rectangle(
          dict,
          annotation_key(b"RD"),
          owner,
          "RD",
        ),
      })
    Polygon | PolyLine => {
      let vertices = match dict.get(annotation_key(b"Vertices")) {
        Some(value) => annotation_points_from_array(value, owner, "Vertices")
        None => []
      }
      let paths = match dict.get(annotation_key(b"Path")) {
        Some(value) => parse_path_array(value, owner, "Path")
        None => []
      }
      if vertices.length() == 0 && paths.length() == 0 {
        raise annotation_error(owner, "Vertices or Path is required")
      }
      if vertices.length() > 0 && paths.length() > 0 {
        raise annotation_error(
          owner, "Vertices and Path are mutually exclusive",
        )
      }
      Polygon(PdfPolygonAnnotation::{
        kind: if common.subtype == PdfAnnotationSubtype::Polygon {
          PdfPolygonKind::Polygon
        } else {
          PdfPolygonKind::PolyLine
        },
        vertices,
        path: paths,
        line_endings: parse_line_endings(dict, owner),
        interior_color: annotation_optional_color(
          dict,
          annotation_key(b"IC"),
          owner,
          "IC",
        ),
        intent: annotation_optional_name(
          dict,
          annotation_key(b"IT"),
          owner,
          "IT",
        ),
        measure: dict.get(annotation_key(b"Measure")),
      })
    }
    Highlight | Underline | Squiggly | StrikeOut => {
      let kind = match common.subtype {
        Highlight => PdfTextMarkupKind::Highlight
        Underline => PdfTextMarkupKind::Underline
        Squiggly => PdfTextMarkupKind::Squiggly
        _ => PdfTextMarkupKind::StrikeOut
      }
      TextMarkup(PdfTextMarkupAnnotation::{
        kind,
        quad_points: parse_quad_points(
          required_raw(dict, annotation_key(b"QuadPoints"), owner, "QuadPoints"),
          owner,
          "QuadPoints",
        ),
      })
    }
    Caret =>
      Caret(PdfCaretAnnotation::{
        difference_rectangle: parse_optional_rectangle(
          dict,
          annotation_key(b"RD"),
          owner,
          "RD",
        ),
        symbol: match
          annotation_optional_name(dict, annotation_key(b"Sy"), owner, "Sy") {
          Some(name) => name
          None => annotation_key(b"None")
        },
      })
    Stamp => {
      let icon_name = match
        annotation_optional_name(dict, annotation_key(b"Name"), owner, "Name") {
        Some(name) => name
        None => annotation_key(b"Draft")
      }
      let intent = match
        annotation_optional_name(dict, annotation_key(b"IT"), owner, "IT") {
        Some(name) => name
        None => annotation_key(b"Stamp")
      }
      if dict.get(annotation_key(b"Name")) is Some(_) &&
        intent != annotation_key(b"Stamp") &&
        intent != annotation_key(b"StampImage") &&
        intent != annotation_key(b"StampSnapshot") {
        raise annotation_error(owner, "Name is only valid with stamp intents")
      }
      Stamp(PdfStampAnnotation::{ icon_name, intent })
    }
    Ink => {
      let ink_list = match dict.get(annotation_key(b"InkList")) {
        Some(value) => parse_path_array(value, owner, "InkList")
        None => []
      }
      let paths = match dict.get(annotation_key(b"Path")) {
        Some(value) => parse_path_array(value, owner, "Path")
        None => []
      }
      if ink_list.length() == 0 && paths.length() == 0 {
        raise annotation_error(owner, "InkList or Path is required")
      }
      Ink(PdfInkAnnotation::{ ink_list, paths })
    }
    Popup =>
      Popup(PdfPopupAnnotation::{
        parent: dict.get(annotation_key(b"Parent")),
        open: annotation_optional_bool(
          dict,
          annotation_key(b"Open"),
          owner,
          "Open",
          false,
        ),
      })
    FileAttachment =>
      FileAttachment(PdfFileAttachmentAnnotation::{
        file_specification: required_raw(
          dict,
          annotation_key(b"FS"),
          owner,
          "FS",
        ),
        icon_name: match
          annotation_optional_name(dict, annotation_key(b"Name"), owner, "Name") {
          Some(name) => name
          None => annotation_key(b"PushPin")
        },
      })
    Sound =>
      Sound(PdfSoundAnnotation::{
        sound: required_raw(dict, annotation_key(b"Sound"), owner, "Sound"),
        icon_name: match
          annotation_optional_name(dict, annotation_key(b"Name"), owner, "Name") {
          Some(name) => name
          None => annotation_key(b"Speaker")
        },
      })
    Movie =>
      Movie(PdfMovieAnnotation::{
        title: annotation_optional_string(
          dict,
          annotation_key(b"T"),
          owner,
          "T",
        ),
        movie: required_raw(dict, annotation_key(b"Movie"), owner, "Movie"),
        activation: dict.get(annotation_key(b"A")),
      })
    Screen =>
      Screen(PdfScreenAnnotation::{
        title: annotation_optional_string(
          dict,
          annotation_key(b"T"),
          owner,
          "T",
        ),
        action: dict.get(annotation_key(b"A")),
        additional_actions: dict.get(annotation_key(b"AA")),
        appearance_characteristics: parse_mk(dict, owner),
      })
    Widget =>
      Widget(PdfWidgetAnnotation::{
        highlight_mode: parse_highlight_mode(dict, owner),
        action: dict.get(annotation_key(b"A")),
        additional_actions: dict.get(annotation_key(b"AA")),
        border_style: parse_annotation_border(dict, owner),
        parent: dict.get(annotation_key(b"Parent")),
        appearance_characteristics: parse_mk(dict, owner),
      })
    PrinterMark =>
      PrinterMark(PdfPrinterMarkAnnotation::{
        production_mark: dict.get(annotation_key(b"PMD")),
      })
    TrapNet => TrapNetwork(PdfTrapNetworkAnnotation::{ raw_dict: dict })
    Watermark =>
      Watermark(PdfWatermarkAnnotation::{
        fixed_print: match dict.get(annotation_key(b"FixedPrint")) {
          Some(value) => Some(parse_fixed_print(value, owner))
          None => None
        },
      })
    Redact => {
      let overlay_text = annotation_optional_string(
        dict,
        annotation_key(b"OverlayText"),
        owner,
        "OverlayText",
      )
      let default_appearance = annotation_optional_string(
        dict,
        annotation_key(b"DA"),
        owner,
        "DA",
      )
      if overlay_text is Some(_) && default_appearance is None {
        raise annotation_error(
          owner, "DA is required when OverlayText is present",
        )
      }
      Redaction(PdfRedactionAnnotation::{
        quad_points: parse_optional_quad_points(
          dict,
          annotation_key(b"QuadPoints"),
          owner,
        ),
        interior_color: annotation_optional_color(
          dict,
          annotation_key(b"IC"),
          owner,
          "IC",
        ),
        overlay: dict.get(annotation_key(b"RO")),
        overlay_text,
        repeat: annotation_optional_bool(
          dict,
          annotation_key(b"Repeat"),
          owner,
          "Repeat",
          false,
        ),
        default_appearance,
        justification: parse_justification(dict, owner),
      })
    }
    Projection =>
      Projection(PdfProjectionAnnotation::{
        external_data: match dict.get(annotation_key(b"ExData")) {
          Some(value) => Some(parse_markup_external_data(value, owner))
          None => None
        },
      })
    ThreeD =>
      ThreeDRaw(PdfRawAnnotation::{
        subtype_name: common.subtype_name,
        raw_dict: dict,
      })
    RichMedia =>
      RichMediaRaw(PdfRawAnnotation::{
        subtype_name: common.subtype_name,
        raw_dict: dict,
      })
    Unknown(_) =>
      UnknownRaw(PdfRawAnnotation::{
        subtype_name: common.subtype_name,
        raw_dict: dict,
      })
  }
}

///|
fn parse_page_annotation(
  page : PdfPage,
  object_id : @objects.ObjectId?,
  array_index : Int,
  dict : @objects.PdfDictionary,
) -> PdfAnnotation raise PdfDocumentError {
  let common = parse_annotation_common(page.file, page, object_id, dict)
  PdfAnnotation::{
    page_index: page.index(),
    array_index,
    object_id,
    common,
    markup: parse_markup_annotation(dict, common.subtype, object_id),
    specific: parse_annotation_specific(
      page.file,
      page,
      common,
      dict,
      object_id,
    ),
    raw_dict: dict,
  }
}

///|
/// Parses the page Annots array from ISO 32000-2 12.5.1 and 12.5.2 into
/// typed annotations. Missing Annots returns an empty array; present Annots
/// must be an array of direct or indirect annotation dictionaries, preserving
/// annotation array order and page-local positions. Text annotation replies
/// may also carry State and StateModel values from Table 174.
pub fn PdfPage::annotations(
  self : PdfPage,
) -> Array[PdfAnnotation] raise PdfDocumentError {
  let value = match self.annots() {
    Some(value) =>
      resolve_annotation_direct(
        self.file,
        value,
        Some(self.object_id()),
        "Page Annots",
      )
    None => return []
  }
  let entries = match value {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise annotation_error(Some(self.object_id()), "Annots must be an array")
  }
  let annotations : Array[PdfAnnotation] = []
  let mut index = 0
  let mut trap_network_count = 0
  for entry in entries {
    let source_id = match entry {
      @objects.PdfObject::Ref(id) => Some(id)
      _ => None
    }
    let dict = resolve_annotation_dictionary(
      self.file,
      entry,
      source_id,
      "annotation entry",
    )
    let annotation = parse_page_annotation(self, source_id, index, dict)
    if annotation.common.subtype == PdfAnnotationSubtype::TrapNet {
      trap_network_count = trap_network_count + 1
      if trap_network_count > 1 {
        raise annotation_error(
          source_id, "page may contain only one TrapNet annotation",
        )
      }
      if index != entries.length() - 1 {
        raise annotation_error(
          source_id, "TrapNet annotation must be the final Annots entry",
        )
      }
    }
    annotations.push(annotation)
    index = index + 1
  }
  annotations
}

///|
/// Enumerates document annotations across pages and validates ISO 32000-2
/// 12.5.2 ownership: a given indirect annotation dictionary shall be
/// referenced from the Annots array of only one page.
pub fn PdfDocument::annotations(
  self : PdfDocument,
) -> Array[PdfAnnotation] raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Int] = Map::new()
  let annotations : Array[PdfAnnotation] = []
  for page in self.pages() {
    for annotation in page.annotations() {
      match annotation.object_id {
        Some(id) =>
          match seen.get(id) {
            Some(page_index) =>
              if page_index != page.index() {
                raise annotation_error(
                  Some(id),
                  "indirect annotation is referenced from multiple pages",
                )
              }
            None => seen[id] = page.index()
          }
        None => ()
      }
      annotations.push(annotation)
    }
  }
  annotations
}

///|
/// Parses the page Tabs entry described by ISO 32000-2 12.5.1 "General".
/// R row order, C column order, S structure order, A annotation array order,
/// and W widgets order are reported without computing interactive focus order.
pub fn PdfPage::annotation_tab_order(
  self : PdfPage,
) -> PdfAnnotationTabOrder? raise PdfDocumentError {
  match self.entry(annotation_key(b"Tabs")) {
    Some(@objects.PdfObject::Name(name)) =>
      if name == annotation_key(b"R") {
        Some(Row)
      } else if name == annotation_key(b"C") {
        Some(Column)
      } else if name == annotation_key(b"S") {
        Some(Structure)
      } else if name == annotation_key(b"A") {
        Some(AnnotationArray)
      } else if name == annotation_key(b"W") {
        Some(Widget)
      } else {
        Some(Unknown(name))
      }
    Some(_) =>
      raise annotation_error(Some(self.object_id()), "Tabs must be a name")
    None => None
  }
}
