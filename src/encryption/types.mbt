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
/// Standard security-handler file key plus reader-visible policy derived from
/// the Encrypt dictionary. Kept as an alias so callers can use the requested
/// encryption-key vocabulary without duplicating EncryptionContext state.
pub type EncryptionKey = EncryptionContext

///|
pub fn DocumentPermissions::from_raw(raw_permissions : Int64) -> DocumentPermissions {
  DocumentPermissions::{
    raw_permissions,
    print: (raw_permissions & 0x04L) != 0L,
    modify: (raw_permissions & 0x08L) != 0L,
    copy: (raw_permissions & 0x10L) != 0L,
    annotate: (raw_permissions & 0x20L) != 0L,
    fill_forms: (raw_permissions & 0x100L) != 0L,
    accessibility_extract: (raw_permissions & 0x200L) != 0L,
    assemble: (raw_permissions & 0x400L) != 0L,
    high_quality_print: (raw_permissions & 0x800L) != 0L,
  }
}

///|
pub fn DocumentPermissions::unrestricted() -> DocumentPermissions {
  DocumentPermissions::{
    raw_permissions: -1L,
    print: true,
    modify: true,
    copy: true,
    annotate: true,
    fill_forms: true,
    accessibility_extract: true,
    assemble: true,
    high_quality_print: true,
  }
}

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
