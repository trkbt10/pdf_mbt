///|
/// Text string encoding selected for ISO 32000-2 clause 7.9.2.2. A text
/// string uses PDFDocEncoding unless the required leading bytes identify
/// UTF-16BE or UTF-8. UTF-16BE requires first byte 254 followed by byte 255;
/// UTF-8 requires first byte 239 followed by byte 187 followed by byte 191.
/// Unicode text string processors must handle supplementary characters.
pub(all) enum PdfTextEncoding {
  PDFDocEncoding
  UTF16BE
  UTF8
} derive(Eq, Debug)

///|
/// Caller-selected qualification for a PDF string object from 7.9.2.1. The
/// same fundamental string object is interpreted as a text string, ASCII
/// string, or byte string according to document-hierarchy context.
pub(all) enum PdfStringQualification {
  TextString
  ASCIIString
  ByteString
} derive(Eq, Debug)

///|
/// Metadata for a Unicode text string language escape sequence. The decoded
/// text keeps the ESC bytes in place while this span records the BCP 47
/// language code, optional ISO 3166 country code, and character range.
pub(all) struct PdfLanguageSpan {
  language : Bytes
  country : Bytes?
  start : Int
  end : Int
} derive(Eq, Debug)

///|
/// Decoded document-hierarchy text string with the original string object bytes
/// preserved. These 7.9 string conventions apply outside content streams; an
/// entirely different convention is used within content streams for glyph text.
pub(all) struct PdfTextString {
  raw : Bytes
  text : String
  encoding : PdfTextEncoding
  language_spans : Array[PdfLanguageSpan]
} derive(Eq, Debug)

///|
/// Qualified PDF string object kind from 7.9.2: text string, ASCII string, or
/// byte string. Byte strings preserve arbitrary 8-bit binary data.
pub(all) enum PdfStringKind {
  Text(PdfTextString)
  Ascii(Bytes)
  Byte(Bytes)
} derive(Eq, Debug)

///|
/// Relationship of a PDF date local time to Universal Time. Unspecified date
/// time-zone information is considered GMT without converting to system time.
pub(all) enum PdfUtcOffset {
  UnspecifiedGMT
  EqualUT
  LaterThanUT(Int, Int)
  EarlierThanUT(Int, Int)
} derive(Eq, Debug)

///|
/// Parsed 7.9.4 date value. Date values used in a PDF shall conform to the
/// standard date format that closely follows ASN.1: a text string containing no
/// white-space in the form `D:YYYYMMDDHHmmSSOHH'mm`. The `D:` prefix and year
/// are required. Month range 01 through 12, day range 01 through 31, hour range
/// 00 through 23, minute range 00 through 59, and second range 00 through 59
/// are enforced. Month and day default to 01, other numerical fields default to
/// zero, and raw bytes are retained.
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
/// 7.9.5 rectangle array coordinates in source order: lower-left x,
/// lower-left y, upper-right x, upper-right y. Zero width and zero height are
/// valid and no clipping, transformation, or reordering is applied by parsing.
pub(all) struct PdfRectangle {
  left : Double
  bottom : Double
  right : Double
  top : Double
} derive(Eq, Debug)

///|
/// Returns a rectangle whose lower-left and upper-right coordinates are sorted.
pub fn PdfRectangle::normalized(self : PdfRectangle) -> PdfRectangle {
  let left = if self.left <= self.right { self.left } else { self.right }
  let right = if self.left <= self.right { self.right } else { self.left }
  let bottom = if self.bottom <= self.top { self.bottom } else { self.top }
  let top = if self.bottom <= self.top { self.top } else { self.bottom }
  PdfRectangle::{ left, bottom, right, top }
}

///|
/// Name tree pair from a 7.9.6 `/Names` array. A name tree serves a dictionary
/// like purpose by associating keys and values by different means: unlike
/// dictionary keys, name tree keys are strings, keys are ordered, and the data
/// structure can represent an arbitrarily large collection of key-value pairs
/// for efficient lookup without requiring the entire data structure to be read.
/// Table 36 node dictionaries use Kids, Names, and Limits entries: the root has
/// Kids or Names but not both, intermediate nodes have Limits and Kids, and leaf
/// nodes have Limits and Names. Keys are compared by simple byte-by-byte
/// lexical order with shorter prefix keys before longer keys, each leaf
/// contains a contiguous range, keys do not overlap, and values remain raw PDF
/// objects.
pub(all) struct PdfNameTreeEntry {
  key : Bytes
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Number tree pair from a 7.9.7 `/Nums` array. Keys are integer objects sorted
/// in ascending numeric order, and values remain raw PDF objects.
pub(all) struct PdfNumberTreeEntry {
  key : Int
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Compares this entry key with a caller-supplied number tree key.
pub fn PdfNumberTreeEntry::compare_key(
  self : PdfNumberTreeEntry,
  key : Int,
) -> Int {
  if self.key < key {
    -1
  } else if self.key > key {
    1
  } else {
    0
  }
}
