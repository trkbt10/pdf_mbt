///|
/// Errors returned by the PDF filter decoder for Filter and DecodeParms
/// processing.
///
/// InvalidDecodeParms covers malformed predictor configuration, including
/// Predictor, Columns, Colors, BitsPerComponent, and EarlyChange values.
/// DecodeParms failures can also come from image filters such as CCITTFaxDecode.
/// DecodeError carries named failures from supported filters, including
/// CCITTFaxDecode and JPXDecode. UnsupportedFilter carries unsupported filter
/// names such as JBIG2Decode and Crypt so callers can identify the failed
/// filter and avoid corrupted data.
pub(all) suberror PdfFilterError {
  InvalidFilterSpec(String)
  InvalidDecodeParms(String, String)
  UnsupportedFilter(String)
  DecodeError(String, String)
} derive(Eq, Debug)
