///|
/// Caller-provided credentials. Password bytes are kept byte-oriented because
/// legacy PDF revisions use PDFDocEncoding-compatible inputs.
pub(all) struct EncryptionCredentials {
  password : Bytes
} derive(Eq, Debug)

///|
pub fn EncryptionCredentials::empty() -> EncryptionCredentials {
  EncryptionCredentials::{ password: b"" }
}

///|
pub fn EncryptionCredentials::password(
  password : Bytes,
) -> EncryptionCredentials {
  EncryptionCredentials::{ password, }
}

///|
/// Reader-visible encryption state for an opened file.
pub(all) enum EncryptionStatus {
  Unencrypted
  EncryptedAuthorized
  EncryptedUnsupported(String)
} derive(Eq, Debug)

///|
pub(all) enum EncryptionAccessMode {
  UserAccess
  OwnerAccess
} derive(Eq, Debug)

///|
pub(all) enum CipherVersion {
  V1
  V2
  V3
  V4
  V5
} derive(Eq, Debug)

///|
pub(all) enum CryptFilterMethod {
  Identity
  None
  V2
  AESV2
  AESV3
  Unsupported(Bytes)
} derive(Eq, Debug)

///|
pub(all) enum CryptFilterAuthEvent {
  DocOpen
  EFOpen
  Unsupported(Bytes)
} derive(Eq, Debug)

///|
pub(all) struct CryptFilter {
  name : @objects.PdfName
  filter_method : CryptFilterMethod
  auth_event : CryptFilterAuthEvent
  length_bits : Int?
} derive(Eq, Debug)

///|
pub(all) enum StreamDecryptPurpose {
  RegularStream
  XrefStream
  ObjectStream
  MetadataStream
  EmbeddedFileStream
  ExternalFileStream
} derive(Eq, Debug)

///|
pub(all) struct DocumentPermissions {
  raw_permissions : Int64
  print : Bool
  modify : Bool
  copy : Bool
  annotate : Bool
  fill_forms : Bool
  accessibility_extract : Bool
  assemble : Bool
  high_quality_print : Bool
} derive(Eq, Debug)

///|
pub(all) struct FileIdentifier {
  first : Bytes
  second : Bytes?
} derive(Eq, Debug)

///|
pub(all) struct EncryptionContext {
  status : EncryptionStatus
  file_key : Bytes
  access_mode : EncryptionAccessMode
  permissions : DocumentPermissions
  cipher_version : CipherVersion
  encrypt_metadata : Bool
  string_filter : CryptFilter
  stream_filter : CryptFilter
  embedded_file_filter : CryptFilter?
} derive(Eq, Debug)

///|
pub(all) struct EncryptedPayloadInfo {
  subtype : @objects.PdfName
  version : Bytes?
} derive(Eq, Debug)
