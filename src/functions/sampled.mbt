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
