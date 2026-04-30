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
fn parser_base_dict(function_type : Int64) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[parser_name(b"FunctionType")] = parser_int(function_type)
  dict[parser_name(b"Domain")] = @objects.PdfObject::Array([
    parser_num(0.0),
    parser_num(1.0),
  ])
  dict
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
  let pending_type_parser : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(type3),
    FunctionLimits::default(),
    25L,
  )
  match pending_type_parser {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 25L)
      assert_eq(reason, "Type 3 function parser is not registered yet")
    }
    _ => fail("expected registered parser handoff point")
  }
}
