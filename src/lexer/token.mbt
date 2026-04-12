///|
pub(all) enum PdfToken {
  Regular(Bytes, Int64)
  Delimiter(Byte, Int64)
  DictStart(Int64)
  DictEnd(Int64)
  HeaderMarker(Int, Int, Int64)
  EofMarker(Int64)
  EndOfInput(Int64)
} derive(Eq, Debug)
