///|
fn parser_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn parser_num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn parser_int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn parser_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn parser_num_array(values : Array[Double]) -> @objects.PdfObject {
  let objects : Array[@objects.PdfObject] = []
  for value in values {
    objects.push(parser_num(value))
  }
  parser_array(objects)
}

///|
fn parser_base_dict(function_type : Int64) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[parser_name(b"FunctionType")] = parser_int(function_type)
  dict[parser_name(b"Domain")] = parser_num_array([0.0, 1.0])
  dict
}

///|
fn parser_type2_object() -> @objects.PdfObject {
  let dict = parser_base_dict(2L)
  dict[parser_name(b"C0")] = parser_num_array([0.0])
  dict[parser_name(b"C1")] = parser_num_array([1.0])
  dict[parser_name(b"N")] = parser_num(1.0)
  @objects.PdfObject::Dictionary(dict)
}

///|
fn parser_ascii_hex_filter(dict : @objects.PdfDictionary) -> Unit {
  dict[parser_name(b"Filter")] = @objects.PdfObject::Name(
    parser_name(b"ASCIIHexDecode"),
  )
}

///|
test "function source preserves indirect references without resolving them" {
  let object_id = @objects.ObjectId::{ object_number: 7, generation_number: 0 }
  let source = parse_function_object(
    @objects.PdfObject::Ref(object_id),
    FunctionLimits::default(),
    0L,
  )
  match source {
    IndirectFunction(found) => assert_eq(found == object_id, true)
    _ => fail("expected indirect function source")
  }
  let evaluated : Result[Array[Double], PdfFunctionError] = try? evaluate_function_source(
    source,
    [0.0],
    FunctionLimits::default(),
  )
  match evaluated {
    Err(UnresolvedFunctionReference(found)) =>
      assert_eq(found == object_id, true)
    _ => fail("expected unresolved reference failure")
  }
}

///|
test "unsupported object shapes and function types fail through function errors" {
  let unsupported_shape : Result[FunctionSource, PdfFunctionError] = try? parse_function_object(
    @objects.PdfObject::Boolean(true),
    FunctionLimits::default(),
    22L,
  )
  match unsupported_shape {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 22L)
      assert_eq(
        reason, "function source must be a dictionary, stream, or indirect reference, got boolean",
      )
    }
    _ => fail("expected unsupported shape failure")
  }

  let dict = parser_base_dict(9L)
  let unsupported_type : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(dict),
    FunctionLimits::default(),
    23L,
  )
  match unsupported_type {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 23L)
      assert_eq(reason, "unsupported FunctionType 9")
    }
    _ => fail("expected unsupported type failure")
  }
}

///|
test "direct parser handoff validates common entries before type parser ownership" {
  let dict = parser_base_dict(4L)
  let no_range : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(dict),
    FunctionLimits::default(),
    24L,
  )
  match no_range {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 24L)
      assert_eq(reason, "Type 4 functions require Range")
    }
    _ => fail("expected Range requirement failure before Type 4 parser")
  }

  let type3 = parser_base_dict(3L)
  let missing_type3_entries : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(type3),
    FunctionLimits::default(),
    25L,
  )
  match missing_type3_entries {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 25L)
      assert_eq(reason, "missing required /b\"Functions\" entry")
    }
    _ => fail("expected Type 3 owned parser failure")
  }
}

///|
test "direct parser dispatches all supported function types and decodes streams" {
  let sampled = parser_base_dict(0L)
  sampled[parser_name(b"Range")] = parser_num_array([0.0, 1.0])
  sampled[parser_name(b"Size")] = parser_array([parser_int(2L)])
  sampled[parser_name(b"BitsPerSample")] = parser_int(8L)
  parser_ascii_hex_filter(sampled)
  match
    parse_direct_function(
      @objects.PdfObject::Stream(@objects.PdfStream::{
        dict: sampled,
        data: b"00FF>",
      }),
      FunctionLimits::default(),
      26L,
    ) {
    SampledFunction(function) => {
      assert_eq(function.bits_per_sample, 8)
      inspect(
        SampledFunction(function).evaluate([1.0], FunctionLimits::default()),
        content="[1]",
      )
    }
    _ => fail("expected Type 0 sampled function")
  }

  match
    parse_direct_function(parser_type2_object(), FunctionLimits::default(), 27L) {
    ExponentialFunction(function) => assert_eq(function.exponent, 1.0)
    _ => fail("expected Type 2 exponential function")
  }

  let stitching = parser_base_dict(3L)
  stitching[parser_name(b"Functions")] = parser_array([parser_type2_object()])
  stitching[parser_name(b"Bounds")] = parser_array([])
  stitching[parser_name(b"Encode")] = parser_num_array([0.0, 1.0])
  match
    parse_direct_function(
      @objects.PdfObject::Dictionary(stitching),
      FunctionLimits::default(),
      28L,
    ) {
    StitchingFunction(function) => assert_eq(function.functions.length(), 1)
    _ => fail("expected Type 3 stitching function")
  }

  let calculator = parser_base_dict(4L)
  calculator[parser_name(b"Range")] = parser_num_array([0.0, 10.0])
  parser_ascii_hex_filter(calculator)
  match
    parse_direct_function(
      @objects.PdfObject::Stream(@objects.PdfStream::{
        dict: calculator,
        data: b"7B20706F702031203220616464207D>",
      }),
      FunctionLimits::default(),
      29L,
    ) {
    CalculatorFunction(function) => {
      assert_eq(function.program.token_count, 4)
      inspect(
        CalculatorFunction(function).evaluate([0.0], FunctionLimits::default()),
        content="[3]",
      )
    }
    _ => fail("expected Type 4 calculator function")
  }
}
