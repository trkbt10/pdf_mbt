///|
fn calc_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn calc_num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn calc_int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn calc_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn calc_stream(program : Bytes) -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[calc_name(b"FunctionType")] = calc_int(4L)
  dict[calc_name(b"Domain")] = calc_array([calc_num(0.0), calc_num(1.0)])
  dict[calc_name(b"Range")] = calc_array([calc_num(0.0), calc_num(1.0)])
  @objects.PdfObject::Stream(@objects.PdfStream::{ dict, data: program })
}

///|
test "calculator parser accepts comments literals operators and conditional blocks" {
  let function = parse_direct_function(
    calc_stream(b"{ % comment\n true { 1 2 add } if false { 3 } { 4 } ifelse }"),
    FunctionLimits::default(),
    90L,
  )
  match function {
    CalculatorFunction(calculator) => {
      assert_eq(calculator.program.token_count, 12)
      assert_eq(calculator.program.instructions.length(), 7)
      match calculator.program.instructions[1] {
        CalculatorBlock(block) => assert_eq(block.length(), 3)
        _ => fail("expected if block")
      }
      match calculator.program.instructions[4] {
        CalculatorBlock(block) => assert_eq(block.length(), 1)
        _ => fail("expected ifelse first block")
      }
    }
    _ => fail("expected calculator function")
  }
}

///|
test "calculator parser rejects unknown names composite syntax and unbalanced braces" {
  let unknown : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    calc_stream(b"{ 1 madeup }"),
    FunctionLimits::default(),
    91L,
  )
  match unknown {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 91L)
      assert_eq(reason, "unsupported calculator operator or name b\"madeup\"")
    }
    _ => fail("expected unknown operator failure")
  }

  let composite : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    calc_stream(b"{ [1 2] }"),
    FunctionLimits::default(),
    92L,
  )
  match composite {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 92L)
      assert_eq(reason, "calculator composite data and names are not supported")
    }
    _ => fail("expected composite rejection")
  }

  let unbalanced : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    calc_stream(b"{ true { 1 } if "),
    FunctionLimits::default(),
    93L,
  )
  match unbalanced {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 93L)
      assert_eq(reason, "unbalanced calculator braces")
    }
    _ => fail("expected unbalanced brace rejection")
  }
}

///|
test "calculator parser rejects procedure-like brace blocks and token limits" {
  let procedure_like : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    calc_stream(b"{ { 1 add } dup }"),
    FunctionLimits::default(),
    94L,
  )
  match procedure_like {
    Err(InvalidFunction(offset, reason)) => {
      assert_eq(offset, 94L)
      assert_eq(
        reason, "calculator brace blocks are only allowed before if or ifelse",
      )
    }
    _ => fail("expected procedure-like block rejection")
  }

  let mut limits = FunctionLimits::default()
  limits = FunctionLimits::{ ..limits, max_calculator_tokens: 2 }
  let limited : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    calc_stream(b"{ 1 2 add }"),
    limits,
    95L,
  )
  match limited {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "calculator tokens")
      assert_eq(actual, 3)
      assert_eq(maximum, 2)
    }
    _ => fail("expected token limit failure")
  }
}
