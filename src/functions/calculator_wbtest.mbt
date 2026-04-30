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
  dict[calc_name(b"Range")] = calc_array([calc_num(-1000.0), calc_num(1000.0)])
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

///|
fn calc_eval(program : Bytes) -> Array[Double] raise PdfFunctionError {
  let function = parse_direct_function(
    calc_stream(program),
    FunctionLimits::default(),
    100L,
  )
  match function {
    CalculatorFunction(calculator) =>
      evaluate_calculator_function(calculator, [], FunctionLimits::default())
    _ =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "expected calculator function",
      )
  }
}

///|
fn calc_values(
  program : Bytes,
) -> Array[CalculatorValue] raise PdfFunctionError {
  let function = parse_direct_function(
    calc_stream(program),
    FunctionLimits::default(),
    101L,
  )
  match function {
    CalculatorFunction(calculator) => {
      let runtime = CalculatorRuntime::new([], FunctionLimits::default())
      runtime.execute_instructions(calculator.program.instructions)
      runtime.stack
    }
    _ =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "expected calculator function",
      )
  }
}

///|
fn calc_bool(program : Bytes) -> Bool raise PdfFunctionError {
  match calc_values(program) {
    [Boolean(value)] => value
    _ =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "expected one boolean result",
      )
  }
}

///|
fn calc_stack_numbers(program : Bytes) -> Array[Double] raise PdfFunctionError {
  let outputs : Array[Double] = []
  for value in calc_values(program) {
    match value {
      Number(number) => outputs.push(number)
      Boolean(_) =>
        raise PdfFunctionError::EvaluationFailure(
          0L, "expected numeric stack result",
        )
    }
  }
  outputs
}

///|
test "calculator arithmetic operators evaluate numeric stack operands" {
  inspect(calc_eval(b"{ -3 abs }"), content="[3]")
  inspect(calc_eval(b"{ 2 3 add }"), content="[5]")
  inspect(calc_eval(b"{ 1 1 atan }"), content="[45]")
  inspect(calc_eval(b"{ 1.2 ceiling }"), content="[2]")
  inspect(calc_eval(b"{ 60 cos }"), content="[0.5000000000000001]")
  inspect(calc_eval(b"{ 3.8 cvi }"), content="[3]")
  inspect(calc_eval(b"{ 3 cvr }"), content="[3]")
  inspect(calc_eval(b"{ 7 2 div }"), content="[3.5]")
  inspect(calc_eval(b"{ 2 3 exp }"), content="[8]")
  inspect(calc_eval(b"{ 1.8 floor }"), content="[1]")
  inspect(calc_eval(b"{ 7 2 idiv }"), content="[3]")
  inspect(calc_eval(b"{ 2.718281828459045 ln }"), content="[1]")
  inspect(calc_eval(b"{ 100 log }"), content="[2]")
  inspect(calc_eval(b"{ 7 4 mod }"), content="[3]")
  inspect(calc_eval(b"{ 6 7 mul }"), content="[42]")
  inspect(calc_eval(b"{ 5 neg }"), content="[-5]")
  inspect(calc_eval(b"{ 1.5 round }"), content="[2]")
  inspect(calc_eval(b"{ 90 sin }"), content="[1]")
  inspect(calc_eval(b"{ 9 sqrt }"), content="[3]")
  inspect(calc_eval(b"{ 7 2 sub }"), content="[5]")
  inspect(calc_eval(b"{ -1.8 truncate }"), content="[-1]")
}

///|
test "calculator arithmetic operators report numeric failures" {
  let underflow : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ add }",
  )
  match underflow {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator stack underflow")
    _ => fail("expected stack underflow")
  }

  let division : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ 1 0 div }",
  )
  match division {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator division by zero")
    _ => fail("expected division failure")
  }

  let type_error : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ true abs }",
  )
  match type_error {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator operator requires numeric operands")
    _ => fail("expected numeric type failure")
  }
}

///|
test "calculator relational boolean and bitwise operators evaluate typed operands" {
  assert_eq(calc_bool(b"{ 2 2 eq }"), true)
  assert_eq(calc_bool(b"{ 2 3 ne }"), true)
  assert_eq(calc_bool(b"{ 3 2 gt }"), true)
  assert_eq(calc_bool(b"{ 3 3 ge }"), true)
  assert_eq(calc_bool(b"{ 2 3 lt }"), true)
  assert_eq(calc_bool(b"{ 2 2 le }"), true)
  assert_eq(calc_bool(b"{ true false and }"), false)
  assert_eq(calc_bool(b"{ true false or }"), true)
  assert_eq(calc_bool(b"{ true false xor }"), true)
  assert_eq(calc_bool(b"{ true not }"), false)
  inspect(calc_eval(b"{ 6 3 and }"), content="[2]")
  inspect(calc_eval(b"{ 4 1 or }"), content="[5]")
  inspect(calc_eval(b"{ 6 3 xor }"), content="[5]")
  inspect(calc_eval(b"{ 2 not }"), content="[-3]")
  inspect(calc_eval(b"{ 6.9 3.1 and }"), content="[2]")
  inspect(calc_eval(b"{ 1 3 bitshift }"), content="[8]")
  inspect(calc_eval(b"{ 8 -2 bitshift }"), content="[2]")
}

///|
test "calculator relational boolean and bitwise operators reject mismatched operands" {
  let mismatch : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ true 1 eq }",
  )
  match mismatch {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator operands must have matching types")
    _ => fail("expected type mismatch")
  }

  let bool_required : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ true 1 and }",
  )
  match bool_required {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator operands must have matching types")
    _ => fail("expected matching type failure")
  }

  let comparison_type : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ true false gt }",
  )
  match comparison_type {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator operator requires numeric operands")
    _ => fail("expected comparison numeric type failure")
  }

  let bitshift_underflow : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ 1 bitshift }",
  )
  match bitshift_underflow {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator stack underflow")
    _ => fail("expected bitshift underflow")
  }
}

///|
test "calculator conditionals execute selected branches without procedure outputs" {
  inspect(calc_eval(b"{ true { 2 3 add } if }"), content="[5]")
  inspect(calc_eval(b"{ false { 2 } { 7 } ifelse }"), content="[7]")
  inspect(
    calc_eval(b"{ true { false { 1 } { 9 } ifelse } { 0 } ifelse }"),
    content="[9]",
  )

  let type_error : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ 1 { 2 } if }",
  )
  match type_error {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator if requires boolean condition")
    _ => fail("expected conditional type failure")
  }
}

///|
test "calculator stack operators manipulate typed stack entries" {
  inspect(calc_stack_numbers(b"{ 1 2 dup add add }"), content="[5]")
  inspect(calc_stack_numbers(b"{ 1 2 exch sub }"), content="[1]")
  inspect(calc_stack_numbers(b"{ 1 2 3 pop add }"), content="[3]")
  inspect(
    calc_stack_numbers(b"{ 1 2 3 2 copy add add add add }"),
    content="[11]",
  )
  inspect(
    calc_stack_numbers(b"{ 8 13 21 1 index add exch pop }"),
    content="[8, 34]",
  )
  inspect(calc_stack_numbers(b"{ 1 2 3 3 1 roll }"), content="[3, 1, 2]")
  inspect(calc_stack_numbers(b"{ 1 2 3 3 -1 roll }"), content="[2, 3, 1]")
}

///|
test "calculator stack operators reject invalid counts and depths" {
  let negative_copy : Result[Array[Double], PdfFunctionError] = try? calc_stack_numbers(
    b"{ 1 -1 copy }",
  )
  match negative_copy {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator copy requires a non-negative count")
    _ => fail("expected negative copy failure")
  }

  let deep_index : Result[Array[Double], PdfFunctionError] = try? calc_stack_numbers(
    b"{ 1 1 index }",
  )
  match deep_index {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator index exceeds stack depth")
    _ => fail("expected index depth failure")
  }

  let deep_roll : Result[Array[Double], PdfFunctionError] = try? calc_stack_numbers(
    b"{ 1 2 3 roll }",
  )
  match deep_roll {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "calculator roll exceeds stack depth")
    _ => fail("expected roll depth failure")
  }
}

///|
test "calculator limits cover stack depth evaluation steps and final arity" {
  let mut stack_limits = FunctionLimits::default()
  stack_limits = FunctionLimits::{
    ..stack_limits,
    max_calculator_stack_depth: 1,
  }
  let stack_limited_function = parse_direct_function(
    calc_stream(b"{ 1 2 }"),
    FunctionLimits::default(),
    110L,
  )
  let stack_limited : Result[Array[Double], PdfFunctionError] = match
    stack_limited_function {
    CalculatorFunction(calculator) =>
      try? evaluate_calculator_function(calculator, [], stack_limits)
    _ =>
      Err(
        PdfFunctionError::EvaluationFailure(0L, "expected calculator function"),
      )
  }
  match stack_limited {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "calculator stack depth")
      assert_eq(actual, 2)
      assert_eq(maximum, 1)
    }
    _ => fail("expected stack depth limit failure")
  }

  let mut block_limits = FunctionLimits::default()
  block_limits = FunctionLimits::{ ..block_limits, max_recursion_depth: 1 }
  let block_limited : Result[PdfFunction, PdfFunctionError] = try? parse_direct_function(
    calc_stream(b"{ true { 1 } if }"),
    block_limits,
    111L,
  )
  match block_limited {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "calculator block depth")
      assert_eq(actual, 2)
      assert_eq(maximum, 1)
    }
    _ => fail("expected nested block depth limit failure")
  }

  let mut step_limits = FunctionLimits::default()
  step_limits = FunctionLimits::{ ..step_limits, max_evaluation_steps: 2 }
  let step_limited_function = parse_direct_function(
    calc_stream(b"{ true { 1 2 add } if }"),
    FunctionLimits::default(),
    112L,
  )
  let step_limited : Result[Array[Double], PdfFunctionError] = match
    step_limited_function {
    CalculatorFunction(calculator) =>
      try? evaluate_calculator_function(calculator, [], step_limits)
    _ =>
      Err(
        PdfFunctionError::EvaluationFailure(0L, "expected calculator function"),
      )
  }
  match step_limited {
    Err(LimitExceeded(name, actual, maximum)) => {
      assert_eq(name, "calculator evaluation steps")
      assert_eq(actual, 3)
      assert_eq(maximum, 2)
    }
    _ => fail("expected evaluation step limit failure")
  }

  let wrong_outputs : Result[Array[Double], PdfFunctionError] = try? calc_eval(
    b"{ 1 2 }",
  )
  match wrong_outputs {
    Err(EvaluationFailure(_, reason)) =>
      assert_eq(reason, "expected 1 calculator outputs, got 2")
    _ => fail("expected final output arity failure")
  }
}
