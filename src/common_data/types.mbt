///|
pub(all) enum PdfTextEncoding {
  PDFDocEncoding
  UTF16BE
  UTF8
} derive(Eq, Debug)

///|
pub(all) struct PdfLanguageSpan {
  language : Bytes
  country : Bytes?
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub(all) struct PdfTextString {
  raw : Bytes
  text : String
  encoding : PdfTextEncoding
  language_spans : Array[PdfLanguageSpan]
} derive(Eq, Debug)

///|
pub(all) enum PdfStringKind {
  Text(PdfTextString)
  Ascii(Bytes)
  Byte(Bytes)
} derive(Eq, Debug)

///|
pub(all) enum PdfUtcOffset {
  UnspecifiedGMT
  EqualUT
  LaterThanUT(Int, Int)
  EarlierThanUT(Int, Int)
} derive(Eq, Debug)

///|
pub(all) struct PdfDate {
  raw : Bytes
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  utc_offset : PdfUtcOffset
} derive(Eq, Debug)

///|
pub(all) struct PdfRectangle {
  left : Double
  bottom : Double
  right : Double
  top : Double
} derive(Eq, Debug)

///|
pub(all) struct PdfNameTreeEntry {
  key : Bytes
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfNumberTreeEntry {
  key : Int
  value : @objects.PdfObject
} derive(Eq, Debug)
