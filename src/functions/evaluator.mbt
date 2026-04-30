///|
pub fn FunctionCommon::input_count(self : FunctionCommon) -> Int {
  self.domain.length()
}

///|
pub fn FunctionCommon::output_count(self : FunctionCommon) -> Int? {
  match self.range {
    Some(range) => Some(range.length())
    None => None
  }
}

///|
pub fn PdfFunction::common(self : PdfFunction) -> FunctionCommon {
  match self {
    SampledFunction(function) => function.common
    ExponentialFunction(function) => function.common
    StitchingFunction(function) => function.common
    CalculatorFunction(function) => function.common
  }
}

///|
fn clip_to_intervals(
  values : Array[Double],
  intervals : Array[FunctionInterval],
) -> Array[Double] {
  let clipped : Array[Double] = []
  for index in 0..<values.length() {
    clipped.push(intervals[index].clip(values[index]))
  }
  clipped
}

///|
pub fn FunctionCommon::clip_inputs(
  self : FunctionCommon,
  inputs : Array[Double],
  offset? : Int64 = 0L,
) -> Array[Double] raise PdfFunctionError {
  if inputs.length() != self.domain.length() {
    raise PdfFunctionError::EvaluationFailure(
      offset,
      "expected \{self.domain.length()} function inputs, got \{inputs.length()}",
    )
  }
  for value in inputs {
    ensure_finite(value, offset, "function input")
  }
  clip_to_intervals(inputs, self.domain)
}

///|
pub fn FunctionCommon::clip_outputs(
  self : FunctionCommon,
  outputs : Array[Double],
  offset? : Int64 = 0L,
) -> Array[Double] raise PdfFunctionError {
  for value in outputs {
    ensure_finite(value, offset, "function output")
  }
  match self.range {
    Some(range) => {
      if outputs.length() != range.length() {
        raise PdfFunctionError::EvaluationFailure(
          offset,
          "expected \{range.length()} function outputs, got \{outputs.length()}",
        )
      }
      clip_to_intervals(outputs, range)
    }
    None => outputs.copy()
  }
}

///|
pub fn PdfFunction::evaluate(
  self : PdfFunction,
  inputs : Array[Double],
  limits : FunctionLimits,
) -> Array[Double] raise PdfFunctionError {
  let common = self.common()
  let clipped_inputs = common.clip_inputs(inputs)
  limits.max_evaluation_steps |> ignore
  match self {
    SampledFunction(function) =>
      evaluate_sampled_function(function, clipped_inputs)
    ExponentialFunction(function) =>
      evaluate_exponential_function(function, clipped_inputs)
    CalculatorFunction(function) =>
      evaluate_calculator_function(function, clipped_inputs, limits)
    _ =>
      raise PdfFunctionError::EvaluationFailure(
        0L, "function type evaluator is not implemented yet",
      )
  }
}

///|
pub fn evaluate_function_source(
  source : FunctionSource,
  inputs : Array[Double],
  limits : FunctionLimits,
) -> Array[Double] raise PdfFunctionError {
  match source {
    DirectFunction(function) => function.evaluate(inputs, limits)
    IndirectFunction(object_id) =>
      raise PdfFunctionError::UnresolvedFunctionReference(object_id)
  }
}
