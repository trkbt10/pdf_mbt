///|
/// Clause 7.9 common-data validation diagnostics. Messages describe shape and
/// offset failures without dumping complete arbitrary byte payloads.
pub(all) suberror PdfCommonDataError {
  ExpectedString(String)
  InvalidTextString(String)
  InvalidAsciiString(String)
  InvalidDate(Bytes, String)
  InvalidRectangle(String)
  InvalidTreeNode(String)
} derive(Eq, Debug)

///|
fn common_object_kind(object : @objects.PdfObject) -> String {
  match object {
    @objects.PdfObject::Boolean(_) => "boolean"
    @objects.PdfObject::Integer(_) => "integer"
    @objects.PdfObject::Real(_) => "real"
    @objects.PdfObject::String(_) => "string"
    @objects.PdfObject::Name(_) => "name"
    @objects.PdfObject::Array(_) => "array"
    @objects.PdfObject::Dictionary(_) => "dictionary"
    @objects.PdfObject::Stream(_) => "stream"
    @objects.PdfObject::Null => "null"
    @objects.PdfObject::Ref(_) => "ref"
  }
}
