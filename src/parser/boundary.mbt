///|
fn _object_from_lexer_name(name : @lexer.LexedName) -> @objects.PdfObject {
  @objects.PdfObject::Name(name)
}
