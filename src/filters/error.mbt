///|
/// Errors returned by the PDF filter decoder for Filter and DecodeParms
/// processing.
///
/// InvalidDecodeParms covers malformed predictor configuration, including
/// Predictor, Columns, Colors, BitsPerComponent, and EarlyChange values.
/// UnsupportedFilter carries unsupported filter names such as CCITTFaxDecode,
/// JBIG2Decode, DCTDecode, JPXDecode, and Crypt so callers can identify the
/// failed filter and avoid corrupted data.
pub(all) suberror PdfFilterError {
  InvalidFilterSpec(String)
  InvalidDecodeParms(String, String)
  UnsupportedFilter(String)
  DecodeError(String, String)
} derive(Eq, Debug)
