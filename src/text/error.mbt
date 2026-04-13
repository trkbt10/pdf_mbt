///|
/// Text diagnostics carry decoded-content operator offsets and optional
/// resource context. The text package never loads indirect objects, so resource
/// paths describe the already materialized resource graph supplied by callers.
pub(all) struct TextErrorContext {
  offset : Int64
  resource : String?
} derive(Eq, Debug)

///|
pub fn TextErrorContext::at(offset : Int64) -> TextErrorContext {
  TextErrorContext::{ offset, resource: None }
}

///|
pub fn TextErrorContext::with_resource(
  offset : Int64,
  resource : String,
) -> TextErrorContext {
  TextErrorContext::{ offset, resource: Some(resource) }
}

///|
pub(all) suberror PdfTextError {
  BadOperand(TextErrorContext, String)
  InvalidTextState(TextErrorContext, String)
  MissingResource(TextErrorContext, String)
  InvalidFont(TextErrorContext, String)
  InvalidCMap(TextErrorContext, String)
  UnicodeConversion(TextErrorContext, String)
  GuardLimitExceeded(TextErrorContext, String)
  ContentFailure(TextErrorContext, @content.PdfContentError)
  FilterFailure(TextErrorContext, @filters.PdfFilterError)
} derive(Eq, Debug)
