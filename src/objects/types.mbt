///|
pub(all) struct PdfName {
  bytes : Bytes
} derive(Eq, Hash, Debug)

///|
pub fn PdfName::new(bytes : Bytes) -> PdfName {
  PdfName::{ bytes, }
}

///|
pub fn PdfName::to_text(self : PdfName) -> String {
  @utf8.decode_lossy(self.bytes)
}

///|
pub type PdfDictionary = Map[PdfName, PdfObject]

///|
pub(all) struct PdfStream {
  dict : PdfDictionary
  data : Bytes
} derive(Eq, Debug)

///|
pub(all) struct ObjectId {
  object_number : Int
  generation_number : Int
} derive(Eq, Hash, Debug)

///|
pub(all) struct IndirectObject {
  id : ObjectId
  value : PdfObject
  start_offset : Int64
  end_offset : Int64
} derive(Eq, Debug)

///|
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
