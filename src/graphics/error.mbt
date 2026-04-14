///|
/// Graphics interpretation failures for ISO 32000-2 clause 8 semantics.
/// Diagnostics carry decoded-content operator offsets when the failure is
/// tied to a content stream instruction.
pub(all) suberror PdfGraphicsError {
  BadOperand(Int64, String)
  InvalidGraphicsState(Int64, String)
  GraphicsStackUnderflow(Int64)
  InvalidPathState(Int64, String)
  InvalidObjectContext(Int64, String)
  ResourceFailure(Int64, String)
  InvalidXObject(Int64, String)
  InvalidImage(Int64, String)
  InvalidOptionalContent(Int64, String)
  InterchangeFailure(@interchange.PdfInterchangeError)
  ContentFailure(@content.PdfContentError)
} derive(Eq, Debug)
