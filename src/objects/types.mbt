///|
/// ISO 32000-2 section 7.3.5 Name object value. PdfName stores the decoded
/// byte sequence after the SOLIDUS prefix and any #XX hex escape expansion.
pub(all) struct PdfName {
  bytes : Bytes
} derive(Eq, Hash, Debug)

///|
/// Creates a Name object payload with byte-sequence equality.
pub fn PdfName::new(bytes : Bytes) -> PdfName {
  PdfName::{ bytes, }
}

///|
/// Decodes Name object bytes as UTF-8 for display only; equality remains
/// exact byte-sequence comparison.
pub fn PdfName::to_text(self : PdfName) -> String {
  @utf8.decode_lossy(self.bytes)
}

///|
/// ISO 32000-2 section 7.3.7 Dictionary objects are delimited by `<<` and
/// `>>` and store key-value pairs with name keys; null values are omitted by
/// the parser.
pub type PdfDictionary = Map[PdfName, PdfObject]

///|
/// ISO 32000-2 section 7.3.8 Stream object, pairing the stream dictionary
/// with exact raw bytes read from the required Length entry before endstream.
pub(all) struct PdfStream {
  dict : PdfDictionary
  data : Bytes
} derive(Eq, Debug)

///|
/// Identifier for an ISO 32000-2 section 7.3.10 indirect object or indirect
/// reference, made from object number and generation number. The `N G R`
/// notation forms an indirect reference from object number N and generation
/// number G to an indirect object.
pub(all) struct ObjectId {
  object_number : Int
  generation_number : Int
} derive(Eq, Hash, Debug)

///|
/// Parsed ISO 32000-2 section 7.3.10 indirect object definition in the
/// N G obj ... endobj form.
pub(all) struct IndirectObject {
  id : ObjectId
  value : PdfObject
  start_offset : Int64
  end_offset : Int64
} derive(Eq, Debug)

///|
/// Type-safe ISO 32000-2 section 7.3 object model. A Comment or PDF comment
/// starts with % and extends to end-of-line; it is lexically-significant only
/// inside content streams; otherwise treated as whitespace and not represented
/// as a PdfObject. Outside strings and streams, CR, LF, and CRLF are
/// end-of-line (EOL) markers, consecutive white-space is one separator, and a
/// delimiter terminates the preceding token before an object is built.
///
/// Boolean object true/false, Integer object as a signed decimal integer,
/// Real object with PERIOD decimal point, literal string or hexadecimal string
/// bytes, Name object, Array, Dictionary objects delimited by `<<` and `>>`
/// with key-value pairs and name keys, Stream object, Null object, and
/// indirect reference. An indirect reference uses `N G R`, where N is the
/// object number and G is the generation number, to refer to an indirect
/// object.
pub(all) enum PdfObject {
  Boolean(Bool)
  Integer(Int64)
  Real(Double)
  String(Bytes)
  Name(PdfName)
  Array(Array[PdfObject])
  Dictionary(PdfDictionary)
  Stream(PdfStream)
  Null
  Ref(ObjectId)
} derive(Eq, Debug)
