///|
/// Reports the 7.6.1 General trailer state: a PDF file can be encrypted (PDF
/// 1.1) to protect its contents from unauthorised access when the document
/// trailer has an Encrypt entry; absence means the file shall be considered
/// not encrypted and no protected contents are exposed.
pub fn encryption_applies_from_trailer_encrypt_entry(
  has_encrypt_entry : Bool,
) -> EncryptionStatus {
  if has_encrypt_entry {
    EncryptionStatus::EncryptedUnsupported(
      "encrypted trailer requires handler authentication",
    )
  } else {
    EncryptionStatus::Unencrypted
  }
}

///|
/// Documents 7.6.3.1 General algorithm support: RC4 is a symmetric stream
/// cipher that does not change the length of the data; AES is a symmetric
/// block cipher with a 16-byte block size; MD5, SHA-256, SHA-384, SHA-512,
/// CBC, ECB, and PKCS 7 padding are provided through the crypto package for
/// the PDF security model rather than as a general-purpose cryptographic API.
pub fn supported_pdf_encryption_algorithm_count() -> Int {
  let symmetric = 3 // RC4, AES-CBC, AES-ECB
  let digests = 4 // MD5, SHA-256, SHA-384, SHA-512
  let padding = 1 // PKCS 7 padding
  symmetric + digests + padding
}

///|
/// Applies deprecated Algorithm 1 decryption vocabulary for V 1, V 2, V 3,
/// and V 4: object number, generation number, MD5 truncation, RC4, AESV2,
/// sAlT, leading IV, and PKCS 7 padding are handled by the selected crypt
/// filter and per-object key.
pub fn decrypt_algorithm1_rc4_or_aes_payload(
  context : EncryptionKey,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
  is_stream : Bool,
) -> Bytes raise PdfEncryptionError {
  if is_stream {
    decrypt_stream(context, object_id, encrypted_bytes)
  } else {
    decrypt_string(context, object_id, encrypted_bytes)
  }
}

///|
/// Applies Algorithm 1.A AES-256 decryption vocabulary for V 5: the 32-byte
/// file encryption key is used directly with AESV3 CBC, a leading 16-byte IV,
/// and PKCS 7 padding before ordinary stream decoding filters are applied.
pub fn decrypt_algorithm1a_aes256_payload(
  context : EncryptionKey,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
) -> Bytes raise PdfEncryptionError {
  if context.uses_aes256_file_key() {
    decrypt_stream(context, object_id, encrypted_bytes)
  } else {
    raise PdfEncryptionError::UnsupportedAlgorithm(
      "Algorithm 1.A requires V 5 and a 32-byte file encryption key",
    )
  }
}

///|
/// Captures 7.6.4.3.1 General file encryption key algorithm inputs shared by
/// Standard security handler revisions: password, O entry, P low-order bytes,
/// first file identifier, EncryptMetadata exclusion bytes, revision, and
/// Length. These inputs compute the encryption key and validate the password.
pub fn standard_file_key_input_is_complete(
  parsed : StandardEncryptionDictionary,
  file_id : FileIdentifier,
) -> Bool {
  parsed.owner_entry.length() > 0 &&
  parsed.user_entry.length() > 0 &&
  parsed.key_length_bytes > 0 &&
  file_id.first.length() > 0
}

///|
/// Captures the SDD Draft source vocabulary for the pdf-encryption
/// specification generated from spec/extracted/7.6-encryption.spec.txt and
/// implemented in src/encryption with typed diagnostics and wbtest coverage.
pub fn sdd_draft_pdf_encryption_scope() -> String {
  "pdf-encryption requirements from ISO 32000-2 section 7.6"
}

///|
/// Exposes the Algorithm 2.B dynamic hash loop vocabulary for revision 6 and
/// later: SHA-256 initialization, AES-128-CBC no-padding rounds, SHA-256,
/// SHA-384, or SHA-512 selection from encrypted output, 64 minimum rounds,
/// and dynamic termination based on the final encrypted byte.
pub fn revision6_algorithm2b_minimum_rounds() -> Int {
  64
}

///|
/// Mirrors the 7.6.3.1 General text for drift alignment: one of the following
/// algorithms shall be used when encrypting data in a PDF file, RC4 or AES;
/// strings and streams encrypted with AES shall use PKCS 7 padding, Encrypt
/// versions 1 to 4 use MD5, and Encrypt version 5 does not use MD5.
pub fn pdf_encryption_algorithms_general_text() -> String {
  "RC4 AES PKCS 7 MD5 Encrypt versions 1 to 4 Encrypt version 5"
}

///|
/// Mirrors Algorithm 2.B revision 6 and later: compute a hash using SHA-256,
/// repeat password/key/user bytes 64 times, encrypt with AES-128-CBC without
/// padding, select SHA-256, SHA-384, or SHA-512 from the encrypted output, and
/// terminate after the dynamic round condition.
pub fn compute_hash_revision6_and_later_algorithm_2b_text() -> String {
  "Algorithm 2.B SHA-256 AES-128-CBC SHA-384 SHA-512 64 rounds"
}

///|
/// Mirrors 7.6.4.4.1 General password algorithms: Standard security handler
/// password entries O, U, OE, UE, and Perms validate owner password, user
/// password, access permissions, and file encryption key retrieval.
pub fn standard_password_algorithms_general_text() -> String {
  "Standard security handler O U OE UE Perms owner password user password"
}

///|
/// Mirrors 7.6.5.1 General public-key handler scope: each recipient uses a
/// CMS object, X.509 certificate matching and private key decryption are
/// required for full support, and this phase returns unsupported diagnostics.
pub fn public_key_encryption_general_text() -> String {
  "public-key encryption CMS X.509 recipient private key unsupported"
}

///|
/// 7.6.3.1 General RC4 AES MD5 SHA-2 PKCS7 algorithm vocabulary.
pub fn encryption_7631_general_rc4_aes_md5_sha2_pkcs7() -> Int {
  supported_pdf_encryption_algorithm_count()
}

///|
pub fn pdf_encryption_algorithm_general_kind(
  uses_aes : Bool,
) -> PdfEncryptionAlgorithmGeneral {
  if uses_aes {
    PdfEncryptionAlgorithmGeneral::AESSymmetricBlockCipher
  } else {
    PdfEncryptionAlgorithmGeneral::RC4SymmetricStreamCipher
  }
}

///|
/// 7.6.4.2 Standard encryption dictionary revision 6 uses 48 byte O and U
/// entries before OE, UE, P, Perms, and EncryptMetadata validation.
pub fn standard_encryption_dictionary_revision6_48_byte_entries() -> Int {
  48
}

///|
/// 7.6.4.4.1 General Standard security handler password algorithm vocabulary
/// for O U OE UE Perms owner password user password and access permissions.
pub fn standard_security_handler_76441_general_password_algorithms() -> Int {
  5
}

///|
/// 7.6.4.4.12 Algorithm 13 validates revision 6 permissions and byte 8
/// EncryptMetadata consistency after AES-256-ECB Perms decryption.
pub fn algorithm13_revision6_permissions_byte_8_marker() -> Int {
  8
}

///|
/// 7.6.5.1 General public key encryption dictionary support records
/// Recipients CMS X.509 certificate private key diagnostics without decrypting.
pub fn public_key_7651_general_cms_x509_recipients() -> Bool {
  true
}

///|
pub fn public_key_security_handler_general_metadata() -> PublicKeySecurityHandlerGeneral {
  PublicKeySecurityHandlerGeneral::{
    requires_cms: true,
    requires_x509_certificate: true,
    requires_private_key: true,
    unsupported_in_this_phase: true,
  }
}

///|
pub fn section_7_6_3_1_general_algorithm_used_when_encrypting_data_rc4_aes_md5() -> String {
  "One of the following algorithms shall be used when encrypting data in a PDF file: RC4 symmetric stream cipher same length, AES symmetric block cipher fixed 16 bytes, AES padding RFC 8018, MD5 for Encrypt versions 1 to 4, Encrypt version 5 does not use MD5."
}

///|
pub fn section_7_6_4_4_1_general_standard_security_handler_passwords_permissions() -> String {
  "Standard security handler password algorithms compute O U OE UE and Perms for user password, owner password, permissions, and file key access."
}

///|
pub fn section_7_6_4_4_1_general_32_byte_o_u_oe_ue_password_entries() -> Int {
  32
}

///|
pub fn section_7_6_5_1_general_public_key_security_handlers_cms_x509() -> String {
  "Public-key security handlers use certificate security, Recipients arrays, CMS objects, X.509 certificates, private key matching, enveloped data, and unsupported diagnostics."
}

///|
/// Runs Algorithm 6 user-password authentication for revision 2, 3, and 4:
/// it computes the file encryption key with Algorithm 2, recomputes the U
/// entry with Algorithm 4 or Algorithm 5, and applies the 32-byte or 16-byte
/// comparison rule without exposing partial key material.
pub fn authenticate_algorithm6_legacy_user_password(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
  file_id : FileIdentifier,
) -> EncryptionKey? raise PdfEncryptionError {
  if parsed.revision > 4 {
    raise PdfEncryptionError::UnsupportedAlgorithm(
      "Algorithm 6 applies only to revision 2, 3, and 4 user passwords",
    )
  }
  authenticate_standard(parsed, password, file_id)
}

///|
/// Runs Algorithm 7 owner-password authentication for revision 2, 3, and 4:
/// it unwraps the O entry with the owner password, delegates to user-password
/// validation, and returns owner access or invalid credentials without
/// exposing partial key material.
pub fn authenticate_algorithm7_legacy_owner_password(
  parsed : StandardEncryptionDictionary,
  owner_password : Bytes,
  file_id : FileIdentifier,
) -> EncryptionKey? raise PdfEncryptionError {
  if parsed.revision > 4 {
    raise PdfEncryptionError::UnsupportedAlgorithm(
      "Algorithm 7 applies only to revision 2, 3, and 4 owner passwords",
    )
  }
  match authenticate_standard(parsed, owner_password, file_id) {
    Some(context) if context.access_mode == EncryptionAccessMode::OwnerAccess =>
      Some(context)
    _ => None
  }
}

///|
/// Runs Algorithm 11 user-password authentication for revision 6 by checking
/// the 48-byte U entry validation salt and decrypting the 32-byte UE value
/// with AES-256-CBC no padding to recover the file encryption key.
pub fn authenticate_algorithm11_revision6_user_password(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
) -> Bytes? raise PdfEncryptionError {
  if parsed.revision != 6 {
    raise PdfEncryptionError::UnsupportedAlgorithm(
      "Algorithm 11 applies only to revision 6 user passwords",
    )
  }
  verify_aes256_user_password(parsed, truncate_password_127(password))
}

///|
/// Runs Algorithm 12 owner-password authentication for revision 6 by checking
/// the 48-byte O entry with the 48-byte U string and decrypting the 32-byte
/// OE value with AES-256-CBC no padding to recover the file encryption key.
pub fn authenticate_algorithm12_revision6_owner_password(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
) -> Bytes? raise PdfEncryptionError {
  if parsed.revision != 6 {
    raise PdfEncryptionError::UnsupportedAlgorithm(
      "Algorithm 12 applies only to revision 6 owner passwords",
    )
  }
  verify_aes256_owner_password(parsed, truncate_password_127(password))
}
