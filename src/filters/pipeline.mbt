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
  execute_pipeline(pipeline, data)
}

///|
fn execute_pipeline(
  pipeline : Array[FilterSpec],
  data : Bytes,
) -> Bytes raise PdfFilterError {
  let mut current = data
  for spec in pipeline {
    current = match spec.name {
      ASCIIHexDecode => decode_ascii_hex(current)
      ASCII85Decode => decode_ascii85(current)
      FlateDecode => decode_flate(current, spec.params)
      LZWDecode => decode_lzw(current, spec.params)
      RunLengthDecode => decode_run_length(current)
      Unsupported(name) => raise PdfFilterError::UnsupportedFilter(name)
    }
  }
  current
}
