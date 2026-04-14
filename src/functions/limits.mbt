///|
/// Caller-visible guardrails for parsing and evaluating PDF functions.
pub(all) struct FunctionLimits {
  max_decoded_stream_bytes : Int
  max_sample_values : Int
  max_input_dimensions : Int
  max_output_dimensions : Int
  max_recursion_depth : Int
  max_calculator_tokens : Int
  max_calculator_stack_depth : Int
  max_evaluation_steps : Int
} derive(Eq, Debug)

///|
pub fn FunctionLimits::default() -> FunctionLimits {
  FunctionLimits::{
    max_decoded_stream_bytes: 1_048_576,
    max_sample_values: 1_000_000,
    max_input_dimensions: 16,
    max_output_dimensions: 32,
    max_recursion_depth: 16,
    max_calculator_tokens: 4096,
    max_calculator_stack_depth: 256,
    max_evaluation_steps: 100_000,
  }
}

///|
fn check_limit(
  name : String,
  actual : Int,
  maximum : Int,
) -> Unit raise PdfFunctionError {
  if actual > maximum {
    raise PdfFunctionError::LimitExceeded(name, actual, maximum)
  }
}
