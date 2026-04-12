///|
pub type LexedName = @objects.PdfName

///|
fn _object_from_lexed_name(name : LexedName) -> @objects.PdfObject {
  @objects.PdfObject::Name(name)
}
