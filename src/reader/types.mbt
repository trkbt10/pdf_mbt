///|
/// PDF version pair used by reader metadata and header validation.
pub(all) struct PdfVersion {
  major : Int
  minor : Int
} derive(Eq, Debug)

///|
/// Parsed PDF header with the version, binary-indicator flag, and the
/// physical offset of the leading `%` byte.
pub(all) struct PdfHeader {
  version : PdfVersion
  base_offset : Int64
  has_binary_indicator : Bool
} derive(Eq, Debug)

///|
/// PDF file identifier pair from the trailer dictionary `ID` entry.
pub(all) struct PdfFileId {
  first : Bytes
  second : Bytes
} derive(Eq, Debug)

///|
/// Trailer metadata extracted from a cross-reference section or resolved from
/// a cross-reference section chain.
pub(all) struct TrailerInfo {
  size : Int
  root : @objects.ObjectId?
  prev : Int64?
  encrypt : @objects.ObjectId?
  info : @objects.ObjectId?
  id : PdfFileId?
  xref_stm : Int64?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Origin of a parsed cross-reference section.
pub(all) enum XrefSectionSource {
  Table
  Stream
} derive(Eq, Debug)

///|
/// Provenance for one parsed cross-reference section.
pub(all) struct XrefSectionProvenance {
  source : XrefSectionSource
  pdf_offset : Int64
} derive(Eq, Debug)

///|
/// Traditional or stream cross-reference entry data grouped with the object
/// number carried by the enclosing section.
pub(all) struct XrefSectionEntry {
  object_number : Int
  entry : XrefEntry
} derive(Eq, Debug)

///|
/// Raw cross-reference entry shapes from table or stream parsing.
pub(all) enum XrefEntry {
  Free(Int, Int)
  InUse(Int64, Int)
  Compressed(Int, Int)
} derive(Eq, Debug)

///|
/// Location of an indirect object after cross-reference resolution.
pub(all) enum ObjectLocation {
  Uncompressed(Int64, Int)
  Compressed(Int, Int)
} derive(Eq, Debug)

///|
/// Cached decoded object-stream member identity and parsed direct object.
pub struct ObjectStreamTableCacheEntry {
  object_number : Int
  object : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Cached decoded object-stream members and their parse offset.
pub struct ObjectStreamTableCache {
  offset : Int64
  members : Array[ObjectStreamTableCacheEntry]
} derive(Eq, Debug)

///|
/// One parsed cross-reference section and its provenance.
pub(all) struct XrefSection {
  provenance : XrefSectionProvenance
  entries : Array[XrefSectionEntry]
  trailer : TrailerInfo
} derive(Eq, Debug)

///|
/// Resolved active object-location map after xref merge.
pub type XrefIndex = Map[@objects.ObjectId, ObjectLocation]

///|
/// Opened-file state owned by the reader package.
pub struct PdfFile {
  bytes : Bytes
  header : PdfHeader
  trailer : TrailerInfo
  sections : Array[XrefSection]
  xref_index : XrefIndex
  priv mut encryption : @encryption.EncryptionKey?
  cache : Map[@objects.ObjectId, @objects.PdfObject]
  object_stream_tables : Map[@objects.ObjectId, ObjectStreamTableCache]
} derive(Eq, Debug)

///|
/// True when the header version is PDF 2.0 or a later major version.
pub fn PdfVersion::is_pdf2_or_later(self : PdfVersion) -> Bool {
  if self.major > 2 {
    true
  } else if self.major == 2 {
    self.minor >= 0
  } else {
    false
  }
}

///|
/// True when the parsed header has a valid offset and binary indicator state.
pub fn PdfHeader::has_valid_preamble(self : PdfHeader) -> Bool {
  if self.base_offset < 0L {
    false
  } else if self.version.major < 1 {
    false
  } else {
    self.has_binary_indicator || self.base_offset >= 0L
  }
}

///|
/// True when trailer entries indicate an incremental or hybrid xref update.
pub fn TrailerInfo::has_incremental_update(self : TrailerInfo) -> Bool {
  if self.prev is Some(offset) && offset >= 0L {
    true
  } else if self.xref_stm is Some(offset) && offset >= 0L {
    true
  } else {
    self.raw_dict.contains(@objects.PdfName::new(b"Prev"))
  }
}

///|
/// True when a cross-reference entry can resolve to an object value.
pub fn XrefEntry::is_live_object(self : XrefEntry) -> Bool {
  match self {
    InUse(offset, generation) => offset >= 0L && generation >= 0
    Compressed(object_stream, index) => object_stream > 0 && index >= 0
    Free(_, _) => false
  }
}

///|
/// True when an object location requires object-stream table lookup.
pub fn ObjectLocation::requires_object_stream(self : ObjectLocation) -> Bool {
  match self {
    Compressed(object_stream, index) => object_stream > 0 && index >= 0
    Uncompressed(offset, generation) => offset < 0L || generation < 0
  }
}
