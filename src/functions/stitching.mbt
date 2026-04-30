///|
fn parse_stitching_function_sources(
  object : @objects.PdfObject,
  limits : FunctionLimits,
  offset : Int64,
) -> Array[FunctionSource] raise PdfFunctionError {
  let raw = require_array_value(object, offset, "Functions")
  if raw.length() == 0 {
    raise function_error(offset, "Type 3 Functions must not be empty")
  }
  let functions : Array[FunctionSource] = []
  for value in raw {
    functions.push(parse_function_object(value, limits, offset))
  }
  functions
}

///|
fn parse_stitching_bounds(
  object : @objects.PdfObject,
  expected_count : Int,
  offset : Int64,
) -> Array[Double] raise PdfFunctionError {
  let bounds = require_numeric_array(object, offset, "Bounds")
  if bounds.length() != expected_count {
    raise function_error(
      offset, "Type 3 Bounds length must be Functions length minus one",
    )
  }
  bounds
}

///|
fn parse_stitching_encode(
  object : @objects.PdfObject,
  function_count : Int,
  offset : Int64,
) -> Array[FunctionInterval] raise PdfFunctionError {
  let values = require_numeric_array(object, offset, "Encode")
  if values.length() != function_count * 2 {
    raise function_error(
      offset, "Type 3 Encode length must be twice the Functions length",
    )
  }
  let encode : Array[FunctionInterval] = []
  for index in 0..<function_count {
    let min = values[index * 2]
    let max = values[index * 2 + 1]
    ensure_finite(min, offset, "Encode")
    ensure_finite(max, offset, "Encode")
    encode.push(FunctionInterval::{ min, max })
  }
  encode
}

///|
fn direct_function_output_count(function : PdfFunction) -> Int? {
  match function {
    SampledFunction(sampled) => sampled.common.output_count()
    ExponentialFunction(exponential) => Some(exponential.c0.length())
    CalculatorFunction(calculator) => calculator.common.output_count()
    StitchingFunction(stitching) => stitching_function_output_count(stitching)
  }
}

///|
fn stitching_function_output_count(function : StitchingFunction) -> Int? {
  match function.common.output_count() {
    Some(count) => Some(count)
    None => {
      let mut count : Int? = None
      for source in function.functions {
        match source {
          DirectFunction(inner) =>
            match direct_function_output_count(inner) {
              Some(output_count) =>
                match count {
                  Some(expected) => if output_count != expected { return None }
                  None => count = Some(output_count)
                }
              None => ()
            }
          IndirectFunction(_) => ()
        }
      }
      count
    }
  }
}

///|
fn validate_stitching_subfunctions(
  functions : Array[FunctionSource],
  common : FunctionCommon,
  offset : Int64,
) -> Unit raise PdfFunctionError {
  let mut expected_output_count : Int? = common.output_count()
  for source in functions {
    match source {
      DirectFunction(function) => {
        if function.common().input_count() != 1 {
          raise function_error(
            offset, "Type 3 subfunctions must take exactly one input",
          )
        }
        match direct_function_output_count(function) {
          Some(output_count) =>
            match expected_output_count {
              Some(expected) =>
                if output_count != expected {
                  raise function_error(
                    offset, "Type 3 subfunction output dimensions are incompatible",
                  )
                }
              None => expected_output_count = Some(output_count)
            }
          None => ()
        }
      }
      IndirectFunction(_) => ()
    }
  }
}

///|
fn validate_stitching_bounds(
  domain : FunctionInterval,
  bounds : Array[Double],
  function_count : Int,
  offset : Int64,
) -> Unit raise PdfFunctionError {
  if function_count > 1 && domain.min >= domain.max {
    raise function_error(
      offset, "Type 3 Domain must be strictly increasing when k is greater than one",
    )
  }
  let mut previous = domain.min
  for index in 0..<bounds.length() {
    let value = bounds[index]
    ensure_finite(value, offset, "Bounds")
    if value < domain.min || value > domain.max {
      raise function_error(
        offset, "Type 3 Bounds values must lie within Domain",
      )
    }
    if index > 0 && value <= previous {
      raise function_error(
        offset, "Type 3 Bounds values must be strictly increasing",
      )
    }
    previous = value
  }
}

///|
fn parse_stitching_function(
  input : DirectFunctionParseInput,
) -> StitchingFunction raise PdfFunctionError {
  if input.common.domain.length() != 1 {
    raise function_error(
      input.offset,
      "Type 3 Domain must contain one input interval",
    )
  }
  let functions = parse_stitching_function_sources(
    required_entry(input.dict, b"Functions", input.offset),
    input.limits,
    input.offset,
  )
  let bounds = parse_stitching_bounds(
    required_entry(input.dict, b"Bounds", input.offset),
    functions.length() - 1,
    input.offset,
  )
  let encode = parse_stitching_encode(
    required_entry(input.dict, b"Encode", input.offset),
    functions.length(),
    input.offset,
  )
  validate_stitching_bounds(
    input.common.domain[0],
    bounds,
    functions.length(),
    input.offset,
  )
  validate_stitching_subfunctions(functions, input.common, input.offset)
  StitchingFunction::{ common: input.common, functions, bounds, encode }
}

///|
fn select_stitching_function(
  function : StitchingFunction,
  value : Double,
) -> Int {
  if function.functions.length() == 1 {
    0
  } else if function.bounds.length() > 0 &&
    function.bounds[0] == function.common.domain[0].min &&
    value == function.common.domain[0].min {
    0
  } else {
    let mut selected = function.functions.length() - 1
    let mut index = 0
    while index < function.bounds.length() {
      if value < function.bounds[index] {
        selected = index
        index = function.bounds.length()
      } else {
        index = index + 1
      }
    }
    selected
  }
}

///|
fn stitching_subdomain(
  function : StitchingFunction,
  index : Int,
) -> FunctionInterval raise PdfFunctionError {
  let domain = function.common.domain[0]
  let min = if index == 0 { domain.min } else { function.bounds[index - 1] }
  let max = if index == function.functions.length() - 1 {
    domain.max
  } else {
    function.bounds[index]
  }
  FunctionInterval::new(min, max)
}

///|
fn evaluate_stitching_function_with_depth(
  function : StitchingFunction,
  clipped_inputs : Array[Double],
  limits : FunctionLimits,
  depth : Int,
) -> Array[Double] raise PdfFunctionError {
  let value = clipped_inputs[0]
  let selected = select_stitching_function(function, value)
  let encoded = interpolate(
    value,
    stitching_subdomain(function, selected),
    function.encode[selected],
  )
  let outputs = evaluate_function_source_with_depth(
    function.functions[selected],
    [encoded],
    limits,
    depth + 1,
  )
  function.common.clip_outputs(outputs)
}
