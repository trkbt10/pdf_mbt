///|
fn is_supported_sample_width(bits_per_sample : Int) -> Bool {
  bits_per_sample == 1 ||
  bits_per_sample == 2 ||
  bits_per_sample == 4 ||
  bits_per_sample == 8 ||
  bits_per_sample == 12 ||
  bits_per_sample == 16 ||
  bits_per_sample == 24 ||
  bits_per_sample == 32
}

///|
fn parse_positive_int_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Array[Int] raise PdfFunctionError {
  let raw = require_array_value(
    required_entry(dict, key, offset),
    offset,
    key_label(key),
  )
  if raw.length() == 0 {
    raise function_error(offset, "\{key_label(key)} must not be empty")
  }
  let values : Array[Int] = []
  for object in raw {
    let value = require_integer_value(object, offset, key_label(key))
    if value <= 0L {
      raise function_error(
        offset,
        "\{key_label(key)} entries must be positive integers",
      )
    }
    values.push(value.to_int())
  }
  values
}

///|
fn parse_optional_order(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> SampleOrder raise PdfFunctionError {
  match optional_entry(dict, b"Order") {
    Some(object) => {
      let order = require_integer_value(object, offset, "Order")
      match order {
        1L => Linear
        3L => Cubic
        _ => raise function_error(offset, "Order must be 1 or 3")
      }
    }
    None => Linear
  }
}

///|
fn default_encode(
  size : Array[Int],
) -> Array[FunctionInterval] raise PdfFunctionError {
  let encode : Array[FunctionInterval] = []
  for dimension in size {
    encode.push(FunctionInterval::new(0.0, (dimension - 1).to_double()))
  }
  encode
}

///|
fn parse_optional_interval_array_exact(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected_count : Int,
  offset : Int64,
) -> Array[FunctionInterval]? raise PdfFunctionError {
  match optional_entry(dict, key) {
    Some(object) => {
      let intervals = intervals_from_numbers(
        require_numeric_array(object, offset, key_label(key)),
        key_label(key),
        offset,
        expected_count,
      )
      if intervals.length() != expected_count {
        raise function_error(
          offset,
          "\{key_label(key)} must contain \{expected_count} interval pairs",
        )
      }
      Some(intervals)
    }
    None => None
  }
}

///|
fn checked_sample_value_count(
  size : Array[Int],
  output_count : Int,
  limits : FunctionLimits,
  offset : Int64,
) -> Int raise PdfFunctionError {
  let mut count = output_count
  for dimension in size {
    if count > limits.max_sample_values / dimension {
      raise PdfFunctionError::LimitExceeded(
        "sample values",
        limits.max_sample_values + 1,
        limits.max_sample_values,
      )
    }
    count = count * dimension
  }
  check_limit("sample values", count, limits.max_sample_values)
  if count <= 0 {
    raise function_error(offset, "declared sample count must be positive")
  }
  count
}

///|
fn read_sample_table(
  decoded_stream : Bytes,
  bits_per_sample : Int,
  sample_value_count : Int,
  output_count : Int,
  offset : Int64,
) -> SampleTable raise PdfFunctionError {
  let reader = SampleBitReader::new(decoded_stream)
  let values : Array[Double] = []
  for _ in 0..<sample_value_count {
    values.push(reader.read_sample(bits_per_sample, offset))
  }
  SampleTable::{ values, output_count }
}

///|
fn max_encoded_sample_value(bits_per_sample : Int) -> Double {
  if bits_per_sample == 32 {
    4294967295.0
  } else {
    ((1L << bits_per_sample) - 1L).to_double()
  }
}

///|
fn sample_value_at(
  function : SampledFunction,
  sample_index : Int,
  component : Int,
) -> Double {
  function.table.values[sample_index * function.table.output_count + component]
}

///|
fn flattened_sample_index(size : Array[Int], coordinates : Array[Int]) -> Int {
  let mut stride = 1
  let mut index = 0
  for dimension in 0..<size.length() {
    index = index + coordinates[dimension] * stride
    stride = stride * size[dimension]
  }
  index
}

///|
fn encoded_coordinates(
  function : SampledFunction,
  clipped_inputs : Array[Double],
) -> Array[Double] {
  let coordinates : Array[Double] = []
  for dimension in 0..<function.size.length() {
    let encoded = interpolate(
      clipped_inputs[dimension],
      function.common.domain[dimension],
      function.encode[dimension],
    )
    let table_interval = FunctionInterval::{
      min: 0.0,
      max: (function.size[dimension] - 1).to_double(),
    }
    coordinates.push(table_interval.clip(encoded))
  }
  coordinates
}

///|
fn interpolate_linear_component(
  function : SampledFunction,
  coordinates : Array[Double],
  component : Int,
) -> Double {
  let dimensions = function.size.length()
  let lower : Array[Int] = []
  let upper : Array[Int] = []
  let fractions : Array[Double] = []
  for dimension in 0..<dimensions {
    if function.size[dimension] == 1 {
      lower.push(0)
      upper.push(0)
      fractions.push(0.0)
    } else {
      let low = @math.floor(coordinates[dimension]).to_int()
      let high = if low + 1 >= function.size[dimension] { low } else { low + 1 }
      lower.push(low)
      upper.push(high)
      fractions.push(coordinates[dimension] - low.to_double())
    }
  }

  let corner_count = 1 << dimensions
  let mut value = 0.0
  for corner in 0..<corner_count {
    let selected : Array[Int] = []
    let mut weight = 1.0
    for dimension in 0..<dimensions {
      if ((corner >> dimension) & 1) == 1 {
        selected.push(upper[dimension])
        weight = weight * fractions[dimension]
      } else {
        selected.push(lower[dimension])
        weight = weight * (1.0 - fractions[dimension])
      }
    }
    value = value +
      weight *
      sample_value_at(
        function,
        flattened_sample_index(function.size, selected),
        component,
      )
  }
  value
}

///|
fn supports_cubic_interpolation(function : SampledFunction) -> Bool {
  match function.order {
    Cubic => {
      let mut supported = true
      for dimension in function.size {
        if dimension < 4 {
          supported = false
        }
      }
      supported
    }
    Linear => false
  }
}

///|
fn cubic_value(
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
  t : Double,
) -> Double {
  let t2 = t * t
  let t3 = t2 * t
  0.5 *
  (
    2.0 * p1 +
    (p2 - p0) * t +
    (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
    (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
  )
}

///|
fn cubic_indices_and_fraction(
  size : Int,
  coordinate : Double,
) -> (Array[Int], Double) {
  let low = @math.floor(coordinate).to_int()
  let fraction = coordinate - low.to_double()
  let i0 = if low - 1 < 0 { 0 } else { low - 1 }
  let i1 = if low < 0 { 0 } else if low >= size { size - 1 } else { low }
  let i2 = if low + 1 >= size { size - 1 } else { low + 1 }
  let i3 = if low + 2 >= size { size - 1 } else { low + 2 }
  ([i0, i1, i2, i3], fraction)
}

///|
fn interpolate_cubic_component_at_dimension(
  function : SampledFunction,
  coordinates : Array[Double],
  component : Int,
  dimension : Int,
  selected : Array[Int],
) -> Double {
  if dimension == function.size.length() {
    sample_value_at(
      function,
      flattened_sample_index(function.size, selected),
      component,
    )
  } else {
    let (indices, fraction) = cubic_indices_and_fraction(
      function.size[dimension],
      coordinates[dimension],
    )
    let values : Array[Double] = []
    for index in indices {
      let next = selected.copy()
      next.push(index)
      values.push(
        interpolate_cubic_component_at_dimension(
          function,
          coordinates,
          component,
          dimension + 1,
          next,
        ),
      )
    }
    cubic_value(values[0], values[1], values[2], values[3], fraction)
  }
}

///|
fn interpolate_cubic_component(
  function : SampledFunction,
  coordinates : Array[Double],
  component : Int,
) -> Double {
  interpolate_cubic_component_at_dimension(
    function,
    coordinates,
    component,
    0,
    [],
  )
}

///|
fn evaluate_sampled_function(
  function : SampledFunction,
  clipped_inputs : Array[Double],
) -> Array[Double] raise PdfFunctionError {
  let coordinates = encoded_coordinates(function, clipped_inputs)
  let max_sample = max_encoded_sample_value(function.bits_per_sample)
  let outputs : Array[Double] = []
  for component in 0..<function.table.output_count {
    let raw = if supports_cubic_interpolation(function) {
      interpolate_cubic_component(function, coordinates, component)
    } else {
      interpolate_linear_component(function, coordinates, component)
    }
    outputs.push(
      interpolate(
        raw,
        FunctionInterval::{ min: 0.0, max: max_sample },
        function.decode[component],
      ),
    )
  }
  function.common.clip_outputs(outputs)
}

///|
fn parse_sampled_function(
  input : DirectFunctionParseInput,
) -> SampledFunction raise PdfFunctionError {
  let decoded_stream = match input.decoded_stream {
    Some(bytes) => bytes
    None =>
      raise function_error(
        input.offset,
        "Type 0 sampled functions must be streams",
      )
  }
  let range = require_range(input.common, input.offset, "Type 0")
  let size = parse_positive_int_array(input.dict, b"Size", input.offset)
  if size.length() != input.common.domain.length() {
    raise function_error(
      input.offset,
      "Size length must match Domain input count",
    )
  }
  check_limit(
    "sampled function input dimensions",
    size.length(),
    input.limits.max_input_dimensions,
  )
  let bits_per_sample = require_integer_value(
    required_entry(input.dict, b"BitsPerSample", input.offset),
    input.offset,
    "BitsPerSample",
  ).to_int()
  if !is_supported_sample_width(bits_per_sample) {
    raise function_error(
      input.offset,
      "BitsPerSample must be one of 1, 2, 4, 8, 12, 16, 24, or 32",
    )
  }
  let order = parse_optional_order(input.dict, input.offset)
  let encode = match
    parse_optional_interval_array_exact(
      input.dict,
      b"Encode",
      size.length(),
      input.offset,
    ) {
    Some(intervals) => intervals
    None => default_encode(size)
  }
  let decode = match
    parse_optional_interval_array_exact(
      input.dict,
      b"Decode",
      range.length(),
      input.offset,
    ) {
    Some(intervals) => intervals
    None => range.copy()
  }
  let sample_value_count = checked_sample_value_count(
    size,
    range.length(),
    input.limits,
    input.offset,
  )
  SampledFunction::{
    common: input.common,
    size,
    bits_per_sample,
    order,
    encode,
    decode,
    table: read_sample_table(
      decoded_stream,
      bits_per_sample,
      sample_value_count,
      range.length(),
      input.offset,
    ),
  }
}
