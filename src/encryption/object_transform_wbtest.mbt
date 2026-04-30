///|
fn transform_context() -> EncryptionContext {
  let filter = CryptFilter::{
    name: @objects.PdfName::new(b"Identity"),
    filter_method: CryptFilterMethod::Identity,
    auth_event: CryptFilterAuthEvent::DocOpen,
    length_bits: None,
  }
  EncryptionContext::{
    status: EncryptionStatus::EncryptedAuthorized,
    file_key: b"01234",
    access_mode: EncryptionAccessMode::UserAccess,
    permissions: DocumentPermissions::unrestricted(),
    cipher_version: CipherVersion::V1,
    encrypt_metadata: false,
    string_filter: filter,
    stream_filter: filter,
    embedded_file_filter: None,
  }
}

///|
test "object transform leaves signature contents and metadata Identity bytes unchanged" {
  let object_id = @objects.ObjectId::{ object_number: 9, generation_number: 0 }
  let sig : @objects.PdfDictionary = Map::new()
  sig[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Sig"),
  )
  sig[@objects.PdfName::new(b"Contents")] = @objects.PdfObject::String(b"hex")
  sig[@objects.PdfName::new(b"Reason")] = @objects.PdfObject::String(b"why")
  let stream_dict : @objects.PdfDictionary = Map::new()
  stream_dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Metadata"),
  )
  let object = @objects.PdfObject::Array([
    @objects.PdfObject::Dictionary(sig),
    @objects.PdfObject::Stream(@objects.PdfStream::{
      dict: stream_dict,
      data: b"<xml/>",
    }),
  ])

  let transformed = decrypt_pdf_object(transform_context(), object_id, object)
  match transformed {
    @objects.PdfObject::Array(values) => {
      match values[0] {
        @objects.PdfObject::Dictionary(out_sig) => {
          assert_eq(
            out_sig[@objects.PdfName::new(b"Contents")] ==
            @objects.PdfObject::String(b"hex"),
            true,
          )
          assert_eq(
            out_sig[@objects.PdfName::new(b"Reason")] ==
            @objects.PdfObject::String(b"why"),
            true,
          )
        }
        _ => fail("expected signature dictionary")
      }
      match values[1] {
        @objects.PdfObject::Stream(stream) => assert_eq(stream.data, b"<xml/>")
        _ => fail("expected metadata stream")
      }
    }
    _ => fail("expected transformed array")
  }
}

///|
test "object transform policy can skip Encrypt dictionary values" {
  let object_id = @objects.ObjectId::{ object_number: 10, generation_number: 0 }
  let policy = ObjectDecryptionPolicy::{
    in_encryption_dictionary: true,
    in_signature_contents: false,
    inside_encrypted_stream: false,
    already_decrypted_object_stream_member: false,
    stream_purpose: StreamDecryptPurpose::RegularStream,
  }
  let transformed = decrypt_pdf_object_with_policy(
    transform_context(),
    object_id,
    @objects.PdfObject::String(b"encrypted-dict-string"),
    policy,
  )
  assert_eq(
    transformed == @objects.PdfObject::String(b"encrypted-dict-string"),
    true,
  )
}
