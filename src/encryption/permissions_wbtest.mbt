///|
test "revision 6 permissions compute and validate Perms data" {
  let file_key = b"0123456789abcdef0123456789abcdef"
  let permissions = DocumentPermissions::from_raw(-4L)
  let encrypted = compute_revision6_perms(file_key, permissions, true)
  assert_eq(encrypted.length(), 16)
  validate_revision6_perms(file_key, encrypted, permissions, true)

  let result : Result[Unit, PdfEncryptionError] = try? validate_revision6_perms(
    file_key, encrypted, permissions, false,
  )
  match result {
    Err(PermissionValidationFailure(reason)) =>
      assert_eq(reason.contains("EncryptMetadata"), true)
    _ => fail("expected metadata mismatch")
  }
}

///|
test "revision 6 user and owner entries recover file key" {
  let file_key = b"abcdefghijklmnopabcdefghijklmnop"
  let (user_entry, user_encrypted_key) = compute_aes256_user_entries(
    6, b"user", b"12345678", b"abcdefgh", file_key,
  )
  let (owner_entry, owner_encrypted_key) = compute_aes256_owner_entries(
    6, b"owner", b"87654321", b"hgfedcba", user_entry, file_key,
  )
  let parsed = StandardEncryptionDictionary::{
    revision: 6,
    cipher_version: CipherVersion::V5,
    key_length_bytes: 32,
    owner_entry,
    user_entry,
    owner_encrypted_file_key: Some(owner_encrypted_key),
    user_encrypted_file_key: Some(user_encrypted_key),
    permissions: DocumentPermissions::from_raw(-4L),
    encrypt_metadata: true,
    string_filter: CryptFilter::{
      name: @objects.PdfName::new(b"StdCF"),
      filter_method: CryptFilterMethod::AESV3,
      auth_event: CryptFilterAuthEvent::DocOpen,
      length_bits: Some(256),
    },
    stream_filter: CryptFilter::{
      name: @objects.PdfName::new(b"StdCF"),
      filter_method: CryptFilterMethod::AESV3,
      auth_event: CryptFilterAuthEvent::DocOpen,
      length_bits: Some(256),
    },
    embedded_file_filter: None,
  }

  assert_eq(verify_aes256_user_password(parsed, b"user").unwrap(), file_key)
  assert_eq(verify_aes256_owner_password(parsed, b"owner").unwrap(), file_key)
  assert_eq(verify_aes256_user_password(parsed, b"bad") is None, true)
}
