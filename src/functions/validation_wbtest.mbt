///|
fn name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn base_dict(function_type : Int64) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[name(b"FunctionType")] = int(function_type)
  dict[name(b"Domain")] = @objects.PdfObject::Array([num(0.0), num(1.0)])
  dict
}

///|
test "common intervals clip and interpolate finite numeric values" {
  let interval = FunctionInterval::new(-1.0, 1.0)
  assert_eq(interval.clip(-6.0), -1.0)
  assert_eq(interval.clip(0.25), 0.25)
  assert_eq(interval.clip(6.0), 1.0)
  let input = FunctionInterval::new(0.0, 10.0)
  let output = FunctionInterval::new(-1.0, 1.0)
  inspect(interpolate(2.5, input, output), content="-0.5")
}

///|
test "domain and range validation reject malformed dictionaries" {
  let limits = FunctionLimits::default()
  let missing_domain : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(
      {
        let dict : @objects.PdfDictionary = Map::new()
        dict[name(b"FunctionType")] = int(2L)
        dict
      },
    ),
    limits,
    12L,
  )
  match missing_domain {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 12L)
      assert_eq(reason, "missing required /Domain entry")
    }
    _ => fail("expected missing Domain to fail")
  }

  let bad_domain = base_dict(2L)
  bad_domain[name(b"Domain")] = @objects.PdfObject::Array([num(1.0), num(0.0)])
  let invalid_interval : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    @objects.PdfObject::Dictionary(bad_domain),
    limits,
    13L,
  )
  match invalid_interval {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 13L)
      assert_eq(
        reason, "interval minimum must be less than or equal to maximum",
      )
    }
    _ => fail("expected invalid Domain interval to fail")
  }
}

///|
test "input and output clipping enforce arity and range contracts" {
  let common = FunctionCommon::{
    domain: [FunctionInterval::new(0.0, 1.0), FunctionInterval::new(-1.0, 1.0)],
    range: Some([FunctionInterval::new(10.0, 20.0)]),
  }
  inspect(common.clip_inputs([-5.0, 0.5]), content="[0, 0.5]")
  inspect(common.clip_outputs([99.0]), content="[20]")
  let wrong_arity : Result[Array[Double], PdfFunctionError] = try? common.clip_inputs([
      1.0,
    ],
  )
  match wrong_arity {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "expected 2 function inputs, got 1")
    _ => fail("expected input arity failure")
  }
}
