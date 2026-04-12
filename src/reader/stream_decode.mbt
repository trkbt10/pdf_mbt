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
      match xref_stream_rejection_reason(stream.dict, offset) {
        Some(reason) => raise PdfReaderError::UnsupportedFilter(offset, reason)
        None => ()
      }
    ObjectStream => ()
  }

  match structural_stream_filter_reason(stream.dict, offset) {
    Some(reason) => raise PdfReaderError::UnsupportedFilter(offset, reason)
    None => stream.data
  }
}

///|
fn xref_stream_rejection_reason(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> String? raise PdfReaderError {
  let encrypt_key = @objects.PdfName::new(b"Encrypt")
  match dict.get(encrypt_key) {
    Some(_) => Some("Encrypt")
    None => structural_stream_filter_reason(dict, offset)
  }
}

///|
fn structural_stream_filter_reason(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> String? raise PdfReaderError {
  let filter_key = @objects.PdfName::new(b"Filter")
  match dict.get(filter_key) {
    None => None
    Some(@objects.PdfObject::Name(name)) => Some(name.to_text())
    Some(@objects.PdfObject::Array(values)) =>
      structural_stream_filter_reason_from_array(values, offset)
    Some(_) => Some("Filter")
  }
}

///|
fn structural_stream_filter_reason_from_array(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> String? raise PdfReaderError {
  if values.length() == 0 {
    raise PdfReaderError::UnsupportedFilter(offset, "Filter")
  }

  let crypt_name = @objects.PdfName::new(b"Crypt")
  let mut first_name : String? = None
  for value in values {
    match value {
      @objects.PdfObject::Name(name) => {
        let text = name.to_text()
        if name == crypt_name {
          return Some(text)
        }
        if first_name is None {
          first_name = Some(text)
        }
      }
      _ => raise PdfReaderError::UnsupportedFilter(offset, "Filter")
    }
  }

  match first_name {
    Some(reason) => Some(reason)
    None => raise PdfReaderError::UnsupportedFilter(offset, "Filter")
  }
}
