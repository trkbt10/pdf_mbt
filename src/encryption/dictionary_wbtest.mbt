///|
fn wb_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn wb_dict() -> @objects.PdfDictionary {
  Map::new()
}

///|
test "common encryption dictionary parses crypt filter references" {
  let std_cf : @objects.PdfDictionary = wb_dict()
  std_cf[wb_name(b"CFM")] = @objects.PdfObject::Name(wb_name(b"AESV2"))
  std_cf[wb_name(b"AuthEvent")] = @objects.PdfObject::Name(wb_name(b"DocOpen"))
  std_cf[wb_name(b"Length")] = @objects.PdfObject::Integer(128L)
  let cf : @objects.PdfDictionary = wb_dict()
  cf[wb_name(b"StdCF")] = @objects.PdfObject::Dictionary(std_cf)
  let dict : @objects.PdfDictionary = wb_dict()
  dict[wb_name(b"Filter")] = @objects.PdfObject::Name(wb_name(b"Standard"))
  dict[wb_name(b"V")] = @objects.PdfObject::Integer(4L)
  dict[wb_name(b"Length")] = @objects.PdfObject::Integer(128L)
  dict[wb_name(b"CF")] = @objects.PdfObject::Dictionary(cf)
  dict[wb_name(b"StmF")] = @objects.PdfObject::Name(wb_name(b"StdCF"))
  dict[wb_name(b"StrF")] = @objects.PdfObject::Name(wb_name(b"Identity"))

  let parsed = parse_common_encryption_dictionary(dict)
  assert_eq(parsed.filter == wb_name(b"Standard"), true)
  assert_eq(parsed.cipher_version == CipherVersion::V4, true)
  assert_eq(parsed.stream_filter_name == wb_name(b"StdCF"), true)
  assert_eq(parsed.string_filter_name == wb_name(b"Identity"), true)
}

///|
test "common encryption dictionary rejects unknown CF references" {
  let dict : @objects.PdfDictionary = wb_dict()
  dict[wb_name(b"Filter")] = @objects.PdfObject::Name(wb_name(b"Standard"))
  dict[wb_name(b"V")] = @objects.PdfObject::Integer(4L)
  dict[wb_name(b"StmF")] = @objects.PdfObject::Name(wb_name(b"Missing"))
  let result : Result[EncryptionDictionaryInfo, PdfEncryptionError] = try? parse_common_encryption_dictionary(
    dict,
  )
  match result {
    Err(MalformedEncryptionDictionary(field, _)) => assert_eq(field, "StmF")
    _ => fail("expected malformed StmF reference")
  }
}

///|
test "standard security handler fields parse permissions and required lengths" {
  let dict = build_legacy_test_dict(2, 5, b"user", b"owner", FileIdentifier::{
    first: b"id",
    second: None,
  })
  let parsed = parse_standard_security_handler_fields(dict)
  assert_eq(parsed.revision, 2)
  assert_eq(parsed.key_length_bytes, 5)
  assert_eq(parsed.permissions.print, true)
}

///|
test "public-key dictionary preserves recipients and unsupported diagnostics" {
  let dict : @objects.PdfDictionary = wb_dict()
  dict[wb_name(b"Filter")] = @objects.PdfObject::Name(wb_name(b"Adobe.PubSec"))
  dict[wb_name(b"SubFilter")] = @objects.PdfObject::Name(
    wb_name(b"adbe.pkcs7.s5"),
  )
  dict[wb_name(b"Recipients")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"cms-recipient"),
  ])
  dict[wb_name(b"P")] = @objects.PdfObject::Integer(-4L)

  let parsed = parse_public_key_encryption_dictionary(dict)
  assert_eq(parsed.recipients.length(), 1)
  assert_eq(parsed.permissions.unwrap().copy, true)

  let malformed : @objects.PdfDictionary = wb_dict()
  malformed[wb_name(b"Filter")] = @objects.PdfObject::Name(
    wb_name(b"Adobe.PubSec"),
  )
  let result : Result[PublicKeyEncryptionMetadata, PdfEncryptionError] = try? parse_public_key_encryption_dictionary(
    malformed,
  )
  match result {
    Err(UnsupportedSecurityHandler(reason)) =>
      assert_eq(reason.contains("Recipients"), true)
    _ => fail("expected unsupported public-key handler diagnostic")
  }
}

///|
test "encrypted payload dictionary requires subtype and preserves version" {
  let dict : @objects.PdfDictionary = wb_dict()
  dict[wb_name(b"Type")] = @objects.PdfObject::Name(
    wb_name(b"EncryptedPayload"),
  )
  dict[wb_name(b"Subtype")] = @objects.PdfObject::Name(
    wb_name(b"application#2fpdf"),
  )
  dict[wb_name(b"Version")] = @objects.PdfObject::String(b"2.0")

  let info = parse_encrypted_payload_dictionary(dict)
  assert_eq(info.subtype == wb_name(b"application#2fpdf"), true)
  assert_eq(info.has_version_marker(), true)

  let bad : @objects.PdfDictionary = wb_dict()
  let result : Result[EncryptedPayloadInfo, PdfEncryptionError] = try? parse_encrypted_payload_dictionary(
    bad,
  )
  match result {
    Err(MalformedEncryptionDictionary(field, _)) => assert_eq(field, "Subtype")
    _ => fail("expected missing subtype diagnostic")
  }
}
