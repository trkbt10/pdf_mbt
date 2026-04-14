///|
pub(all) enum PdfRequirementSupportStatus {
  Supported
  Unsupported
  Unknown
} derive(Eq, Debug)

///|
pub(all) struct PdfRequirementHandler {
  handler_type : @objects.PdfName?
  version : PdfVersion?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfCatalogRequirement {
  requirement_type : @objects.PdfName?
  minimum_version : PdfVersion?
  handlers : Array[PdfRequirementHandler]
  penalty : @objects.PdfName?
  support_status : PdfRequirementSupportStatus
  raw_payload : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)
