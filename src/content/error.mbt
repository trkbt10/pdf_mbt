///|
/// Content-stream diagnostics preserve decoded-byte offsets and wrap lower
/// level parser/filter failures without changing those packages.
pub(all) suberror PdfContentError {
  MalformedSyntax(Int64, String)
  UnknownOperator(Int64, String)
  IllegalOperand(Int64, String)
  InlineImageFailure(Int64, String)
  ResourceFailure(Int64, String)
  ParseError(Int64, @objects.PdfParseError)
  FilterError(Int64, @filters.PdfFilterError)
} derive(Eq, Debug)
