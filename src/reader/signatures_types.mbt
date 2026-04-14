///|
pub(all) struct PdfSignatureByteRange {
  offset : Int64
  length : Int64
} derive(Eq, Debug)

///|
pub(all) enum PdfSignatureSubFilter {
  AdbeX509RsaSha1
  AdbePkcs7Detached
  AdbePkcs7Sha1
  EtsiCAdESDetached
  EtsiRFC3161
  Unknown(@objects.PdfName)
  Absent
} derive(Eq, Debug)

///|
pub(all) struct PdfSignatureReference {
  transform_method : @objects.PdfName?
  digest_method : @objects.PdfName?
  transform_params : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfSignatureDictionary {
  object_id : @objects.ObjectId?
  filter : @objects.PdfName?
  subfilter : PdfSignatureSubFilter
  contents : Bytes?
  cert : @objects.PdfObject?
  byte_range : Array[PdfSignatureByteRange]
  references : Array[PdfSignatureReference]
  signer_name : Bytes?
  signing_time : @objects.PdfObject?
  location : Bytes?
  reason : Bytes?
  contact_info : Bytes?
  changes : Array[Int]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfSignatureField {
  field : PdfFormField
  signature : PdfSignatureDictionary?
  lock : @objects.PdfObject?
  seed_value : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfSignatureValidationPlan {
  signature : PdfSignatureDictionary
  byte_ranges : Array[PdfSignatureByteRange]
  raw_contents : Bytes?
  transform_constraints : Array[PdfSignatureReference]
  evidence_sources : Array[@objects.PdfObject]
} derive(Eq, Debug)
