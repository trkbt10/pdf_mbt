///|
fn stitch_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn stitch_num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn stitch_int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn stitch_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn stitch_num_array(values : Array[Double]) -> @objects.PdfObject {
  let objects : Array[@objects.PdfObject] = []
  for value in values {
    objects.push(stitch_num(value))
  }
  stitch_array(objects)
}

///|
fn stitch_type2(c0 : Array[Double], c1 : Array[Double]) -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[stitch_name(b"FunctionType")] = stitch_int(2L)
  dict[stitch_name(b"Domain")] = stitch_num_array([0.0, 1.0])
  dict[stitch_name(b"C0")] = stitch_num_array(c0)
  dict[stitch_name(b"C1")] = stitch_num_array(c1)
  dict[stitch_name(b"N")] = stitch_num(1.0)
  @objects.PdfObject::Dictionary(dict)
}

///|
fn stitch_type3(
  functions : Array[@objects.PdfObject],
  bounds : Array[Double],
  encode : Array[Double],
  range : Array[Double]?,
) -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[stitch_name(b"FunctionType")] = stitch_int(3L)
  dict[stitch_name(b"Domain")] = stitch_num_array([0.0, 1.0])
  dict[stitch_name(b"Functions")] = stitch_array(functions)
  dict[stitch_name(b"Bounds")] = stitch_num_array(bounds)
  dict[stitch_name(b"Encode")] = stitch_num_array(encode)
  match range {
    Some(values) => dict[stitch_name(b"Range")] = stitch_num_array(values)
    None => ()
  }
  @objects.PdfObject::Dictionary(dict)
}

///|
fn stitch_parse(
  object : @objects.PdfObject,
) -> PdfFunction raise PdfFunctionError {
  parse_direct_function(object, FunctionLimits::default(), 140L)
}

///|
test "stitching parser validates bounds encode and output dimensions" {
  let bounds_mismatch : Result[PdfFunction, PdfFunctionError] = try? stitch_parse(
    stitch_type3(
      [stitch_type2([0.0], [1.0]), stitch_type2([0.0], [1.0])],
      [],
      [0.0, 1.0, 0.0, 1.0],
      Some([0.0, 1.0]),
    ),
  )
  match bounds_mismatch {
    Err(InvalidFunction(_, reason)) =>
      assert_eq(
        reason, "Type 3 Bounds length must be Functions length minus one",
      )
    _ => fail("expected bounds length failure")
  }

  let encode_mismatch : Result[PdfFunction, PdfFunctionError] = try? stitch_parse(
    stitch_type3([stitch_type2([0.0], [1.0])], [], [0.0], Some([0.0, 1.0])),
  )
  match encode_mismatch {
    Err(InvalidFunction(_, reason)) =>
      assert_eq(
        reason, "Type 3 Encode length must be twice the Functions length",
      )
    _ => fail("expected encode length failure")
  }

  let unordered_bounds : Result[PdfFunction, PdfFunctionError] = try? stitch_parse(
    stitch_type3(
      [
        stitch_type2([0.0], [1.0]),
        stitch_type2([0.0], [1.0]),
        stitch_type2([0.0], [1.0]),
      ],
      [0.7, 0.5],
      [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
      Some([0.0, 1.0]),
    ),
  )
  match unordered_bounds {
    Err(InvalidFunction(_, reason)) =>
      assert_eq(reason, "Type 3 Bounds values must be strictly increasing")
    _ => fail("expected bounds ordering failure")
  }

  let incompatible : Result[PdfFunction, PdfFunctionError] = try? stitch_parse(
    stitch_type3(
      [stitch_type2([0.0], [1.0]), stitch_type2([0.0, 0.0], [1.0, 1.0])],
      [0.5],
      [0.0, 1.0, 0.0, 1.0],
      Some([0.0, 1.0]),
    ),
  )
  match incompatible {
    Err(InvalidFunction(_, reason)) =>
      assert_eq(reason, "Type 3 subfunction output dimensions are incompatible")
    _ => fail("expected output dimension failure")
  }
}

///|
test "stitching evaluator selects normal and degenerate partitions" {
  let normal = stitch_parse(
    stitch_type3(
      [stitch_type2([0.0], [10.0]), stitch_type2([100.0], [200.0])],
      [0.5],
      [0.0, 1.0, 0.0, 1.0],
      Some([0.0, 200.0]),
    ),
  )
  inspect(normal.evaluate([0.25], FunctionLimits::default()), content="[5]")
  inspect(normal.evaluate([0.5], FunctionLimits::default()), content="[100]")
  inspect(normal.evaluate([0.75], FunctionLimits::default()), content="[150]")

  let first_degenerate = stitch_parse(
    stitch_type3(
      [stitch_type2([10.0], [10.0]), stitch_type2([100.0], [200.0])],
      [0.0],
      [0.0, 1.0, 0.0, 1.0],
      Some([0.0, 200.0]),
    ),
  )
  inspect(
    first_degenerate.evaluate([0.0], FunctionLimits::default()),
    content="[10]",
  )
  inspect(
    first_degenerate.evaluate([0.25], FunctionLimits::default()),
    content="[125]",
  )

  let last_degenerate = stitch_parse(
    stitch_type3(
      [stitch_type2([0.0], [10.0]), stitch_type2([99.0], [99.0])],
      [1.0],
      [0.0, 1.0, 0.0, 1.0],
      Some([0.0, 200.0]),
    ),
  )
  inspect(
    last_degenerate.evaluate([1.0], FunctionLimits::default()),
    content="[99]",
  )
}

///|
test "stitching evaluator supports single function inverted encode and unresolved refs" {
  let single = stitch_parse(
    stitch_type3([stitch_type2([0.0], [10.0])], [], [1.0, 0.0], None),
  )
  inspect(single.evaluate([0.25], FunctionLimits::default()), content="[7.5]")

  let object_id = @objects.ObjectId::{ object_number: 77, generation_number: 0 }
  let unresolved = stitch_parse(
    stitch_type3(
      [@objects.PdfObject::Ref(object_id)],
      [],
      [0.0, 1.0],
      Some([0.0, 1.0]),
    ),
  )
  let result : Result[Array[Double], PdfFunctionError] = try? unresolved.evaluate(
    [0.5],
    FunctionLimits::default(),
  )
  match result {
    Err(UnresolvedFunctionReference(found)) =>
      assert_eq(found == object_id, true)
    _ => fail("expected unresolved selected subfunction")
  }
}

///|
test "stitching evaluator enforces recursion limits" {
  let child = stitch_type3([stitch_type2([0.0], [1.0])], [], [0.0, 1.0], None)
  let parent = stitch_parse(stitch_type3([child], [], [0.0, 1.0], None))
  let mut limits = FunctionLimits::default()
  limits = FunctionLimits::{ ..limits, max_recursion_depth: 1 }
  let result : Result[Array[Double], PdfFunctionError] = try? parent.evaluate(
    [0.5],
    limits,
  )
  match result {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "function recursion depth")
      assert_eq(actual, 2)
      assert_eq(maximum, 1)
    }
    _ => fail("expected recursion depth failure")
  }
}
