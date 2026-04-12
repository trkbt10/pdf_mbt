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
/// Trailer metadata extracted from the latest cross-reference section.
pub(all) struct TrailerInfo {
  size : Int
  root : @objects.ObjectId
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
  cache : Map[@objects.ObjectId, @objects.PdfObject]
} derive(Eq, Debug)
