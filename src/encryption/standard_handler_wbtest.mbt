///|
fn test_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn test_filter(
  crypt_method : CryptFilterMethod,
  length_bits : Int,
) -> CryptFilter {
  CryptFilter::{
    name: test_name(b"StdCF"),
    filter_method: crypt_method,
    auth_event: CryptFilterAuthEvent::DocOpen,
    length_bits: Some(length_bits),
  }
}

///|
fn legacy_test_parsed(
  revision : Int,
  key_length_bytes : Int,
  owner_entry : Bytes,
  user_entry : Bytes,
) -> StandardEncryptionDictionary {
  let crypt_filter = test_filter(CryptFilterMethod::V2, key_length_bytes * 8)
  StandardEncryptionDictionary::{
    revision,
    cipher_version: if revision == 2 {
      CipherVersion::V1
    } else {
      CipherVersion::V2
    },
    key_length_bytes,
    owner_entry,
    user_entry,
    owner_encrypted_file_key: None,
    user_encrypted_file_key: None,
    permissions: DocumentPermissions::from_raw(-4L),
    encrypt_metadata: true,
    string_filter: crypt_filter,
    stream_filter: crypt_filter,
    embedded_file_filter: None,
  }
}

///|
fn build_legacy_test_dict(
  revision : Int,
  key_length_bytes : Int,
  user_password : Bytes,
  owner_password : Bytes,
  file_id : FileIdentifier,
) -> @objects.PdfDictionary raise PdfEncryptionError {
  let owner_entry = compute_legacy_owner_entry(
    revision, key_length_bytes, user_password, owner_password,
  )
  let parsed_without_u = legacy_test_parsed(
    revision, key_length_bytes, owner_entry, b"",
  )
  let file_key = derive_legacy_file_key(
    parsed_without_u, user_password, file_id,
  )
  let user_entry = compute_legacy_user_entry(
    parsed_without_u, file_key, file_id,
  )
  let dict : @objects.PdfDictionary = Map::new()
  dict[test_name(b"Filter")] = @objects.PdfObject::Name(test_name(b"Standard"))
  dict[test_name(b"V")] = @objects.PdfObject::Integer(
    if revision == 2 {
      1L
    } else {
      2L
    },
  )
  dict[test_name(b"R")] = @objects.PdfObject::Integer(revision.to_int64())
  dict[test_name(b"Length")] = @objects.PdfObject::Integer(
    (key_length_bytes * 8).to_int64(),
  )
  dict[test_name(b"O")] = @objects.PdfObject::String(owner_entry)
  dict[test_name(b"U")] = @objects.PdfObject::String(user_entry)
  dict[test_name(b"P")] = @objects.PdfObject::Integer(-4L)
  dict
}

///|
test "Standard handler authenticates revision 2 user and owner passwords" {
  let file_id = FileIdentifier::{ first: b"doc-id", second: None }
  let dict = build_legacy_test_dict(2, 5, b"user", b"owner", file_id)

  let user_key = authenticate(dict, b"user", file_id)
  match user_key {
    Some(key) => {
      assert_eq(key.access_mode == EncryptionAccessMode::UserAccess, true)
      assert_eq(key.file_key.length(), 5)
    }
    None => fail("expected user password authentication")
  }

  let owner_key = authenticate(dict, b"owner", file_id)
  match owner_key {
    Some(key) =>
      assert_eq(key.access_mode == EncryptionAccessMode::OwnerAccess, true)
    None => fail("expected owner password authentication")
  }

  assert_eq(authenticate(dict, b"bad", file_id) is None, true)
}

///|
test "Standard handler authenticates revision 3 user passwords" {
  let file_id = FileIdentifier::{ first: b"revision-three-id", second: None }
  let dict = build_legacy_test_dict(3, 16, b"", b"owner", file_id)

  let user_key = authenticate(dict, b"", file_id)
  match user_key {
    Some(key) => {
      assert_eq(key.file_key.length(), 16)
      assert_eq(key.permissions.copy, true)
    }
    None => fail("expected empty user password authentication")
  }
}

///|
test "decryptor derives per-object RC4 keys" {
  let file_id = FileIdentifier::{ first: b"doc-id", second: None }
  let dict = build_legacy_test_dict(2, 5, b"user", b"owner", file_id)
  let key = authenticate(dict, b"user", file_id).unwrap()
  let object_id = @objects.ObjectId::{ object_number: 12, generation_number: 3 }

  let encrypted = decrypt_string(key, object_id, b"Plain bytes")
  assert_eq(decrypt_string(key, object_id, encrypted), b"Plain bytes")
}

///|
test "decryptor handles AESV2 and AESV3 CBC payloads" {
  let object_id = @objects.ObjectId::{ object_number: 7, generation_number: 0 }
  let aesv2_context = EncryptionContext::{
    status: EncryptionStatus::EncryptedAuthorized,
    file_key: b"0123456789abcdef",
    access_mode: EncryptionAccessMode::UserAccess,
    permissions: DocumentPermissions::unrestricted(),
    cipher_version: CipherVersion::V4,
    encrypt_metadata: true,
    string_filter: test_filter(CryptFilterMethod::AESV2, 128),
    stream_filter: test_filter(CryptFilterMethod::AESV2, 128),
    embedded_file_filter: None,
  }
  let iv = b"abcdefghijklmnop"
  let aesv2_key = derive_object_key(
    aesv2_context.file_key,
    object_id,
    use_aes_salt=true,
  )
  let aesv2_encrypted = iv +
    crypto_aes_cbc_encrypt(
      aesv2_key,
      iv,
      b"aes two",
      @crypto.PaddingMode::PKCS7,
    )
  assert_eq(
    decrypt_string(aesv2_context, object_id, aesv2_encrypted),
    b"aes two",
  )

  let aesv3_context = EncryptionContext::{
    status: EncryptionStatus::EncryptedAuthorized,
    file_key: b"0123456789abcdef0123456789abcdef",
    access_mode: EncryptionAccessMode::UserAccess,
    permissions: DocumentPermissions::unrestricted(),
    cipher_version: CipherVersion::V5,
    encrypt_metadata: true,
    string_filter: test_filter(CryptFilterMethod::AESV3, 256),
    stream_filter: test_filter(CryptFilterMethod::AESV3, 256),
    embedded_file_filter: None,
  }
  let aesv3_encrypted = iv +
    crypto_aes_cbc_encrypt(
      aesv3_context.file_key,
      iv,
      b"aes three",
      @crypto.PaddingMode::PKCS7,
    )
  assert_eq(
    decrypt_stream(aesv3_context, object_id, aesv3_encrypted),
    b"aes three",
  )
}
