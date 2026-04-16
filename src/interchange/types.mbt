///|
/// Valid metadata stream wrapper. `raw_stream` preserves the stream object
/// exactly as supplied by the owner, while `xml` contains filter-decoded bytes.
pub(all) struct PdfMetadataStream {
  object_id : @objects.ObjectId?
  raw_stream : @objects.PdfStream
  xml : Bytes
} derive(Eq, Debug)

///|
/// Document information Trapped status. Absence is reported as `Unknown`.
pub(all) enum PdfTrappedStatus {
  True
  False
  Unknown
} derive(Eq, Debug)

///|
/// Raw-preserving document information dictionary view. Known text entries are
/// exposed as exact byte strings; dates are not parsed or normalized.
pub(all) struct PdfDocumentInfo {
  object_id : @objects.ObjectId?
  title : Bytes?
  author : Bytes?
  subject : Bytes?
  keywords : Bytes?
  creator : Bytes?
  producer : Bytes?
  creation_date : Bytes?
  mod_date : Bytes?
  trapped : PdfTrappedStatus
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Reports whether at least one descriptive document-info text field is set.
pub fn PdfDocumentInfo::has_descriptive_entries(self : PdfDocumentInfo) -> Bool {
  if self.title is Some(_) {
    true
  } else if self.author is Some(_) {
    true
  } else if self.subject is Some(_) {
    true
  } else {
    self.keywords is Some(_)
  }
}

///|
/// Read-side comparison state for document information dates and metadata
/// stream dates. XMP extraction is intentionally unsupported in this feature.
pub(all) enum PdfMetadataDateComparison {
  Equivalent
  Different
  OnlyInfo
  OnlyMetadataStream
  NotEvaluated
} derive(Eq, Debug)

///|
/// Metadata source presence and exact-byte date comparison diagnostics.
pub(all) struct PdfMetadataSourceDiagnostics {
  has_metadata_stream : Bool
  has_document_info : Bool
  creation_date : PdfMetadataDateComparison
  mod_date : PdfMetadataDateComparison
} derive(Eq, Debug)

///|
/// Reports whether either metadata source was present on the inspected object.
pub fn PdfMetadataSourceDiagnostics::has_any_source(
  self : PdfMetadataSourceDiagnostics,
) -> Bool {
  if self.has_metadata_stream {
    true
  } else {
    self.has_document_info
  }
}

///|
/// Aggregate metadata source summary for callers that want Catalog Metadata,
/// trailer Info, and non-mutating source diagnostics together.
pub(all) struct PdfDocumentMetadataSources {
  metadata_stream : PdfMetadataStream?
  document_info : PdfDocumentInfo?
  diagnostics : PdfMetadataSourceDiagnostics
} derive(Eq, Debug)

///|
/// Exact byte-comparison result for a current file identifier and a reference
/// identifier supplied by a caller.
pub(all) enum PdfFileIdMatch {
  ExactFileAndVersion
  SameOriginalDifferentVersion
  DifferentFile
  MissingCurrentIdentifier
} derive(Eq, Debug)

///|
/// One producer/data-type entry in a Page-Piece dictionary. `Private` remains
/// an opaque object owned by the producer.
pub(all) struct PdfPagePieceData {
  owner_name : @objects.PdfName
  last_modified : Bytes
  private : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Validated Page-Piece dictionary preserving source order via `entries`.
pub(all) struct PdfPagePieceDictionary {
  object_id : @objects.ObjectId?
  entries : Array[PdfPagePieceData]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Predefined deprecated procedure set names from ISO 32000-2 Table 346.
pub(all) enum PdfProcedureSetName {
  PDF
  Text
  ImageB
  ImageC
  ImageI
} derive(Eq, Debug)

///|
/// Normalized marked-content property list. Named properties preserve both the
/// name and the raw resource object for later consumers.
pub(all) enum MarkedContentProperty {
  Inline(@objects.PdfDictionary)
  Named(@objects.PdfName, @objects.PdfObject)
  Null
} derive(Eq, Debug)

///|
/// Marked-content point or sequence. Points use `begin_offset` as the operator
/// offset and `end_offset` is set to the same offset.
pub(all) struct MarkedContentScope {
  tag : @objects.PdfName
  property : MarkedContentProperty?
  begin_offset : Int64
  end_offset : Int64?
} derive(Eq, Debug)

///|
/// Structural marked-content analysis report preserving point and sequence
/// entries in the order they are encountered.
pub(all) struct MarkedContentReport {
  points : Array[MarkedContentScope]
  sequences : Array[MarkedContentScope]
} derive(Eq, Debug)

///|
/// Reports whether analysis found no marked-content points or sequences.
pub fn MarkedContentReport::is_empty(self : MarkedContentReport) -> Bool {
  if self.points.length() > 0 {
    false
  } else {
    self.sequences.length() == 0
  }
}
