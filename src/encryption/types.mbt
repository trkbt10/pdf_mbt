///|
/// Caller-provided credentials. Password bytes are kept byte-oriented because
/// legacy PDF revisions use PDFDocEncoding-compatible inputs.
pub(all) struct EncryptionCredentials {
  password : Bytes
} derive(Eq, Debug)

///|
/// Creates empty user-password credentials for the Standard security handler.
pub fn EncryptionCredentials::empty() -> EncryptionCredentials {
  EncryptionCredentials::{ password: b"" }
}

///|
/// Wraps caller-provided password bytes without text transcoding so revision
/// 2-6 Standard security handler authentication can apply PDF password
/// preprocessing.
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
/// Reports whether document objects may be decrypted with an available key.
pub fn EncryptionStatus::is_authorized(self : EncryptionStatus) -> Bool {
  match self {
    EncryptedAuthorized => true
    Unencrypted => false
    EncryptedUnsupported(_) => false
  }
}

///|
/// Successful Standard security handler authentication mode: user password
/// access or owner password access.
pub(all) enum EncryptionAccessMode {
  UserAccess
  OwnerAccess
} derive(Eq, Debug)

///|
/// Reports whether authentication succeeded through the owner password path.
pub fn EncryptionAccessMode::is_owner_access(
  self : EncryptionAccessMode,
) -> Bool {
  match self {
    OwnerAccess => true
    UserAccess => false
  }
}

///|
/// PDF encryption algorithm version from the Encrypt dictionary V entry.
pub(all) enum CipherVersion {
  V1
  V2
  V3
  V4
  V5
} derive(Eq, Debug)

///|
/// Returns the default encryption key length in bits for this V value.
pub fn CipherVersion::default_key_bits(self : CipherVersion) -> Int {
  match self {
    V1 => 40
    V2 | V3 | V4 => 128
    V5 => 256
  }
}

///|
/// Crypt filter method used to decrypt encrypted strings, encrypted streams,
/// and embedded-file streams.
pub(all) enum CryptFilterMethod {
  Identity
  None
  V2
  AESV2
  AESV3
  Unsupported(Bytes)
} derive(Eq, Debug)

///|
/// Reports whether the crypt filter method requires a per-object key.
pub fn CryptFilterMethod::uses_object_key(self : CryptFilterMethod) -> Bool {
  match self {
    V2 | AESV2 => true
    Identity | None | AESV3 | Unsupported(_) => false
  }
}

///|
/// Crypt filter authentication event from the CF dictionary.
pub(all) enum CryptFilterAuthEvent {
  DocOpen
  EFOpen
  Unsupported(Bytes)
} derive(Eq, Debug)

///|
/// Parsed crypt filter selected by StrF, StmF, or EFF. The method determines
/// whether the per-object encryption key uses RC4, AESV2, AESV3, or Identity.
pub(all) struct CryptFilter {
  name : @objects.PdfName
  filter_method : CryptFilterMethod
  auth_event : CryptFilterAuthEvent
  length_bits : Int?
} derive(Eq, Debug)

///|
/// Stream category used when choosing the crypt filter for encrypted streams.
/// Regular streams use StmF, metadata can be left clear by EncryptMetadata,
/// and embedded file streams may use EFF.
pub(all) enum StreamDecryptPurpose {
  RegularStream
  XrefStream
  ObjectStream
  MetadataStream
  EmbeddedFileStream
  ExternalFileStream
} derive(Eq, Debug)

///|
/// Reports whether this stream purpose is governed by EncryptMetadata.
pub fn StreamDecryptPurpose::uses_metadata_policy(
  self : StreamDecryptPurpose,
) -> Bool {
  match self {
    MetadataStream => true
    _ => false
  }
}

///|
/// Parsed /P permission flags exposed after authentication so callers can
/// check printing, modification, copying, annotation, form filling,
/// accessibility extraction, assembly, and high-quality printing permissions.
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
/// Parses the raw /P permission integer into boolean permission flags.
pub fn DocumentPermissions::from_raw(
  raw_permissions : Int64,
) -> DocumentPermissions {
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
/// Returns a permissive permission set for unencrypted files or callers that
/// need an explicit unrestricted policy value.
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
/// File identifier pair from the trailer ID array. The first identifier is
/// part of Standard security handler key derivation for revisions 2-4.
pub(all) struct FileIdentifier {
  first : Bytes
  second : Bytes?
} derive(Eq, Debug)

///|
/// Authorized encryption context containing the derived file encryption key,
/// parsed permission flags, crypt filters, and metadata policy. Reader object
/// loading uses it for transparent decryption of encrypted strings and
/// encrypted streams with a per-object encryption key.
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
/// Metadata for encrypted payload dictionaries that identify an encrypted
/// attachment or external payload subtype and optional version string.
pub(all) struct EncryptedPayloadInfo {
  subtype : @objects.PdfName
  version : Bytes?
} derive(Eq, Debug)

///|
/// Reports whether this context is authorized to decrypt document objects
/// after Standard security handler authentication.
pub fn EncryptionContext::can_decrypt_objects(self : EncryptionContext) -> Bool {
  match self.status {
    EncryptedAuthorized => self.file_key.length() > 0
    Unencrypted => false
    EncryptedUnsupported(_) => false
  }
}

///|
/// Selects the crypt filter used for encrypted streams during transparent
/// decryption in object loading. MetadataStream respects EncryptMetadata,
/// EmbeddedFileStream uses EFF when present, and all other stream purposes use
/// the normal stream filter.
pub fn EncryptionContext::crypt_filter_for_stream(
  self : EncryptionContext,
  purpose : StreamDecryptPurpose,
) -> CryptFilter {
  match purpose {
    EmbeddedFileStream =>
      self.embedded_file_filter.unwrap_or(self.stream_filter)
    MetadataStream =>
      if self.encrypt_metadata {
        self.stream_filter
      } else {
        CryptFilter::identity()
      }
    _ => self.stream_filter
  }
}

///|
/// Returns the Identity crypt filter used when encrypted streams are exempt
/// from byte transformation.
pub fn CryptFilter::identity() -> CryptFilter {
  CryptFilter::{
    name: @objects.PdfName::new(b"Identity"),
    filter_method: CryptFilterMethod::Identity,
    auth_event: CryptFilterAuthEvent::DocOpen,
    length_bits: None,
  }
}

///|
/// Reports whether this crypt filter transforms payload bytes or leaves the
/// object data unchanged.
pub fn CryptFilter::decrypts_payload(self : CryptFilter) -> Bool {
  match self.filter_method {
    Identity | None => false
    V2 | AESV2 | AESV3 => true
    Unsupported(_) => true
  }
}

///|
/// True when the context uses the AES-256 file-key path from PDF 2.0.
pub fn EncryptionContext::uses_aes256_file_key(
  self : EncryptionContext,
) -> Bool {
  match self.cipher_version {
    V5 => self.file_key.length() == 32
    V1 | V2 | V3 | V4 => false
  }
}

///|
/// True when any document-changing permission bit is available to callers.
pub fn DocumentPermissions::allows_document_changes(
  self : DocumentPermissions,
) -> Bool {
  if self.modify || self.annotate {
    true
  } else if self.fill_forms || self.assemble {
    true
  } else {
    false
  }
}

///|
/// True when both trailer file identifiers are present and non-empty.
pub fn FileIdentifier::has_persistent_pair(self : FileIdentifier) -> Bool {
  if self.first.length() == 0 {
    false
  } else {
    match self.second {
      Some(value) => value.length() > 0
      None => false
    }
  }
}

///|
/// True when encrypted payload metadata names a versioned payload subtype.
pub fn EncryptedPayloadInfo::has_version_marker(
  self : EncryptedPayloadInfo,
) -> Bool {
  match self.version {
    Some(bytes) => bytes.length() > 0
    None => false
  }
}

///|
/// True when the crypt filter is selected by an embedded-file open event.
pub fn CryptFilterAuthEvent::requires_embedded_file_open(
  self : CryptFilterAuthEvent,
) -> Bool {
  match self {
    EFOpen => true
    DocOpen => false
    Unsupported(_) => false
  }
}
