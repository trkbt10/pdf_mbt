///|
/// Returns the number of input values m implied by the Domain array.
pub fn FunctionCommon::input_count(self : FunctionCommon) -> Int {
  self.domain.length()
}

///|
/// Returns the number of output values n implied by Range when the function
/// dictionary declares output clipping.
pub fn FunctionCommon::output_count(self : FunctionCommon) -> Int? {
  match self.range {
    Some(range) => Some(range.length())
    None => None
  }
}

///|
/// Returns the Table 38 common entries shared by a sampled, exponential,
/// stitching, or PostScript calculator function.
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
/// Clips each input value to the declared Domain interval before evaluation.
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
/// Clips each produced output value to the declared Range interval when Range
/// is present; if Range is absent no output clipping is done.
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
/// Evaluates a PDF function as a side-effect-free numerical transformation:
/// inputs are clipped to Domain, Type 0/2/3/4 semantics run, and outputs are
/// clipped to Range when present.
pub fn PdfFunction::evaluate(
  self : PdfFunction,
  inputs : Array[Double],
  limits : FunctionLimits,
) -> Array[Double] raise PdfFunctionError {
  evaluate_function_with_depth(self, inputs, limits, 1)
}

///|
fn evaluate_function_with_depth(
  function : PdfFunction,
  inputs : Array[Double],
  limits : FunctionLimits,
  depth : Int,
) -> Array[Double] raise PdfFunctionError {
  check_limit("function recursion depth", depth, limits.max_recursion_depth)
  let common = function.common()
  let clipped_inputs = common.clip_inputs(inputs)
  check_limit("function evaluation steps", 1, limits.max_evaluation_steps)
  match function {
    SampledFunction(sampled) =>
      evaluate_sampled_function(sampled, clipped_inputs)
    ExponentialFunction(exponential) =>
      evaluate_exponential_function(exponential, clipped_inputs)
    CalculatorFunction(calculator) =>
      evaluate_calculator_function(calculator, clipped_inputs, limits)
    StitchingFunction(stitching) =>
      evaluate_stitching_function_with_depth(
        stitching, clipped_inputs, limits, depth,
      )
  }
}

///|
/// Evaluates a direct function source and rejects unresolved indirect function
/// references until the reader materializes them.
pub fn evaluate_function_source(
  source : FunctionSource,
  inputs : Array[Double],
  limits : FunctionLimits,
) -> Array[Double] raise PdfFunctionError {
  evaluate_function_source_with_depth(source, inputs, limits, 1)
}

///|
fn evaluate_function_source_with_depth(
  source : FunctionSource,
  inputs : Array[Double],
  limits : FunctionLimits,
  depth : Int,
) -> Array[Double] raise PdfFunctionError {
  match source {
    DirectFunction(function) =>
      evaluate_function_with_depth(function, inputs, limits, depth)
    IndirectFunction(object_id) =>
      raise PdfFunctionError::UnresolvedFunctionReference(object_id)
  }
}
