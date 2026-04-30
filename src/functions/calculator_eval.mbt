///|
priv struct CalculatorRuntime {
  stack : Array[CalculatorValue]
  limits : FunctionLimits
  mut steps : Int
}

///|
fn CalculatorRuntime::new(
  inputs : Array[Double],
  limits : FunctionLimits,
) -> CalculatorRuntime {
  let stack : Array[CalculatorValue] = []
  for input in inputs {
    stack.push(Number(input))
  }
  CalculatorRuntime::{ stack, limits, steps: 0 }
}

///|
fn CalculatorRuntime::step(
  self : CalculatorRuntime,
) -> Unit raise PdfFunctionError {
  self.steps = self.steps + 1
  check_limit(
    "calculator evaluation steps",
    self.steps,
    self.limits.max_evaluation_steps,
  )
}

///|
fn CalculatorRuntime::push(
  self : CalculatorRuntime,
  value : CalculatorValue,
) -> Unit raise PdfFunctionError {
  self.stack.push(value)
  check_limit(
    "calculator stack depth",
    self.stack.length(),
    self.limits.max_calculator_stack_depth,
  )
}

///|
fn CalculatorRuntime::pop(
  self : CalculatorRuntime,
) -> CalculatorValue raise PdfFunctionError {
  match self.stack.pop() {
    Some(value) => value
    None =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "calculator stack underflow",
      )
  }
}

///|
fn CalculatorRuntime::pop_number(
  self : CalculatorRuntime,
) -> Double raise PdfFunctionError {
  match self.pop() {
    Number(value) => value
    Boolean(_) =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "calculator operator requires numeric operands",
      )
  }
}

///|
fn ensure_calculator_finite(
  value : Double,
  label : String,
) -> Double raise PdfFunctionError {
  ensure_finite(value, 0L, label)
  value
}

///|
fn calculator_int(value : Double) -> Int raise PdfFunctionError {
  if value.is_nan() || value.is_inf() {
    raise PdfFunctionError::EvaluationFailure(
      0L, "calculator integer operand must be finite",
    )
  }
  @math.trunc(value).to_int()
}

///|
fn eval_arithmetic_operator(
  runtime : CalculatorRuntime,
  operator : CalculatorOperator,
) -> Bool raise PdfFunctionError {
  match operator {
    Abs => {
      let value = runtime.pop_number()
      runtime.push(Number(if value < 0.0 { -value } else { value }))
      true
    }
    Add => {
      let b = runtime.pop_number()
      let a = runtime.pop_number()
      runtime.push(
        Number(ensure_calculator_finite(a + b, "calculator add result")),
      )
      true
    }
    Atan => {
      let den = runtime.pop_number()
      let num = runtime.pop_number()
      runtime.push(
        Number(
          ensure_calculator_finite(
            @math.atan2(num, den) * 180.0 / @math.PI,
            "calculator atan result",
          ),
        ),
      )
      true
    }
    Ceiling => {
      runtime.push(Number(@math.ceil(runtime.pop_number())))
      true
    }
    Cos => {
      runtime.push(
        Number(
          ensure_calculator_finite(
            @math.cos(runtime.pop_number() * @math.PI / 180.0),
            "calculator cos result",
          ),
        ),
      )
      true
    }
    Cvi => {
      runtime.push(Number(calculator_int(runtime.pop_number()).to_double()))
      true
    }
    Cvr => {
      runtime.push(Number(runtime.pop_number()))
      true
    }
    Div => {
      let b = runtime.pop_number()
      let a = runtime.pop_number()
      if b == 0.0 {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator division by zero",
        )
      }
      runtime.push(
        Number(ensure_calculator_finite(a / b, "calculator div result")),
      )
      true
    }
    Exp => {
      let exponent = runtime.pop_number()
      let base = runtime.pop_number()
      runtime.push(
        Number(
          ensure_calculator_finite(
            @math.pow(base, exponent),
            "calculator exp result",
          ),
        ),
      )
      true
    }
    Floor => {
      runtime.push(Number(@math.floor(runtime.pop_number())))
      true
    }
    Idiv => {
      let b = calculator_int(runtime.pop_number())
      let a = calculator_int(runtime.pop_number())
      if b == 0 {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator division by zero",
        )
      }
      runtime.push(Number((a / b).to_double()))
      true
    }
    Ln => {
      let value = runtime.pop_number()
      if value <= 0.0 {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator ln requires positive operand",
        )
      }
      runtime.push(Number(@math.ln(value)))
      true
    }
    Log => {
      let value = runtime.pop_number()
      if value <= 0.0 {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator log requires positive operand",
        )
      }
      runtime.push(Number(@math.log10(value)))
      true
    }
    Mod => {
      let b = calculator_int(runtime.pop_number())
      let a = calculator_int(runtime.pop_number())
      if b == 0 {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator division by zero",
        )
      }
      runtime.push(Number((a % b).to_double()))
      true
    }
    Mul => {
      let b = runtime.pop_number()
      let a = runtime.pop_number()
      runtime.push(
        Number(ensure_calculator_finite(a * b, "calculator mul result")),
      )
      true
    }
    Neg => {
      runtime.push(Number(-runtime.pop_number()))
      true
    }
    Round => {
      runtime.push(Number(@math.round(runtime.pop_number())))
      true
    }
    Sin => {
      runtime.push(
        Number(
          ensure_calculator_finite(
            @math.sin(runtime.pop_number() * @math.PI / 180.0),
            "calculator sin result",
          ),
        ),
      )
      true
    }
    Sqrt => {
      let value = runtime.pop_number()
      if value < 0.0 {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator sqrt requires non-negative operand",
        )
      }
      runtime.push(Number(@math.pow(value, 0.5)))
      true
    }
    Sub => {
      let b = runtime.pop_number()
      let a = runtime.pop_number()
      runtime.push(
        Number(ensure_calculator_finite(a - b, "calculator sub result")),
      )
      true
    }
    Truncate => {
      runtime.push(Number(@math.trunc(runtime.pop_number())))
      true
    }
    _ => false
  }
}

///|
fn CalculatorRuntime::execute_instruction(
  self : CalculatorRuntime,
  instruction : CalculatorInstruction,
) -> Unit raise PdfFunctionError {
  self.step()
  match instruction {
    CalculatorNumber(value) => self.push(Number(value))
    CalculatorBoolean(value) => self.push(Boolean(value))
    CalculatorOperator(operator) =>
      if !eval_arithmetic_operator(self, operator) {
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator operator is not implemented yet",
        )
      }
    CalculatorBlock(_) =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "calculator conditional execution is not implemented yet",
      )
  }
}

///|
fn evaluate_calculator_function(
  function : CalculatorFunction,
  clipped_inputs : Array[Double],
  limits : FunctionLimits,
) -> Array[Double] raise PdfFunctionError {
  let runtime = CalculatorRuntime::new(clipped_inputs, limits)
  for instruction in function.program.instructions {
    runtime.execute_instruction(instruction)
  }
  let output_count = require_range(function.common, 0L, "Type 4").length()
  if runtime.stack.length() != output_count {
    raise PdfFunctionError::EvaluationFailure(
      0L,
      "expected \{output_count} calculator outputs, got \{runtime.stack.length()}",
    )
  }
  let outputs : Array[Double] = []
  for value in runtime.stack {
    match value {
      Number(number) => outputs.push(number)
      Boolean(_) =>
        raise PdfFunctionError::EvaluationFailure(
          0L, "calculator outputs must be numeric",
        )
    }
  }
  function.common.clip_outputs(outputs)
}
