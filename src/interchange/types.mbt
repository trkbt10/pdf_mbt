///|
/// Valid metadata stream wrapper. `raw_stream` preserves the stream object
/// exactly as supplied by the owner, while `xml` contains filter-decoded bytes.
pub(all) struct PdfMetadataStream {
  object_id : @objects.ObjectId?
  raw_stream : @objects.PdfStream
  xml : Bytes
} derive(Eq, Debug)

///|
/// 14.3.3 Document information dictionary /Trapped status. `True`, `False`,
/// and `Unknown` are name objects for whether trapping information is present;
/// absence defaults to `Unknown` and pdf:Trapped can also appear in metadata.
pub(all) enum PdfTrappedStatus {
  True
  False
  Unknown
} derive(Eq, Debug)

///|
/// 14.3 Document information dictionary view for trailer Info metadata.
/// Deprecated descriptive text entries are preserved as text strings, while
/// CreationDate, ModDate, and Trapped remain available for metadata streams and
/// page-piece dictionary reconciliation.
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
/// Reports whether 14.3.3 deprecated descriptive document information
/// dictionary text entries such as Title, Author, Subject, or Keywords are set.
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
/// 14.3.2 Metadata streams diagnostics for the available document metadata
/// sources: document-level metadata stream presence, document information
/// dictionary presence, and CreationDate / ModDate equivalence state.
pub(all) struct PdfMetadataSourceDiagnostics {
  has_metadata_stream : Bool
  has_document_info : Bool
  creation_date : PdfMetadataDateComparison
  mod_date : PdfMetadataDateComparison
} derive(Eq, Debug)

///|
/// Reports whether any 14.3.1 document metadata source is present. Metadata
/// can be stored for document data in a 14.3.2 metadata stream associated with
/// the document, or for document metadata only in a 14.3.3 document
/// information dictionary associated with the document.
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
/// 14.4 File identifiers comparison result for a trailer ID array. Matching
/// both the first permanent original ID byte string and second changing
/// current ID byte string means the same file and version; matching only the
/// original ID means a different version of the correct PDF file.
pub(all) enum PdfFileIdMatch {
  ExactFileAndVersion
  SameOriginalDifferentVersion
  DifferentFile
  MissingCurrentIdentifier
} derive(Eq, Debug)

///|
/// 14.5 Page-piece dictionary data dictionary for one PDF processor or
/// well-known data type. LastModified is the required modification date for
/// document, page, or form content; Private remains opaque processor data.
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
/// 14.6.2 Property lists for marked content. DP and BDC operators may use an
/// inline direct dictionary, or a name object that resolves through the
/// Properties subdictionary of the current resource dictionary.
pub(all) enum MarkedContentProperty {
  Inline(@objects.PdfDictionary)
  Named(@objects.PdfName, @objects.PdfObject)
  Null
} derive(Eq, Debug)

///|
/// 14.6 Marked content point or sequence. MP and DP designate a single
/// marked-content point; BMC and BDC begin a marked-content sequence that is
/// terminated by a balancing EMC operator in the same content stream.
pub(all) struct MarkedContentScope {
  tag : @objects.PdfName
  property : MarkedContentProperty?
  begin_offset : Int64
  end_offset : Int64?
} derive(Eq, Debug)

///|
/// 14.6 Marked content analysis report for content stream operators. It keeps
/// MP and DP marked-content points plus BMC, BDC, and EMC marked-content
/// sequences, including tag operands and property lists, in content stream
/// order.
pub(all) struct MarkedContentReport {
  points : Array[MarkedContentScope]
  sequences : Array[MarkedContentScope]
} derive(Eq, Debug)

///|
/// Reports whether the 14.6 marked content state is empty. Marked-content
/// operators may identify a portion of a PDF content stream; empty means no MP
/// or DP single marked-content point and no BMC, BDC, or EMC bracketed
/// marked-content sequence was encountered.
pub fn MarkedContentReport::is_empty(self : MarkedContentReport) -> Bool {
  if self.points.length() > 0 {
    false
  } else {
    self.sequences.length() == 0
  }
}
