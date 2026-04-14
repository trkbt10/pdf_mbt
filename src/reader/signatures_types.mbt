///|
/// ByteRange pair from ISO 32000-2 12.8.1 Table 255. Each pair contributes a
/// starting byte offset and length for a byte range digest that excludes the
/// Contents signature value.
pub(all) struct PdfSignatureByteRange {
  offset : Int64
  length : Int64
} derive(Eq, Debug)

///|
/// Signature SubFilter names from 12.8.3.1 through 12.8.3.4. PKCS #1
/// adbe.x509.rsa_sha1, CMS/PKCS #7 adbe.pkcs7.detached and
/// adbe.pkcs7.sha1, PAdES ETSI.CAdES.detached, and document timestamp
/// ETSI.RFC3161 values are modeled without cryptographic validation.
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
/// Signature reference dictionary from Table 256 and transform method clauses
/// 12.8.2.1 through 12.8.2.4. TransformMethod values such as DocMDP, UR, and
/// FieldMDP, DigestMethod names, and TransformParams dictionaries are kept as
/// modification detection and prevention metadata.
pub(all) struct PdfSignatureReference {
  transform_method : @objects.PdfName?
  digest_method : @objects.PdfName?
  transform_params : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Signature dictionary from ISO 32000-2 12.8.1 Table 255. It covers Sig and
/// DocTimeStamp dictionaries, Filter signature handler names, SubFilter
/// interoperability, Contents bytes, Cert chains, ByteRange digest data,
/// Reference transform constraints, Changes ordering, Name, M signing time,
/// Location, Reason, ContactInfo, PAdES ETSI.CAdES.detached restrictions, and
/// Internet RFC 3161 timestamp tokens as updated by Internet RFC 5816.
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
/// Signature field model from ISO 32000-2 12.7.5.5 Table 235. It ties a Sig
/// form field to an optional signature dictionary V entry, Lock signature
/// field lock dictionary from Table 236, and SV seed value dictionary from
/// Table 237 while preserving signing constraints as structural data only.
pub(all) struct PdfSignatureField {
  field : PdfFormField
  signature : PdfSignatureDictionary?
  lock : @objects.PdfObject?
  seed_value : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Reader model for the document security store (DSS) from 12.8.4.1 through
/// 12.8.4.3 and Table 261. It preserves VRI, Certs, OCSPs, and CRLs entries
/// used for long term validation (LTV) without validating certificates,
/// revocation lists, OCSP responses, CMS objects, CAdES, or PAdES signatures.
pub(all) struct PdfDocumentSecurityStore {
  validation_related_information : @objects.PdfObject?
  certificates : Array[@objects.PdfObject]
  ocsps : Array[@objects.PdfObject]
  crls : Array[@objects.PdfObject]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Validation-related information (VRI) dictionary from 12.8.4.4 Table 262
/// and 12.8.4.5 DSS VRI usage. Cert, CRL, OCSP, TU, and TS references are
/// kept so callers can prefer VRI validation data, then DSS validation data,
/// then validation data embedded in the signature.
pub(all) struct PdfValidationRelatedInformation {
  certificates : Array[@objects.PdfObject]
  crls : Array[@objects.PdfObject]
  ocsps : Array[@objects.PdfObject]
  time_update : @objects.PdfObject?
  timestamp : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Permissions dictionary from 12.8.6 Table 263 and catalog Table 29. DocMDP
/// and deprecated UR3 signature dictionaries are retained as indirect
/// permission handler entries; this reader does not grant permissions or
/// enforce security-handler policy.
pub(all) struct PdfPermissionsDictionary {
  doc_mdp : @objects.PdfObject?
  ur3 : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Legal attestation dictionary from 12.8.7 Table 264 and catalog Table 29.
/// It records counts for JavaScriptActions, LaunchActions, URIActions,
/// MovieActions, SoundActions, HideAnnotationActions, GoToRemoteActions,
/// annotations, OptionalContent, Attestation text, and raw unexpected
/// rendering indicators without deciding legal trust.
pub(all) struct PdfLegalAttestation {
  javascript_actions : Int?
  launch_actions : Int?
  uri_actions : Int?
  movie_actions : Int?
  sound_actions : Int?
  hide_annotation_actions : Int?
  go_to_remote_actions : Int?
  annotations : Int?
  optional_content : Bool?
  attestation : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Signature validation plan for 12.8.2 DocMDP and FieldMDP comparisons,
/// 12.8.3 PKCS #1, CMS/PKCS #7, CAdES, and PAdES interoperability, revocation
/// checking at current UTC time or a time in the past, and 12.8.5 document
/// timestamp (DTS) dictionaries. It is evidence routing only and never
/// performs cryptographic signature validation.
pub(all) struct PdfSignatureValidationPlan {
  signature : PdfSignatureDictionary
  byte_ranges : Array[PdfSignatureByteRange]
  raw_contents : Bytes?
  transform_constraints : Array[PdfSignatureReference]
  evidence_sources : Array[@objects.PdfObject]
} derive(Eq, Debug)
