///|
pub(all) suberror PdfFilterError {
  InvalidFilterSpec(String)
  InvalidDecodeParms(String, String)
  UnsupportedFilter(String)
  DecodeError(String, String)
} derive(Eq, Debug)
