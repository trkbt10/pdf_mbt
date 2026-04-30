///|
fn exp_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn exp_num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn exp_int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn exp_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn exp_base_dict(
  domain : Array[Double],
  exponent : Double,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[exp_name(b"FunctionType")] = exp_int(2L)
  let domain_objects : Array[@objects.PdfObject] = []
  for value in domain {
    domain_objects.push(exp_num(value))
  }
  dict[exp_name(b"Domain")] = exp_array(domain_objects)
  dict[exp_name(b"N")] = exp_num(exponent)
  dict
}

///|
fn exp_num_array(values : Array[Double]) -> @objects.PdfObject {
  let objects : Array[@objects.PdfObject] = []
  for value in values {
    objects.push(exp_num(value))
  }
  exp_array(objects)
}

///|
test "exponential functions evaluate defaults and explicit multi-output coefficients" {
  let default_function = parse_direct_function(
    @objects.PdfObject::Dictionary(exp_base_dict([0.0, 1.0], 2.0)),
    FunctionLimits::default(),
    80L,
  )
  inspect(
    default_function.evaluate([0.5], FunctionLimits::default()),
    content="[0.25]",
  )

  let dict = exp_base_dict([0.0, 1.0], 1.0)
  dict[exp_name(b"C0")] = exp_num_array([1.0, 10.0])
  dict[exp_name(b"C1")] = exp_num_array([3.0, 14.0])
  let multi = parse_direct_function(
    @objects.PdfObject::Dictionary(dict),
    FunctionLimits::default(),
    81L,
  )
  inspect(multi.evaluate([0.5], FunctionLimits::default()), content="[2, 12]")
}

///|
test "exponential functions clip optional ranges and reject arity mismatches" {
  let dict = exp_base_dict([0.0, 1.0], 1.0)
  dict[exp_name(b"C1")] = exp_num_array([2.0])
  dict[exp_name(b"Range")] = exp_num_array([0.0, 1.0])
  let function = parse_direct_function(
    @objects.PdfObject::Dictionary(dict),
    FunctionLimits::default(),
    82L,
  )
  inspect(function.evaluate([0.75], FunctionLimits::default()), content="[1]")
  let wrong_arity : Result[Array[Double], PdfFunctionError] = try? function.evaluate(
    [],
    FunctionLimits::default(),
  )
  match wrong_arity {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "expected 1 function inputs, got 0")
    _ => fail("expected arity failure")
  }
}

///|
test "exponential functions reject invalid numeric preconditions" {
  let fractional = parse_direct_function(
    @objects.PdfObject::Dictionary(exp_base_dict([-1.0, 1.0], 0.5)),
    FunctionLimits::default(),
    83L,
  )
  let fractional_result : Result[Array[Double], PdfFunctionError] = try? fractional.evaluate(
    [-0.25],
    FunctionLimits::default(),
  )
  match fractional_result {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(
        reason, "Type 2 non-integer exponent requires non-negative input",
      )
    _ => fail("expected non-integer exponent domain failure")
  }

  let negative = parse_direct_function(
    @objects.PdfObject::Dictionary(exp_base_dict([0.0, 1.0], -1.0)),
    FunctionLimits::default(),
    84L,
  )
  let negative_result : Result[Array[Double], PdfFunctionError] = try? negative.evaluate(
    [0.0],
    FunctionLimits::default(),
  )
  match negative_result {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "Type 2 negative exponent requires non-zero input")
    _ => fail("expected negative exponent zero-input failure")
  }
}

///|
test "exponential parser validates coefficient and range dimensions" {
  let mismatch = exp_base_dict([0.0, 1.0], 1.0)
  mismatch[exp_name(b"C0")] = exp_num_array([0.0, 1.0])
  mismatch[exp_name(b"C1")] = exp_num_array([1.0])
  let mismatch_result : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(mismatch),
    FunctionLimits::default(),
    85L,
  )
  match mismatch_result {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 85L)
      assert_eq(reason, "Type 2 C0 and C1 lengths must match")
    }
    _ => fail("expected coefficient mismatch failure")
  }

  let bad_range = exp_base_dict([0.0, 1.0], 1.0)
  bad_range[exp_name(b"C0")] = exp_num_array([0.0, 0.0])
  bad_range[exp_name(b"C1")] = exp_num_array([1.0, 1.0])
  bad_range[exp_name(b"Range")] = exp_num_array([0.0, 1.0])
  let range_result : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(bad_range),
    FunctionLimits::default(),
    86L,
  )
  match range_result {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 86L)
      assert_eq(reason, "Range length must match Type 2 output count")
    }
    _ => fail("expected range dimension failure")
  }
}
