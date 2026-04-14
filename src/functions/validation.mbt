///|
fn pdf_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn object_kind_label(object : @objects.PdfObject) -> String {
  match object {
    @objects.PdfObject::Boolean(_) => "boolean"
    @objects.PdfObject::Integer(_) => "integer"
    @objects.PdfObject::Real(_) => "real"
    @objects.PdfObject::String(_) => "string"
    @objects.PdfObject::Name(_) => "name"
    @objects.PdfObject::Array(_) => "array"
    @objects.PdfObject::Dictionary(_) => "dictionary"
    @objects.PdfObject::Stream(_) => "stream"
    @objects.PdfObject::Null => "null"
    @objects.PdfObject::Ref(_) => "ref"
  }
}

///|
fn function_error(offset : Int64, reason : String) -> PdfFunctionError {
  PdfFunctionError::InvalidFunction(offset, reason)
}

///|
fn missing_required(key : Bytes, offset : Int64) -> PdfFunctionError {
  function_error(offset, "missing required /\{key_label(key)} entry")
}

///|
fn key_label(key : Bytes) -> String {
  if key == b"FunctionType" {
    "FunctionType"
  } else if key == b"Domain" {
    "Domain"
  } else if key == b"Range" {
    "Range"
  } else {
    key.to_string()
  }
}

///|
fn required_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> @objects.PdfObject raise PdfFunctionError {
  match dict.get(pdf_name(key)) {
    Some(value) => value
    None => raise missing_required(key, offset)
  }
}

///|
fn optional_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> @objects.PdfObject? {
  dict.get(pdf_name(key))
}

///|
fn require_integer_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Int64 raise PdfFunctionError {
  match object {
    @objects.PdfObject::Integer(value) => value
    _ =>
      raise function_error(
        offset,
        "\{label} must be an integer, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_number_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfFunctionError {
  let value = match object {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise function_error(
        offset,
        "\{label} must be a number, got \{object_kind_label(object)}",
      )
  }
  ensure_finite(value, offset, label)
  value
}

///|
fn require_array_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[@objects.PdfObject] raise PdfFunctionError {
  match object {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise function_error(
        offset,
        "\{label} must be an array, got \{object_kind_label(object)}",
      )
  }
}

///|
fn ensure_finite(
  value : Double,
  offset : Int64,
  label : String,
) -> Unit raise PdfFunctionError {
  if value.is_nan() || value.is_inf() {
    raise function_error(offset, "\{label} must be finite")
  }
}

///|
pub fn FunctionInterval::new(
  min : Double,
  max : Double,
  offset? : Int64 = 0L,
) -> FunctionInterval raise PdfFunctionError {
  ensure_finite(min, offset, "interval minimum")
  ensure_finite(max, offset, "interval maximum")
  if min > max {
    raise function_error(
      offset, "interval minimum must be less than or equal to maximum",
    )
  }
  FunctionInterval::{ min, max }
}

///|
pub fn FunctionInterval::clip(
  self : FunctionInterval,
  value : Double,
) -> Double {
  if value < self.min {
    self.min
  } else if value > self.max {
    self.max
  } else {
    value
  }
}

///|
pub fn interpolate(
  value : Double,
  input : FunctionInterval,
  output : FunctionInterval,
) -> Double {
  if input.min == input.max {
    output.min
  } else {
    output.min +
    (value - input.min) * (output.max - output.min) / (input.max - input.min)
  }
}

///|
fn parse_function_type(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> FunctionType raise PdfFunctionError {
  let raw = require_integer_value(
    required_entry(dict, b"FunctionType", offset),
    offset,
    "FunctionType",
  )
  match raw {
    0L => Sampled
    2L => Exponential
    3L => Stitching
    4L => Calculator
    _ => raise function_error(offset, "unsupported FunctionType \{raw}")
  }
}

///|
fn require_numeric_array(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[Double] raise PdfFunctionError {
  let raw = require_array_value(object, offset, label)
  let values : Array[Double] = []
  for value in raw {
    values.push(require_number_value(value, offset, label))
  }
  values
}

///|
fn intervals_from_numbers(
  values : Array[Double],
  label : String,
  offset : Int64,
  dimension_limit : Int,
) -> Array[FunctionInterval] raise PdfFunctionError {
  if values.length() == 0 || values.length() % 2 != 0 {
    raise function_error(offset, "\{label} must contain pairs of numbers")
  }
  let count = values.length() / 2
  check_limit(label, count, dimension_limit)
  let intervals : Array[FunctionInterval] = []
  for index in 0..<count {
    intervals.push(
      FunctionInterval::new(values[index * 2], values[index * 2 + 1], offset~),
    )
  }
  intervals
}

///|
fn parse_required_intervals(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  dimension_limit : Int,
) -> Array[FunctionInterval] raise PdfFunctionError {
  intervals_from_numbers(
    require_numeric_array(
      required_entry(dict, key, offset),
      offset,
      key_label(key),
    ),
    key_label(key),
    offset,
    dimension_limit,
  )
}

///|
fn parse_optional_intervals(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  dimension_limit : Int,
) -> Array[FunctionInterval]? raise PdfFunctionError {
  match optional_entry(dict, key) {
    Some(value) =>
      Some(
        intervals_from_numbers(
          require_numeric_array(value, offset, key_label(key)),
          key_label(key),
          offset,
          dimension_limit,
        ),
      )
    None => None
  }
}

///|
fn parse_function_common(
  dict : @objects.PdfDictionary,
  limits : FunctionLimits,
  offset : Int64,
) -> FunctionCommon raise PdfFunctionError {
  FunctionCommon::{
    domain: parse_required_intervals(
      dict,
      b"Domain",
      offset,
      limits.max_input_dimensions,
    ),
    range: parse_optional_intervals(
      dict,
      b"Range",
      offset,
      limits.max_output_dimensions,
    ),
  }
}

///|
fn require_range(
  common : FunctionCommon,
  offset : Int64,
  function_type : String,
) -> Array[FunctionInterval] raise PdfFunctionError {
  match common.range {
    Some(range) => range
    None =>
      raise function_error(offset, "\{function_type} functions require Range")
  }
}
