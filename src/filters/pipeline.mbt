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
  let pipeline = normalize_pipeline(dict)
  match pipeline.get(0) {
    None => data
    Some(spec) => execute_pipeline(spec, data)
  }
}

///|
fn execute_pipeline(
  spec : FilterSpec,
  data : Bytes,
) -> Bytes raise PdfFilterError {
  match spec.name {
    ASCIIHexDecode => decode_ascii_hex(data)
    ASCII85Decode => decode_ascii85(data)
    FlateDecode => raise PdfFilterError::UnsupportedFilter(spec.name.to_text())
    LZWDecode => raise PdfFilterError::UnsupportedFilter(spec.name.to_text())
    RunLengthDecode => decode_run_length(data)
    Unsupported(name) => raise PdfFilterError::UnsupportedFilter(name)
  }
}
