///|
let perms_marker_tail : Bytes = Bytes::from_array([b'a', b'd', b'b'])

///|
fn perms_metadata_byte(encrypt_metadata : Bool) -> Byte {
  if encrypt_metadata {
    b'T'
  } else {
    b'F'
  }
}

///|
fn perms_little_endian(value : Int64) -> Bytes {
  Bytes::from_array([
    (value & 0xffL).to_byte(),
    ((value >> 8) & 0xffL).to_byte(),
    ((value >> 16) & 0xffL).to_byte(),
    ((value >> 24) & 0xffL).to_byte(),
  ])
}

///|
fn bytes_range(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::from_array(data.view(start~, end~).to_array().view())
}

///|
fn perms_plaintext(
  permissions : DocumentPermissions,
  encrypt_metadata : Bool,
) -> Bytes {
  perms_little_endian(permissions.raw_permissions) +
  Bytes::from_array([
    b'\xff',
    b'\xff',
    b'\xff',
    b'\xff',
    perms_metadata_byte(encrypt_metadata),
    b'a',
    b'd',
    b'b',
    b'\x00',
    b'\x00',
    b'\x00',
    b'\x00',
  ])
}

///|
/// Computes revision 6 Algorithm 10 Perms permission data by encoding the
/// little-endian P value, EncryptMetadata marker, and "adb" marker before
/// AES-256-ECB encryption with the file encryption key.
pub fn compute_revision6_perms(
  file_key : Bytes,
  permissions : DocumentPermissions,
  encrypt_metadata : Bool,
) -> Bytes raise PdfEncryptionError {
  try
    @crypto.aes_encrypt_block(
      file_key,
      perms_plaintext(permissions, encrypt_metadata),
    )
  catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    encrypted => encrypted
  }
}

///|
/// Validates revision 6 Algorithm 13 Perms permission data, including the byte
/// 8 EncryptMetadata marker position, adb marker bytes, little-endian
/// permissions, and EncryptMetadata consistency before an authorized Standard
/// security handler context is returned.
pub fn validate_revision6_perms(
  file_key : Bytes,
  encrypted_perms : Bytes,
  permissions : DocumentPermissions,
  encrypt_metadata : Bool,
) -> Unit raise PdfEncryptionError {
  if encrypted_perms.length() != 16 {
    raise PdfEncryptionError::PermissionValidationFailure(
      "Perms entry must contain 16 bytes",
    )
  }
  let plain = try @crypto.aes_decrypt_block(file_key, encrypted_perms) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    decrypted => decrypted
  }
  if bytes_range(plain, 0, 4) !=
    perms_little_endian(permissions.raw_permissions) {
    raise PdfEncryptionError::PermissionValidationFailure(
      "Perms little-endian permissions do not match P",
    )
  }
  if bytes_range(plain, 9, 12) != perms_marker_tail {
    raise PdfEncryptionError::PermissionValidationFailure(
      "Perms marker bytes must be Tadb or Fadb",
    )
  }
  let encrypt_metadata_marker_index = 8
  if plain[encrypt_metadata_marker_index] !=
    perms_metadata_byte(encrypt_metadata) {
    raise PdfEncryptionError::PermissionValidationFailure(
      "Perms EncryptMetadata marker does not match dictionary",
    )
  }
}
