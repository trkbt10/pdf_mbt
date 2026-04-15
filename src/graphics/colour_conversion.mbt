///|
/// Device RGB colour components in additive form. Values are normalized to the
/// PDF device component interval 0.0..1.0 by conversion helpers.
pub(all) struct DeviceRgbColour {
  red : Double
  green : Double
  blue : Double
} derive(Eq, Debug)

///|
/// Device CMYK colour components in subtractive form. Values are normalized to
/// the PDF device component interval 0.0..1.0 by conversion helpers.
pub(all) struct DeviceCmykColour {
  cyan : Double
  magenta : Double
  yellow : Double
  black : Double
} derive(Eq, Debug)

///|
/// CIE 1931 XYZ tristimulus value with Y normalized to 1.0 at the reference
/// white used by the source colour space.
pub(all) struct CieXyzColour {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
/// Direct scalar function source used by colour conversion policies such as
/// black generation, undercolour removal, transfer functions, and tint
/// transforms. The Identity name is handled without parsing a function object;
/// indirect functions are preserved as unresolved because graphics must not
/// load reader-owned objects.
pub(all) enum ColourTransformFunction {
  IdentityTransformFunction
  DirectTransformFunction(@objects.PdfObject)
  UnresolvedTransformFunction(@objects.ObjectId)
} derive(Eq, Debug)

///|
pub fn device_gray_to_rgb(gray : Double) -> DeviceRgbColour {
  let value = colour_component(gray)
  DeviceRgbColour::{ red: value, green: value, blue: value }
}

///|
pub fn device_rgb_to_cmyk(
  rgb : DeviceRgbColour,
  black_generation? : ColourTransformFunction = IdentityTransformFunction,
  undercolour_removal? : ColourTransformFunction = IdentityTransformFunction,
  offset? : Int64 = 0L,
) -> DeviceCmykColour raise PdfGraphicsError {
  let c = 1.0 - colour_component(rgb.red)
  let m = 1.0 - colour_component(rgb.green)
  let y = 1.0 - colour_component(rgb.blue)
  let k = min3(c, m, y)
  let ucr = undercolour_removal.apply_scalar(k, offset~)
  let bg = black_generation.apply_scalar(k, offset~)
  DeviceCmykColour::{
    cyan: colour_component(c - ucr),
    magenta: colour_component(m - ucr),
    yellow: colour_component(y - ucr),
    black: colour_component(bg),
  }
}

///|
pub fn device_cmyk_to_rgb(cmyk : DeviceCmykColour) -> DeviceRgbColour {
  let c = colour_component(cmyk.cyan)
  let m = colour_component(cmyk.magenta)
  let y = colour_component(cmyk.yellow)
  let k = colour_component(cmyk.black)
  DeviceRgbColour::{
    red: 1.0 - colour_component(c + k),
    green: 1.0 - colour_component(m + k),
    blue: 1.0 - colour_component(y + k),
  }
}

///|
pub fn ColourTransformFunction::apply_scalar(
  self : ColourTransformFunction,
  input : Double,
  offset? : Int64 = 0L,
) -> Double raise PdfGraphicsError {
  let outputs = self.apply([input], 1, offset~)
  outputs[0]
}

///|
pub fn ColourTransformFunction::apply(
  self : ColourTransformFunction,
  inputs : Array[Double],
  expected_outputs : Int,
  offset? : Int64 = 0L,
) -> Array[Double] raise PdfGraphicsError {
  match self {
    IdentityTransformFunction => {
      if inputs.length() != expected_outputs {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "Identity colour function output count does not match input count",
        )
      }
      inputs.copy()
    }
    UnresolvedTransformFunction(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "indirect colour function must be resolved before evaluation",
      )
    DirectTransformFunction(object) =>
      evaluate_direct_colour_function(object, inputs, expected_outputs, offset)
  }
}

///|
fn min3(a : Double, b : Double, c : Double) -> Double {
  let ab = if a < b { a } else { b }
  if ab < c {
    ab
  } else {
    c
  }
}

///|
fn colour_component(value : Double) -> Double {
  clamp_double(value, 0.0, 1.0)
}

///|
fn ColourRange::clip(self : ColourRange, value : Double) -> Double {
  clamp_double(value, self.min, self.max)
}

///|
fn evaluate_direct_colour_function(
  object : @objects.PdfObject,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) =>
      if name == @objects.PdfName::new(b"Identity") {
        ColourTransformFunction::IdentityTransformFunction.apply(
          inputs,
          expected_outputs,
          offset~,
        )
      } else {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "unsupported named colour transform",
        )
      }
    @objects.PdfObject::Dictionary(dict) =>
      evaluate_colour_function_dictionary(
        dict, inputs, expected_outputs, offset,
      )
    @objects.PdfObject::Stream(stream) =>
      evaluate_colour_function_dictionary(
        stream.dict,
        inputs,
        expected_outputs,
        offset,
      )
    @objects.PdfObject::Ref(id) =>
      ColourTransformFunction::UnresolvedTransformFunction(id).apply(
        inputs,
        expected_outputs,
        offset~,
      )
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "colour transform must be a function dictionary, stream, or Identity name",
      )
  }
}

///|
fn evaluate_colour_function_dictionary(
  dict : @objects.PdfDictionary,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let function_type = match dict.get(@objects.PdfName::new(b"FunctionType")) {
    Some(@objects.PdfObject::Integer(value)) => value
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "FunctionType must be an integer",
      )
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "colour transform function requires FunctionType",
      )
  }
  match function_type {
    2L => evaluate_type2_colour_function(dict, inputs, expected_outputs, offset)
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        "colour transform FunctionType " +
        function_type.to_string() +
        " is not supported for direct evaluation",
      )
  }
}

///|
fn evaluate_type2_colour_function(
  dict : @objects.PdfDictionary,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  if inputs.length() != 1 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 2 colour function requires one input",
    )
  }
  let domain = required_interval_array(dict, b"Domain", 1, offset)
  let range = optional_interval_array(dict, b"Range", expected_outputs, offset)
  let c0 = optional_output_array(dict, b"C0", offset)
  let c1 = optional_output_array(dict, b"C1", offset)
  let output_count = infer_type2_output_count(c0, c1, expected_outputs, offset)
  let c0_values = match c0 {
    Some(values) => values
    None => repeat_double(output_count, 0.0)
  }
  let c1_values = match c1 {
    Some(values) => values
    None => repeat_double(output_count, 1.0)
  }
  if c0_values.length() != output_count || c1_values.length() != output_count {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 2 C0 and C1 output counts must match",
    )
  }
  let exponent = match dict.get(@objects.PdfName::new(b"N")) {
    Some(value) => finite_colour_number(value, offset, "Type 2 N")
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Type 2 colour function requires N",
      )
  }
  let x = domain[0].clip(
    finite_double(inputs[0], offset, "colour function input"),
  )
  let factor = finite_double(@math.pow(x, exponent), offset, "Type 2 power")
  let outputs : Array[Double] = []
  for index in 0..<output_count {
    let raw = c0_values[index] + factor * (c1_values[index] - c0_values[index])
    let clipped = match range {
      Some(intervals) => intervals[index].clip(raw)
      None => raw
    }
    outputs.push(finite_double(clipped, offset, "colour function output"))
  }
  outputs
}

///|
fn infer_type2_output_count(
  c0 : Array[Double]?,
  c1 : Array[Double]?,
  expected_outputs : Int,
  offset : Int64,
) -> Int raise PdfGraphicsError {
  let count = match c0 {
    Some(values) => values.length()
    None =>
      match c1 {
        Some(values) => values.length()
        None => expected_outputs
      }
  }
  if count != expected_outputs {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "colour function output count mismatch",
    )
  }
  if count <= 0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "colour function must produce at least one output",
    )
  }
  count
}

///|
fn optional_output_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Array[Double]? raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => None
    Some(value) => Some(numeric_array(value, offset, key.to_string()))
  }
}

///|
fn required_interval_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected_count : Int,
  offset : Int64,
) -> Array[ColourRange] raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(value) =>
      interval_array(value, expected_count, offset, key.to_string())
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        "colour function requires " + @objects.PdfName::new(key).to_text(),
      )
  }
}

///|
fn optional_interval_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected_count : Int,
  offset : Int64,
) -> Array[ColourRange]? raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => None
    Some(value) =>
      Some(interval_array(value, expected_count, offset, key.to_string()))
  }
}

///|
fn interval_array(
  object : @objects.PdfObject,
  expected_count : Int,
  offset : Int64,
  label : String,
) -> Array[ColourRange] raise PdfGraphicsError {
  let values = numeric_array(object, offset, label)
  if values.length() != expected_count * 2 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset,
      label + " must contain interval pairs",
    )
  }
  let intervals : Array[ColourRange] = []
  for index in 0..<expected_count {
    let min = values[index * 2]
    let max = values[index * 2 + 1]
    if min > max {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " lower bound must not exceed upper bound",
      )
    }
    intervals.push(ColourRange::{ min, max })
  }
  intervals
}

///|
fn numeric_array(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[Double] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => {
      let numbers : Array[Double] = []
      for value in values {
        numbers.push(finite_colour_number(value, offset, label))
      }
      numbers
    }
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be an array",
      )
  }
}

///|
fn finite_colour_number(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  finite_double(colour_object_number(object, offset, label), offset, label)
}

///|
fn finite_double(
  value : Double,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  if value.is_nan() || value.is_inf() {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset,
      label + " must be finite",
    )
  }
  value
}

///|
fn repeat_double(count : Int, value : Double) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<count {
    values.push(value)
  }
  values
}
