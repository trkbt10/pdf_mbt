///|
fn decrypt_loaded_object(
  file : PdfFile,
  object_id : @objects.ObjectId,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise PdfReaderError {
  if should_skip_object_decryption(file, object_id) {
    return object
  }
  match file.encryption {
    Some(context) => decrypt_object_value(context, object_id, object)
    None => object
  }
}

///|
fn should_skip_object_decryption(
  file : PdfFile,
  object_id : @objects.ObjectId,
) -> Bool {
  match file.trailer.encrypt {
    Some(encrypt_id) => encrypt_id == object_id
    None => false
  }
}

///|
fn decrypt_object_value(
  context : @encryption.EncryptionKey,
  object_id : @objects.ObjectId,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise PdfReaderError {
  match object {
    @objects.PdfObject::String(bytes) =>
      @objects.PdfObject::String(
        decrypt_string_bytes(context, object_id, bytes),
      )
    @objects.PdfObject::Array(values) => {
      let decrypted : Array[@objects.PdfObject] = []
      for value in values {
        decrypted.push(decrypt_object_value(context, object_id, value))
      }
      @objects.PdfObject::Array(decrypted)
    }
    @objects.PdfObject::Dictionary(dict) =>
      @objects.PdfObject::Dictionary(
        decrypt_dictionary(context, object_id, dict),
      )
    @objects.PdfObject::Stream(stream) =>
      @objects.PdfObject::Stream(
        decrypt_stream_object(context, object_id, stream),
      )
    _ => object
  }
}

///|
fn decrypt_dictionary(
  context : @encryption.EncryptionKey,
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
) -> @objects.PdfDictionary raise PdfReaderError {
  let decrypted : @objects.PdfDictionary = Map::new()
  for key, value in dict {
    decrypted[key] = decrypt_object_value(context, object_id, value)
  }
  decrypted
}

///|
fn decrypt_stream_object(
  context : @encryption.EncryptionKey,
  object_id : @objects.ObjectId,
  stream : @objects.PdfStream,
) -> @objects.PdfStream raise PdfReaderError {
  let dict = decrypt_dictionary(context, object_id, stream.dict)
  let data = if should_decrypt_stream_data(context, stream.dict) {
    decrypt_stream_bytes(context, object_id, stream.data)
  } else {
    stream.data
  }
  @objects.PdfStream::{ dict, data }
}

///|
fn should_decrypt_stream_data(
  context : @encryption.EncryptionKey,
  dict : @objects.PdfDictionary,
) -> Bool {
  if context.encrypt_metadata {
    return true
  }
  match dict.get(@objects.PdfName::new(b"Type")) {
    Some(@objects.PdfObject::Name(name)) =>
      name != @objects.PdfName::new(b"Metadata")
    _ => true
  }
}

///|
fn decrypt_string_bytes(
  context : @encryption.EncryptionKey,
  object_id : @objects.ObjectId,
  bytes : Bytes,
) -> Bytes raise PdfReaderError {
  try @encryption.decrypt_string(context, object_id, bytes) catch {
    error => raise PdfReaderError::EncryptionError(error)
  } noraise {
    decrypted => decrypted
  }
}

///|
fn decrypt_stream_bytes(
  context : @encryption.EncryptionKey,
  object_id : @objects.ObjectId,
  bytes : Bytes,
) -> Bytes raise PdfReaderError {
  try @encryption.decrypt_stream(context, object_id, bytes) catch {
    error => raise PdfReaderError::EncryptionError(error)
  } noraise {
    decrypted => decrypted
  }
}
