///|
/// Public stream decoding entry point for PDF stream filter chains described
/// by spec/extracted/7.4-filters.spec.txt. This API is intended for
/// pdf-file-structure integration: the file structure reader can call it from
/// object stream decoding and cross-reference stream decoding paths, using the
/// PdfStream dictionary and raw stream bytes from pdf-objects.
///
/// Applies the stream dictionary Filter and DecodeParms entries, including
/// FlateDecode, LZWDecode, ASCIIHexDecode, ASCII85Decode with the ~> EOD
/// marker, RunLengthDecode, DCTDecode, JPXDecode JPEG 2000, and
/// CCITTFaxDecode Group 3 Group 4 fax decompression. CCITTFaxDecode emits
/// 1 bit per pixel MSB first rows padded byte boundaries. Unsupported filter
/// names are reported through PdfFilterError instead of being skipped.
pub fn decode_stream(stream : @objects.PdfStream) -> Bytes raise PdfFilterError {
  decode_stream_bytes(stream.dict, stream.data)
}

///|
/// Decodes a stream dictionary and raw bytes for the filter decoder.
///
/// Applies a single Filter name or a Filter array in order, maps DecodeParms
/// dictionaries by index, and returns the fully decoded bytes. FlateDecode and
/// LZWDecode honor predictor parameters such as Predictor, Columns, Colors,
/// BitsPerComponent, and EarlyChange. CCITTFaxDecode handles Group 3 1D,
/// Group 4 2D, and mixed Group 3 2D bilevel image data. RunLengthDecode
/// handles literal runs, repeat runs, and byte 128 as the end-of-data marker.
/// DCTDecode and JPXDecode JPEG 2000 decode image data to raw interleaved
/// sample bytes. CCITTFaxDecode output is 1 bit per pixel MSB first rows
/// padded byte boundaries.
///
/// Missing Filter entries return the original byte sequence unchanged.
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
      DCTDecode => decode_dct(current, spec.params)
      CCITTFaxDecode => decode_ccitt_fax(current, spec.params)
      JPXDecode => decode_jpx(current)
      Unsupported(name) => raise PdfFilterError::UnsupportedFilter(name)
    }
  }
  current
}
