///|
fn evaluator_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn evaluator_num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn evaluator_int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn evaluator_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn evaluator_parse(
  object : @objects.PdfObject,
) -> PdfFunction raise PdfFunctionError {
  parse_direct_function(object, FunctionLimits::default(), 130L)
}

///|
fn evaluator_type2() -> PdfFunction raise PdfFunctionError {
  let dict : @objects.PdfDictionary = Map::new()
  dict[evaluator_name(b"FunctionType")] = evaluator_int(2L)
  dict[evaluator_name(b"Domain")] = evaluator_array([
    evaluator_num(0.0),
    evaluator_num(1.0),
  ])
  dict[evaluator_name(b"Range")] = evaluator_array([
    evaluator_num(0.0),
    evaluator_num(1.0),
  ])
  dict[evaluator_name(b"C0")] = evaluator_array([evaluator_num(0.0)])
  dict[evaluator_name(b"C1")] = evaluator_array([evaluator_num(2.0)])
  dict[evaluator_name(b"N")] = evaluator_num(1.0)
  evaluator_parse(@objects.PdfObject::Dictionary(dict))
}

///|
fn evaluator_type4() -> PdfFunction raise PdfFunctionError {
  let dict : @objects.PdfDictionary = Map::new()
  dict[evaluator_name(b"FunctionType")] = evaluator_int(4L)
  dict[evaluator_name(b"Domain")] = evaluator_array([
    evaluator_num(0.0),
    evaluator_num(1.0),
  ])
  dict[evaluator_name(b"Range")] = evaluator_array([
    evaluator_num(0.0),
    evaluator_num(1.0),
  ])
  evaluator_parse(
    @objects.PdfObject::Stream(@objects.PdfStream::{ dict, data: b"{ 2 mul }" }),
  )
}

///|
fn evaluator_type0() -> PdfFunction raise PdfFunctionError {
  let dict : @objects.PdfDictionary = Map::new()
  dict[evaluator_name(b"FunctionType")] = evaluator_int(0L)
  dict[evaluator_name(b"Domain")] = evaluator_array([
    evaluator_num(0.0),
    evaluator_num(1.0),
  ])
  dict[evaluator_name(b"Range")] = evaluator_array([
    evaluator_num(0.0),
    evaluator_num(1.0),
  ])
  dict[evaluator_name(b"Size")] = evaluator_array([evaluator_int(2L)])
  dict[evaluator_name(b"BitsPerSample")] = evaluator_int(8L)
  evaluator_parse(
    @objects.PdfObject::Stream(@objects.PdfStream::{
      dict,
      data: Bytes::from_array([b'\x00', b'\xff']),
    }),
  )
}

///|
test "shared evaluator clips inputs and range outputs for direct functions" {
  inspect(
    evaluator_type0().evaluate([2.0], FunctionLimits::default()),
    content="[1]",
  )
  inspect(
    evaluator_type2().evaluate([0.75], FunctionLimits::default()),
    content="[1]",
  )
  inspect(
    evaluator_type4().evaluate([0.75], FunctionLimits::default()),
    content="[1]",
  )
}

///|
test "shared evaluator applies arity and common evaluation step guards" {
  let wrong_arity : Result[Array[Double], PdfFunctionError] = try? evaluator_type2().evaluate(
    [0.5, 0.25],
    FunctionLimits::default(),
  )
  match wrong_arity {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "expected 1 function inputs, got 2")
    _ => fail("expected common input arity failure")
  }

  let mut limits = FunctionLimits::default()
  limits = FunctionLimits::{ ..limits, max_evaluation_steps: 0 }
  let step_limited : Result[Array[Double], PdfFunctionError] = try? evaluator_type0().evaluate(
    [0.5],
    limits,
  )
  match step_limited {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "function evaluation steps")
      assert_eq(actual, 1)
      assert_eq(maximum, 0)
    }
    _ => fail("expected common evaluation step limit")
  }
}
