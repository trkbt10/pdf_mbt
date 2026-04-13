///|
pub(all) suberror PdfFilterError {
  InvalidFilterSpec(String)
  UnsupportedFilter(String)
} derive(Eq, Debug)
