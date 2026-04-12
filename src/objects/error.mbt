///|
pub(all) suberror PdfParseError {
  UnexpectedToken(Int64, String, String)
  UnexpectedEof(Int64, String)
  InvalidNumber(Int64, Bytes)
  NumericOverflow(Int64, Bytes)
  InvalidName(Int64, String)
  InvalidDictionary(Int64, String)
  InvalidStream(Int64, String)
  InvalidIndirectObject(Int64, String)
} derive(Eq, Debug)
