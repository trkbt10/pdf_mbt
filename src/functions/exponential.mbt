///|
fn coefficient_array_or_default(
  dict : @objects.PdfDictionary,
  key : Bytes,
  output_count : Int,
  default_value : Double,
  offset : Int64,
) -> Array[Double] raise PdfFunctionError {
  match optional_entry(dict, key) {
    Some(object) => {
      let values = require_numeric_array(object, offset, key_label(key))
      if values.length() == 0 {
        raise function_error(offset, "\{key_label(key)} must not be empty")
      }
      values
    }
    None => {
      let values : Array[Double] = []
      for _ in 0..<output_count {
        values.push(default_value)
      }
      values
    }
  }
}

///|
fn optional_coefficient_count(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Int? raise PdfFunctionError {
  match optional_entry(dict, key) {
    Some(object) =>
      Some(require_numeric_array(object, offset, key_label(key)).length())
    None => None
  }
}

///|
fn infer_exponential_output_count(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Int raise PdfFunctionError {
  let c0_count = optional_coefficient_count(dict, b"C0", offset)
  let c1_count = optional_coefficient_count(dict, b"C1", offset)
  let count = match (c0_count, c1_count) {
    (Some(left), Some(right)) => {
      if left != right {
        raise function_error(offset, "Type 2 C0 and C1 lengths must match")
      }
      left
    }
    (Some(left), None) => left
    (None, Some(right)) => right
    (None, None) => 1
  }
  if count <= 0 {
    raise function_error(offset, "Type 2 output count must be positive")
  }
  count
}

///|
fn parse_exponential_function(
  input : DirectFunctionParseInput,
) -> ExponentialFunction raise PdfFunctionError {
  if input.common.domain.length() != 1 {
    raise function_error(
      input.offset,
      "Type 2 functions require exactly one Domain interval",
    )
  }
  let output_count = infer_exponential_output_count(input.dict, input.offset)
  check_limit(
    "Type 2 output dimensions",
    output_count,
    input.limits.max_output_dimensions,
  )
  match input.common.range {
    Some(range) =>
      if range.length() != output_count {
        raise function_error(
          input.offset,
          "Range length must match Type 2 output count",
        )
      }
    None => ()
  }
  ExponentialFunction::{
    common: input.common,
    c0: coefficient_array_or_default(
      input.dict,
      b"C0",
      output_count,
      0.0,
      input.offset,
    ),
    c1: coefficient_array_or_default(
      input.dict,
      b"C1",
      output_count,
      1.0,
      input.offset,
    ),
    exponent: require_number_value(
      required_entry(input.dict, b"N", input.offset),
      input.offset,
      "N",
    ),
  }
}

///|
fn is_integer_double(value : Double) -> Bool {
  @math.floor(value) == value
}

///|
fn evaluate_exponential_function(
  function : ExponentialFunction,
  clipped_inputs : Array[Double],
) -> Array[Double] raise PdfFunctionError {
  let x = clipped_inputs[0]
  if !is_integer_double(function.exponent) && x < 0.0 {
    raise PdfFunctionError::EvaluationFailure(
      0L, "Type 2 non-integer exponent requires non-negative input",
    )
  }
  if function.exponent < 0.0 && x == 0.0 {
    raise PdfFunctionError::EvaluationFailure(
      0L, "Type 2 negative exponent requires non-zero input",
    )
  }
  let factor = @math.pow(x, function.exponent)
  ensure_finite(factor, 0L, "Type 2 power")
  let outputs : Array[Double] = []
  for index in 0..<function.c0.length() {
    outputs.push(
      function.c0[index] + factor * (function.c1[index] - function.c0[index]),
    )
  }
  function.common.clip_outputs(outputs)
}
