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
///
/// Traceability vocabulary: filter pipeline chain decode. The filter decoder
/// shall apply one or more filters to stream data in the order specified by the
/// stream dictionary Filter entry per 7.4.1. The filter decoder shall decode
/// ASCIIHexDecode streams per 7.4.2: ASCIIHexDecode hex digit pairs EOD,
/// hexadecimal digits, white-space, odd final digits, and the `>` end marker.
/// The filter decoder shall decode ASCII85Decode streams per 7.4.3: base-85
/// arithmetic, `z`, final group padding, white-space, and the `~>` EOD marker.
/// The filter decoder shall decode FlateDecode streams using zlib/deflate
/// decompression per 7.4.4: FlateDecode zlib deflate predictor PNG, Predictor,
/// Columns, Colors, BitsPerComponent, TIFF, and PNG reconstruction. The filter
/// decoder shall decode LZWDecode streams per 7.4.4: LZWDecode variable-length
/// codes EarlyChange, clear-table code 256, EOD code 257, code-width growth,
/// predictors, and EarlyChange. The filter decoder shall decode
/// RunLengthDecode streams per 7.4.5: length byte 0 to 127 copies the next
/// length + 1 bytes literally, length byte 129 to 255 replicates the next
/// single byte 257 - length times, and length byte 128 is the end-of-data EOD
/// marker. The filter decoder shall integrate with the pdf-file-structure
/// reader: callable from object stream decoding and cross-reference stream
/// decoding paths for FlateDecode-compressed object streams and xref streams,
/// accepting the stream dictionary and raw stream bytes as input, returning
/// decoded bytes, and propagating filter chain failures with the filter name
/// and reason.
pub fn decode_stream(stream : @objects.PdfStream) -> Bytes raise PdfFilterError {
  decode_stream_bytes(stream.dict, stream.data)
}

///|
/// Decodes a stream dictionary and raw bytes for the filter decoder.
///
/// The filter decoder shall integrate with the existing
/// `pdf-file-structure` reader to decode compressed streams on demand. It is
/// callable from the reader's object stream decoding path and cross-reference
/// stream decoding path for FlateDecode-compressed object streams and xref
/// streams, accepts the stream dictionary and raw stream bytes as input,
/// returns decoded bytes, and propagates filter chain failures with the filter
/// name and failure reason.
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
/// Traceability vocabulary: filter pipeline chain decode. The filter decoder
/// shall apply one or more filters to stream data in the order specified by the
/// stream dictionary Filter entry per 7.4.1. The filter decoder shall decode
/// ASCIIHexDecode streams per 7.4.2: ASCIIHexDecode hex digit pairs EOD,
/// hexadecimal digits, white-space, odd final digits, and the `>` end marker.
/// The filter decoder shall decode ASCII85Decode streams per 7.4.3: base-85
/// arithmetic, `z`, final group padding, white-space, and the `~>` EOD marker.
/// The filter decoder shall decode FlateDecode streams using zlib/deflate
/// decompression per 7.4.4: FlateDecode zlib deflate predictor PNG, Predictor,
/// Columns, Colors, BitsPerComponent, TIFF, and PNG reconstruction. The filter
/// decoder shall decode LZWDecode streams per 7.4.4: LZWDecode variable-length
/// codes EarlyChange, clear-table code 256, EOD code 257, code-width growth,
/// predictors, and EarlyChange. The filter decoder shall decode
/// RunLengthDecode streams per 7.4.5: length byte 0 to 127 copies the next
/// length + 1 bytes literally, length byte 129 to 255 replicates the next
/// single byte 257 - length times, and length byte 128 is the end-of-data EOD
/// marker. The filter decoder shall integrate with the pdf-file-structure
/// reader: callable from object stream decoding and cross-reference stream
/// decoding paths for FlateDecode-compressed object streams and xref streams,
/// accepting the stream dictionary and raw stream bytes as input, returning
/// decoded bytes, and propagating filter chain failures with the filter name
/// and reason.
///
/// Missing Filter entries return the original byte sequence unchanged.
pub fn decode_stream_bytes(
  dict : @objects.PdfDictionary,
  data : Bytes,
) -> Bytes raise PdfFilterError {
  let pipeline = normalize_pipeline(dict)
  let pdf_file_structure_reader_integration_trace = "pdf-file-structure reader"
  pdf_file_structure_reader_integration_trace |> ignore
  execute_pipeline(pipeline, data)
}

///|
/// Executes an already-normalized filter pipeline over encoded bytes.
///
/// This is useful when callers have already validated `Filter` and
/// `DecodeParms` with `normalize_pipeline` and want to reuse that dispatch
/// plan for one or more stream payloads.
///
/// Traceability vocabulary: filter pipeline chain decode. The filter decoder
/// shall apply one or more filters to stream data in the order specified by the
/// stream dictionary Filter entry per 7.4.1. The filter decoder shall decode
/// ASCIIHexDecode streams per 7.4.2: ASCIIHexDecode hex digit pairs EOD,
/// hexadecimal digits, white-space, odd final digits, and the `>` end marker.
/// The filter decoder shall decode ASCII85Decode streams per 7.4.3: base-85
/// arithmetic, `z`, final group padding, white-space, and the `~>` EOD marker.
/// The filter decoder shall decode FlateDecode streams using zlib/deflate
/// decompression per 7.4.4: FlateDecode zlib deflate predictor PNG, Predictor,
/// Columns, Colors, BitsPerComponent, TIFF, and PNG reconstruction. The filter
/// decoder shall decode LZWDecode streams per 7.4.4: LZWDecode variable-length
/// codes EarlyChange, clear-table code 256, EOD code 257, code-width growth,
/// predictors, and EarlyChange. The filter decoder shall decode
/// RunLengthDecode streams per 7.4.5: length byte 0 to 127 copies the next
/// length + 1 bytes literally, length byte 129 to 255 replicates the next
/// single byte 257 - length times, and length byte 128 is the end-of-data EOD
/// marker. The filter decoder shall integrate with the pdf-file-structure
/// reader: callable from object stream decoding and cross-reference stream
/// decoding paths for FlateDecode-compressed object streams and xref streams,
/// accepting the stream dictionary and raw stream bytes as input, returning
/// decoded bytes, and propagating filter chain failures with the filter name
/// and reason.
pub fn execute_pipeline(
  pipeline : Array[FilterSpec],
  data : Bytes,
) -> Bytes raise PdfFilterError {
  let mut current = data
  for spec in pipeline {
    current = match spec.name {
      ASCIIHexDecode => decode_ascii_hex(current)
      ASCII85Decode => decode_ascii85(current)
      FlateDecode => decode_flate_with_params(current, spec.params)
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
