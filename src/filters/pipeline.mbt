///|
/// Public stream decoding entry point for structural and future content
/// streams. This task only guarantees the identity behavior when no Filter
/// entry is present.
pub fn decode_stream(stream : @objects.PdfStream) -> Bytes raise PdfFilterError {
  decode_stream_bytes(stream.dict, stream.data)
}

///|
/// Decodes a stream dictionary and raw bytes. Missing Filter entries return
/// the original byte sequence unchanged.
pub fn decode_stream_bytes(
  dict : @objects.PdfDictionary,
  data : Bytes,
) -> Bytes raise PdfFilterError {
  let filter_key = @objects.PdfName::new(b"Filter")
  match dict.get(filter_key) {
    None => data
    Some(value) => handle_filter_entry(value, data)
  }
}

///|
fn handle_filter_entry(
  filter_entry : @objects.PdfObject,
  data : Bytes,
) -> Bytes raise PdfFilterError {
  match filter_entry {
    @objects.PdfObject::Null => data
    @objects.PdfObject::Name(name) =>
      raise PdfFilterError::UnsupportedFilter(name.to_text())
    @objects.PdfObject::Array(_) =>
      raise PdfFilterError::InvalidFilterSpec(
        "filter arrays are not yet supported",
      )
    _ =>
      raise PdfFilterError::InvalidFilterSpec(
        "Filter entry must be a name, array, or null",
      )
  }
}
