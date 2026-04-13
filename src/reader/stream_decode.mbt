///|
priv enum StructuralStreamPurpose {
  XrefStream
  ObjectStream
} derive(Eq, Debug)

///|
fn decode_structural_stream(
  stream : @objects.PdfStream,
  purpose : StructuralStreamPurpose,
  offset~ : Int64,
) -> Bytes raise PdfReaderError {
  match purpose {
    XrefStream =>
      match xref_stream_rejection_reason(stream.dict) {
        Some(reason) => raise PdfReaderError::UnsupportedFilter(offset, reason)
        None => ()
      }
    ObjectStream => ()
  }

  let decoded_result : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream(
    stream,
  )
  match decoded_result {
    Ok(decoded) => decoded
    Err(error) => raise PdfReaderError::DecodeStreamError(offset, error)
  }
}

///|
fn xref_stream_rejection_reason(dict : @objects.PdfDictionary) -> String? {
  let encrypt_key = @objects.PdfName::new(b"Encrypt")
  match dict.get(encrypt_key) {
    Some(_) => Some("Encrypt")
    None =>
      match dict.get(@objects.PdfName::new(b"Filter")) {
        Some(@objects.PdfObject::Name(name)) => {
          let crypt_name = @objects.PdfName::new(b"Crypt")
          if name == crypt_name {
            Some("Crypt")
          } else {
            None
          }
        }
        Some(@objects.PdfObject::Array(values)) =>
          xref_stream_rejection_reason_from_array(values)
        _ => None
      }
  }
}

///|
fn xref_stream_rejection_reason_from_array(
  values : Array[@objects.PdfObject],
) -> String? {
  let crypt_name = @objects.PdfName::new(b"Crypt")
  for value in values {
    match value {
      @objects.PdfObject::Name(name) =>
        if name == crypt_name {
          return Some("Crypt")
        }
      _ => ()
    }
  }

  None
}
