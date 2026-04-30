///|
fn name_is(value : @objects.PdfName, expected : Bytes) -> Bool {
  value == @objects.PdfName::new(expected)
}

///|
fn object_transform_default_policy() -> ObjectDecryptionPolicy {
  ObjectDecryptionPolicy::{
    in_encryption_dictionary: false,
    in_signature_contents: false,
    inside_encrypted_stream: false,
    already_decrypted_object_stream_member: false,
    stream_purpose: StreamDecryptPurpose::RegularStream,
  }
}

///|
fn dictionary_stream_purpose(
  dict : @objects.PdfDictionary,
) -> StreamDecryptPurpose {
  match dict.get(@objects.PdfName::new(b"Type")) {
    Some(@objects.PdfObject::Name(name)) if name_is(name, b"Metadata") =>
      StreamDecryptPurpose::MetadataStream
    Some(@objects.PdfObject::Name(name)) if name_is(name, b"ObjStm") =>
      StreamDecryptPurpose::ObjectStream
    Some(@objects.PdfObject::Name(name)) if name_is(name, b"XRef") =>
      StreamDecryptPurpose::XrefStream
    Some(@objects.PdfObject::Name(name)) if name_is(name, b"EmbeddedFile") =>
      StreamDecryptPurpose::EmbeddedFileStream
    _ => StreamDecryptPurpose::RegularStream
  }
}

///|
fn dictionary_is_signature(dict : @objects.PdfDictionary) -> Bool {
  match dict.get(@objects.PdfName::new(b"Type")) {
    Some(@objects.PdfObject::Name(name)) => name_is(name, b"Sig")
    _ => false
  }
}

///|
fn external_file_stream(dict : @objects.PdfDictionary) -> Bool {
  dict.get(@objects.PdfName::new(b"F")) is Some(_)
}

///|
/// Recursively decrypts eligible strings and stream bytes with documented
/// exception rules from 7.6.2. Integers, booleans, names, references, nulls,
/// trailer ID values, Encrypt dictionary strings, signature Contents strings,
/// strings already inside encrypted streams, and object-stream members marked
/// as already decrypted are left byte-identical.
pub fn decrypt_pdf_object(
  context : EncryptionKey,
  object_id : @objects.ObjectId,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise PdfEncryptionError {
  decrypt_pdf_object_with_policy(
    context,
    object_id,
    object,
    object_transform_default_policy(),
  )
}

///|
/// Recursively decrypts a PDF object using an explicit exception policy for
/// reader integration, object streams, signature dictionaries, metadata
/// streams, embedded file streams, external file streams, and Encrypt
/// dictionary exemptions.
pub fn decrypt_pdf_object_with_policy(
  context : EncryptionKey,
  object_id : @objects.ObjectId,
  object : @objects.PdfObject,
  policy : ObjectDecryptionPolicy,
) -> @objects.PdfObject raise PdfEncryptionError {
  if policy.already_decrypted_object_stream_member {
    return object
  }
  match object {
    @objects.PdfObject::String(bytes) =>
      if policy.in_encryption_dictionary ||
        policy.in_signature_contents ||
        policy.inside_encrypted_stream {
        object
      } else {
        @objects.PdfObject::String(decrypt_string(context, object_id, bytes))
      }
    @objects.PdfObject::Array(values) => {
      let out : Array[@objects.PdfObject] = []
      for value in values {
        out.push(
          decrypt_pdf_object_with_policy(context, object_id, value, policy),
        )
      }
      @objects.PdfObject::Array(out)
    }
    @objects.PdfObject::Dictionary(dict) =>
      @objects.PdfObject::Dictionary(
        decrypt_pdf_dictionary(context, object_id, dict, policy),
      )
    @objects.PdfObject::Stream(stream) =>
      @objects.PdfObject::Stream(
        decrypt_pdf_stream(context, object_id, stream, policy),
      )
    _ => object
  }
}

///|
fn decrypt_pdf_dictionary(
  context : EncryptionKey,
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
  policy : ObjectDecryptionPolicy,
) -> @objects.PdfDictionary raise PdfEncryptionError {
  let out : @objects.PdfDictionary = Map::new()
  let is_signature = dictionary_is_signature(dict)
  for key, value in dict {
    let next_policy = ObjectDecryptionPolicy::{
      in_encryption_dictionary: policy.in_encryption_dictionary,
      in_signature_contents: is_signature && name_is(key, b"Contents"),
      inside_encrypted_stream: policy.inside_encrypted_stream,
      already_decrypted_object_stream_member: false,
      stream_purpose: policy.stream_purpose,
    }
    out[key] = decrypt_pdf_object_with_policy(
      context, object_id, value, next_policy,
    )
  }
  out
}

///|
fn decrypt_pdf_stream(
  context : EncryptionKey,
  object_id : @objects.ObjectId,
  stream : @objects.PdfStream,
  policy : ObjectDecryptionPolicy,
) -> @objects.PdfStream raise PdfEncryptionError {
  let stream_purpose = if external_file_stream(stream.dict) {
    StreamDecryptPurpose::ExternalFileStream
  } else {
    dictionary_stream_purpose(stream.dict)
  }
  let dict_policy = ObjectDecryptionPolicy::{
    in_encryption_dictionary: policy.in_encryption_dictionary,
    in_signature_contents: false,
    inside_encrypted_stream: true,
    already_decrypted_object_stream_member: false,
    stream_purpose,
  }
  let dict = decrypt_pdf_dictionary(
    context,
    object_id,
    stream.dict,
    dict_policy,
  )
  let data = match stream_purpose {
    ExternalFileStream => stream.data
    MetadataStream if !context.encrypt_metadata => stream.data
    EmbeddedFileStream =>
      decrypt_embedded_file_stream(context, object_id, stream.data)
    _ => decrypt_stream(context, object_id, stream.data)
  }
  @objects.PdfStream::{ dict, data }
}
