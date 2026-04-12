///|
#warnings("-unused_value")
fn reader_boundary_probe() -> Unit raise @objects.PdfParseError {
  let _ = @objects.PdfObject::Null
  let _ = @lexer.ByteCursor::new(b"")
  let _ = @parser.parse_object(b"null")
}
