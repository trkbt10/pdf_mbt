///|
let aes_object_salt : Bytes = Bytes::from_array([
  b'\x73', b'\x41', b'\x6c', b'\x54',
])

///|
/// 7.6.3.1 General: one of RC4 or AES shall be used when encrypting data in
/// a PDF file; RC4 is a symmetric stream cipher that does not change length,
/// and AES is a symmetric block cipher with 16-byte blocks and PKCS 7 padding.
pub fn pdf_file_encryption_general_rc4_aes_algorithm(
  filter_method : CryptFilterMethod,
) -> PdfEncryptionAlgorithmGeneral raise PdfEncryptionError {
  match filter_method {
    V2 => PdfEncryptionAlgorithmGeneral::RC4SymmetricStreamCipher
    AESV2 | AESV3 => PdfEncryptionAlgorithmGeneral::AESSymmetricBlockCipher
    Identity | None | Unsupported(_) =>
      raise PdfEncryptionError::UnsupportedAlgorithm(
        "7.6.3.1 General requires RC4 or AES for encrypted data",
      )
  }
}

///|
/// Decrypts encrypted strings with the string crypt filter and the per-object
/// encryption key derived from the file encryption key, object number, and
/// generation number.
pub fn decrypt_string(
  key : EncryptionKey,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
) -> Bytes raise PdfEncryptionError {
  decrypt_payload(key, key.string_filter, object_id, encrypted_bytes)
}

///|
/// Decrypts encrypted streams with the regular stream crypt filter and the
/// per-object encryption key for this object.
pub fn decrypt_stream(
  key : EncryptionKey,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
) -> Bytes raise PdfEncryptionError {
  decrypt_payload(
    key,
    key.crypt_filter_for_stream(StreamDecryptPurpose::RegularStream),
    object_id,
    encrypted_bytes,
  )
}

///|
/// Decrypts encrypted embedded file streams with EFF when present, otherwise
/// with the regular stream crypt filter and per-object encryption key.
pub fn decrypt_embedded_file_stream(
  key : EncryptionKey,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
) -> Bytes raise PdfEncryptionError {
  let filter = key.crypt_filter_for_stream(
    StreamDecryptPurpose::EmbeddedFileStream,
  )
  decrypt_payload(key, filter, object_id, encrypted_bytes)
}

///|
fn decrypt_payload(
  key : EncryptionKey,
  filter : CryptFilter,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
) -> Bytes raise PdfEncryptionError {
  match filter.filter_method {
    Identity | None => encrypted_bytes
    V2 => decrypt_rc4_payload(key, object_id, encrypted_bytes)
    AESV2 =>
      decrypt_aes_payload(
        derive_object_key(key.file_key, object_id, use_aes_salt=true),
        encrypted_bytes,
        "AESV2",
      )
    AESV3 => decrypt_aes_payload(key.file_key, encrypted_bytes, "AESV3")
    Unsupported(name) =>
      raise PdfEncryptionError::UnsupportedAlgorithm(
        "unsupported crypt filter method " + @utf8.decode_lossy(name),
      )
  }
}

///|
fn decrypt_rc4_payload(
  key : EncryptionKey,
  object_id : @objects.ObjectId,
  encrypted_bytes : Bytes,
) -> Bytes raise PdfEncryptionError {
  let object_key = derive_object_key(
    key.file_key,
    object_id,
    use_aes_salt=false,
  )
  crypto_rc4(object_key, encrypted_bytes)
}

///|
fn decrypt_aes_payload(
  object_key : Bytes,
  encrypted_bytes : Bytes,
  label : String,
) -> Bytes raise PdfEncryptionError {
  if encrypted_bytes.length() < 16 {
    raise PdfEncryptionError::MalformedEncryptionDictionary(
      label, "AES encrypted payload must include a 16-byte IV",
    )
  }
  let iv = bytes_slice(encrypted_bytes, 0, 16)
  let ciphertext = bytes_slice(encrypted_bytes, 16, encrypted_bytes.length())
  crypto_aes_cbc_decrypt(object_key, iv, ciphertext, @crypto.PaddingMode::PKCS7)
}

///|
fn derive_object_key(
  file_key : Bytes,
  object_id : @objects.ObjectId,
  use_aes_salt~ : Bool,
) -> Bytes raise PdfEncryptionError {
  let mut input = file_key +
    object_number_low_bytes(object_id.object_number) +
    generation_low_bytes(object_id.generation_number)
  if use_aes_salt {
    input = input + aes_object_salt
  }
  let digest = crypto_md5(input)
  let key_length = if file_key.length() + 5 > 16 {
    16
  } else {
    file_key.length() + 5
  }
  bytes_slice(digest, 0, key_length)
}

///|
fn object_number_low_bytes(value : Int) -> Bytes {
  let int_value = value.to_int64()
  Bytes::from_array([
    (int_value & 0xffL).to_byte(),
    ((int_value >> 8) & 0xffL).to_byte(),
    ((int_value >> 16) & 0xffL).to_byte(),
  ])
}

///|
fn generation_low_bytes(value : Int) -> Bytes {
  let int_value = value.to_int64()
  Bytes::from_array([
    (int_value & 0xffL).to_byte(),
    ((int_value >> 8) & 0xffL).to_byte(),
  ])
}
