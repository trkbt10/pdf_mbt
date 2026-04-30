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
fn calculator_values_equal(
  left : CalculatorValue,
  right : CalculatorValue,
) -> Bool raise PdfFunctionError {
  match (left, right) {
    (Number(a), Number(b)) => a == b
    (Boolean(a), Boolean(b)) => a == b
    _ =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "calculator operands must have matching types",
      )
  }
}

///|
fn calculator_value_copy(value : CalculatorValue) -> CalculatorValue {
  match value {
    Number(number) => Number(number)
    Boolean(boolean) => Boolean(boolean)
  }
}

///|
fn require_stack_extent(
  runtime : CalculatorRuntime,
  count : Int,
  operation : String,
) -> Unit raise PdfFunctionError {
  if count < 0 {
    raise PdfFunctionError::EvaluationFailure(
      0L,
      "calculator \{operation} requires a non-negative count",
    )
  }
  if count > runtime.stack.length() {
    raise PdfFunctionError::EvaluationFailure(
      0L,
      "calculator \{operation} exceeds stack depth",
    )
  }
}

///|
fn positive_mod(value : Int, modulus : Int) -> Int {
  let result = value % modulus
  if result < 0 {
    result + modulus
  } else {
    result
  }
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
fn eval_relational_boolean_bitwise_operator(
  runtime : CalculatorRuntime,
  operator : CalculatorOperator,
) -> Bool raise PdfFunctionError {
  match operator {
    Eq => {
      let b = runtime.pop()
      let a = runtime.pop()
      runtime.push(Boolean(calculator_values_equal(a, b)))
      true
    }
    Ne => {
      let b = runtime.pop()
      let a = runtime.pop()
      runtime.push(Boolean(!calculator_values_equal(a, b)))
      true
    }
    Gt | Ge | Lt | Le => {
      let b = runtime.pop_number()
      let a = runtime.pop_number()
      runtime.push(
        Boolean(
          match operator {
            Gt => a > b
            Ge => a >= b
            Lt => a < b
            Le => a <= b
            _ => false
          },
        ),
      )
      true
    }
    And | Or | Xor => {
      let b = runtime.pop()
      let a = runtime.pop()
      match (a, b) {
        (Boolean(left), Boolean(right)) => {
          let result = match operator {
            And => left && right
            Or => left || right
            Xor => left != right
            _ => false
          }
          runtime.push(Boolean(result))
        }
        (Number(left), Number(right)) => {
          let li = calculator_int(left)
          let ri = calculator_int(right)
          let result = match operator {
            And => li & ri
            Or => li | ri
            Xor => li ^ ri
            _ => 0
          }
          runtime.push(Number(result.to_double()))
        }
        _ =>
          raise PdfFunctionError::EvaluationFailure(
            0L, "calculator operands must have matching types",
          )
      }
      true
    }
    Not => {
      match runtime.pop() {
        Boolean(value) => runtime.push(Boolean(!value))
        Number(value) => {
          let integer = calculator_int(value)
          runtime.push(Number((-integer - 1).to_double()))
        }
      }
      true
    }
    Bitshift => {
      let shift = calculator_int(runtime.pop_number())
      let value = calculator_int(runtime.pop_number())
      runtime.push(
        Number(
          if shift < 0 {
            (value >> -shift).to_double()
          } else {
            (value << shift).to_double()
          },
        ),
      )
      true
    }
    _ => false
  }
}

///|
fn eval_stack_operator(
  runtime : CalculatorRuntime,
  operator : CalculatorOperator,
) -> Bool raise PdfFunctionError {
  match operator {
    Pop => {
      runtime.pop() |> ignore
      true
    }
    Dup => {
      let value = runtime.pop()
      runtime.push(calculator_value_copy(value))
      runtime.push(value)
      true
    }
    Exch => {
      let top = runtime.pop()
      let below = runtime.pop()
      runtime.push(top)
      runtime.push(below)
      true
    }
    Copy => {
      let count = calculator_int(runtime.pop_number())
      require_stack_extent(runtime, count, "copy")
      let start = runtime.stack.length() - count
      for index in start..<runtime.stack.length() {
        runtime.push(calculator_value_copy(runtime.stack[index]))
      }
      true
    }
    Index => {
      let depth = calculator_int(runtime.pop_number())
      require_stack_extent(runtime, depth + 1, "index")
      let source = runtime.stack.length() - depth - 1
      runtime.push(calculator_value_copy(runtime.stack[source]))
      true
    }
    Roll => {
      let shift = calculator_int(runtime.pop_number())
      let count = calculator_int(runtime.pop_number())
      require_stack_extent(runtime, count, "roll")
      if count > 0 {
        let start = runtime.stack.length() - count
        let values : Array[CalculatorValue] = []
        for index in start..<runtime.stack.length() {
          values.push(calculator_value_copy(runtime.stack[index]))
        }
        for _ in 0..<count {
          runtime.pop() |> ignore
        }
        let amount = positive_mod(shift, count)
        for offset in 0..<count {
          let source = positive_mod(offset - amount, count)
          runtime.push(calculator_value_copy(values[source]))
        }
      }
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
      if !eval_arithmetic_operator(self, operator) &&
        !eval_relational_boolean_bitwise_operator(self, operator) &&
        !eval_stack_operator(self, operator) {
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
fn CalculatorRuntime::execute_instructions(
  self : CalculatorRuntime,
  instructions : Array[CalculatorInstruction],
) -> Unit raise PdfFunctionError {
  let mut index = 0
  while index < instructions.length() {
    match instructions[index] {
      CalculatorBlock(block) =>
        if index + 1 < instructions.length() &&
          is_operator(instructions[index + 1], If) {
          self.step()
          match self.pop() {
            Boolean(condition) =>
              if condition {
                self.execute_instructions(block)
              }
            Number(_) =>
              raise PdfFunctionError::EvaluationFailure(
                0L, "calculator if requires boolean condition",
              )
          }
          index = index + 2
        } else if index + 2 < instructions.length() {
          match instructions[index + 1] {
            CalculatorBlock(other) =>
              if is_operator(instructions[index + 2], Ifelse) {
                self.step()
                match self.pop() {
                  Boolean(condition) =>
                    if condition {
                      self.execute_instructions(block)
                    } else {
                      self.execute_instructions(other)
                    }
                  Number(_) =>
                    raise PdfFunctionError::EvaluationFailure(
                      0L, "calculator ifelse requires boolean condition",
                    )
                }
                index = index + 3
              } else {
                raise PdfFunctionError::EvaluationFailure(
                  0L, "calculator conditional block is malformed",
                )
              }
            _ =>
              raise PdfFunctionError::EvaluationFailure(
                0L, "calculator conditional block is malformed",
              )
          }
        } else {
          raise PdfFunctionError::EvaluationFailure(
            0L, "calculator conditional block is malformed",
          )
        }
      _ => {
        self.execute_instruction(instructions[index])
        index = index + 1
      }
    }
  }
}

///|
fn evaluate_calculator_function(
  function : CalculatorFunction,
  clipped_inputs : Array[Double],
  limits : FunctionLimits,
) -> Array[Double] raise PdfFunctionError {
  let runtime = CalculatorRuntime::new(clipped_inputs, limits)
  runtime.execute_instructions(function.program.instructions)
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
