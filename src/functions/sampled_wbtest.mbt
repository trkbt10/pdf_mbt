///|
fn sampled_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn sampled_num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn sampled_int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn sampled_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn pack_sample_bits(values : Array[Int64], bits_per_sample : Int) -> Bytes {
  let output : Array[Byte] = []
  let mut current = 0
  let mut filled = 0
  for value in values {
    let mut bit_index = bits_per_sample - 1
    while bit_index >= 0 {
      let bit = ((value >> bit_index) & 1L).to_int()
      current = (current << 1) | bit
      filled = filled + 1
      if filled == 8 {
        output.push(current.to_byte())
        current = 0
        filled = 0
      }
      bit_index = bit_index - 1
    }
  }
  if filled > 0 {
    output.push((current << (8 - filled)).to_byte())
  }
  Bytes::from_array(output)
}

///|
fn sampled_stream(
  size : Array[Int64],
  bits_per_sample : Int64,
  range_pairs : Array[Double],
  data : Bytes,
) -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[sampled_name(b"FunctionType")] = sampled_int(0L)
  dict[sampled_name(b"Domain")] = sampled_array([
    sampled_num(0.0),
    sampled_num(1.0),
  ])
  let size_objects : Array[@objects.PdfObject] = []
  for value in size {
    size_objects.push(sampled_int(value))
  }
  dict[sampled_name(b"Size")] = sampled_array(size_objects)
  dict[sampled_name(b"BitsPerSample")] = sampled_int(bits_per_sample)
  let range_objects : Array[@objects.PdfObject] = []
  for value in range_pairs {
    range_objects.push(sampled_num(value))
  }
  dict[sampled_name(b"Range")] = sampled_array(range_objects)
  @objects.PdfObject::Stream(@objects.PdfStream::{ dict, data })
}

///|
fn sampled_stream_with_dict(
  dict : @objects.PdfDictionary,
  data : Bytes,
) -> @objects.PdfObject {
  @objects.PdfObject::Stream(@objects.PdfStream::{ dict, data })
}

///|
test "sampled parser accepts every supported bit width as one continuous MSB-first stream" {
  let widths = [1, 2, 4, 8, 12, 16, 24, 32]
  let maxima = [1L, 3L, 15L, 255L, 4095L, 65535L, 16777215L, 4294967295L]
  for index in 0..<widths.length() {
    let width = widths[index]
    let object = sampled_stream(
      [1L],
      width.to_int64(),
      [0.0, 1.0],
      pack_sample_bits([maxima[index]], width),
    )
    let function = parse_direct_function(
      object,
      FunctionLimits::default(),
      index.to_int64(),
    )
    match function {
      SampledFunction(sampled) => {
        assert_eq(sampled.bits_per_sample, width)
        assert_eq(sampled.size, [1])
        assert_eq(sampled.table.sample_count(), 1)
        inspect(sampled.table.values, content="[\{maxima[index].to_double()}]")
      }
      _ => fail("expected sampled function")
    }
  }
}

///|
test "sampled parser preserves first-dimension-fastest values and defaults" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[sampled_name(b"FunctionType")] = sampled_int(0L)
  dict[sampled_name(b"Domain")] = sampled_array([
    sampled_num(-1.0),
    sampled_num(1.0),
    sampled_num(10.0),
    sampled_num(20.0),
  ])
  dict[sampled_name(b"Size")] = sampled_array([sampled_int(2L), sampled_int(2L)])
  dict[sampled_name(b"BitsPerSample")] = sampled_int(4L)
  dict[sampled_name(b"Range")] = sampled_array([
    sampled_num(-1.0),
    sampled_num(1.0),
    sampled_num(10.0),
    sampled_num(20.0),
  ])
  let object = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict,
    data: pack_sample_bits([0L, 1L, 2L, 3L, 4L, 5L, 6L, 7L], 4),
  })
  let function = parse_direct_function(object, FunctionLimits::default(), 40L)
  match function {
    SampledFunction(sampled) => {
      match sampled.order {
        Linear => ()
        _ => fail("expected default linear order")
      }
      assert_eq(sampled.encode[0].min, 0.0)
      assert_eq(sampled.encode[0].max, 1.0)
      assert_eq(sampled.encode[1].min, 0.0)
      assert_eq(sampled.encode[1].max, 1.0)
      assert_eq(sampled.decode[0].min, -1.0)
      assert_eq(sampled.decode[0].max, 1.0)
      assert_eq(sampled.decode[1].min, 10.0)
      assert_eq(sampled.decode[1].max, 20.0)
      inspect(sampled.table.values, content="[0, 1, 2, 3, 4, 5, 6, 7]")
      assert_eq(sampled.table.output_count, 2)
    }
    _ => fail("expected sampled function")
  }
}

///|
test "sampled parser rejects invalid declarations and insufficient stream data" {
  let invalid_width : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    sampled_stream([1L], 3L, [0.0, 1.0], Bytes::from_array([b'\x00'])),
    FunctionLimits::default(),
    50L,
  )
  match invalid_width {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 50L)
      assert_eq(
        reason, "BitsPerSample must be one of 1, 2, 4, 8, 12, 16, 24, or 32",
      )
    }
    _ => fail("expected invalid bit width")
  }

  let too_short : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    sampled_stream([3L], 4L, [0.0, 1.0], Bytes::from_array([b'\x12'])),
    FunctionLimits::default(),
    51L,
  )
  match too_short {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 51L)
      assert_eq(
        reason, "sample stream is too short for declared Size and Range",
      )
    }
    _ => fail("expected truncated sample stream")
  }

  let mut limits = FunctionLimits::default()
  limits = FunctionLimits::{ ..limits, max_sample_values: 2 }
  let limit_result : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    sampled_stream(
      [3L],
      8L,
      [0.0, 1.0],
      Bytes::from_array([b'\x00', b'\x01', b'\x02']),
    ),
    limits,
    52L,
  )
  match limit_result {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "sample values")
      assert_eq(actual > maximum, true)
    }
    _ => fail("expected sample value limit failure")
  }
}

///|
test "sampled linear evaluation maps domain through encode decode and range clipping" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[sampled_name(b"FunctionType")] = sampled_int(0L)
  dict[sampled_name(b"Domain")] = sampled_array([
    sampled_num(0.0),
    sampled_num(1.0),
  ])
  dict[sampled_name(b"Size")] = sampled_array([sampled_int(2L)])
  dict[sampled_name(b"BitsPerSample")] = sampled_int(8L)
  dict[sampled_name(b"Encode")] = sampled_array([
    sampled_num(0.0),
    sampled_num(1.0),
  ])
  dict[sampled_name(b"Decode")] = sampled_array([
    sampled_num(0.0),
    sampled_num(2.0),
  ])
  dict[sampled_name(b"Range")] = sampled_array([
    sampled_num(0.0),
    sampled_num(1.0),
  ])
  let function = parse_direct_function(
    sampled_stream_with_dict(dict, Bytes::from_array([b'\x00', b'\xff'])),
    FunctionLimits::default(),
    60L,
  )
  inspect(function.evaluate([0.25], FunctionLimits::default()), content="[0.5]")
  inspect(function.evaluate([-2.0], FunctionLimits::default()), content="[0]")
  inspect(function.evaluate([2.0], FunctionLimits::default()), content="[1]")
}

///|
test "sampled linear evaluation uses first-dimension-fastest multidimensional ordering" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[sampled_name(b"FunctionType")] = sampled_int(0L)
  dict[sampled_name(b"Domain")] = sampled_array([
    sampled_num(0.0),
    sampled_num(1.0),
    sampled_num(0.0),
    sampled_num(1.0),
  ])
  dict[sampled_name(b"Size")] = sampled_array([sampled_int(2L), sampled_int(2L)])
  dict[sampled_name(b"BitsPerSample")] = sampled_int(8L)
  dict[sampled_name(b"Decode")] = sampled_array([
    sampled_num(0.0),
    sampled_num(255.0),
  ])
  dict[sampled_name(b"Range")] = sampled_array([
    sampled_num(0.0),
    sampled_num(255.0),
  ])
  let function = parse_direct_function(
    sampled_stream_with_dict(
      dict,
      Bytes::from_array([b'\x00', b'\x64', b'\xc8', b'\xff']),
    ),
    FunctionLimits::default(),
    61L,
  )
  inspect(
    function.evaluate([0.5, 0.5], FunctionLimits::default()),
    content="[138.75]",
  )
  inspect(
    function.evaluate([1.0, 0.0], FunctionLimits::default()),
    content="[100]",
  )
  inspect(
    function.evaluate([0.0, 1.0], FunctionLimits::default()),
    content="[200]",
  )
}
