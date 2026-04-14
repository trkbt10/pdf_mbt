///|
/// Requirement evaluation status for ISO 32000-2 12.11.1. Requirements are
/// checked before ECMAScripts; unsupported requirements can carry a Penalty
/// value between 0 and 100.
pub(all) enum PdfRequirementSupportStatus {
  Supported
  Unsupported
  Unknown
} derive(Eq, Debug)

///|
/// Requirement handler dictionary from ISO 32000-2 12.11.1 Table 273 and
/// handler vocabulary from later 12.11 clauses. RH alternatives identify
/// handlers that should be disabled when the processor can check S itself.
pub(all) struct PdfRequirementHandler {
  handler_type : @objects.PdfName?
  version : PdfVersion?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Catalog Requirements entry model from ISO 32000-2 12.11.1 Tables 273 and
/// 274. It preserves Type Requirement, S requirement type, V minimum version,
/// RH handler dictionaries, Penalty, Encrypt and DigSig raw payloads, and
/// support status without executing ECMAScript.
pub(all) struct PdfCatalogRequirement {
  requirement_type : @objects.PdfName?
  minimum_version : PdfVersion?
  handlers : Array[PdfRequirementHandler]
  penalty : @objects.PdfName?
  support_status : PdfRequirementSupportStatus
  raw_payload : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)
