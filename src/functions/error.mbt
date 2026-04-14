///|
/// Function-domain failures for ISO 32000-2 clause 7.10 semantics.
pub(all) suberror PdfFunctionError {
  InvalidFunction(Int64, String)
  EvaluationFailure(Int64, String)
  UnresolvedFunctionReference(@objects.ObjectId)
  LimitExceeded(String, Int, Int)
  FilterFailure(@filters.PdfFilterError)
} derive(Eq, Debug)
