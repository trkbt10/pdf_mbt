///|
/// Zlib container metadata for FlateDecode streams used by the
/// pdf-file-structure reader integration.
///
/// The filter decoder shall integrate with the existing
/// `pdf-file-structure` reader to decode compressed streams on demand. The
/// reader calls the filter decoder from object stream decoding and
/// cross-reference stream decoding paths for FlateDecode-compressed object
/// streams and xref streams, passing the stream dictionary and raw stream bytes
/// and receiving decoded bytes or filter chain failures with the filter name
/// and reason.
priv struct ZlibStream {
  deflate_data : Bytes
  expected_adler32 : Int64
}

///|
/// Decodes a zlib-wrapped Flate stream without DecodeParms predictors.
pub fn decode_flate(data : Bytes) -> Bytes raise PdfFilterError {
  let zlib_data = data
  let decoded = decode_zlib_stream(zlib_data)
  decoded
}

///|
fn parse_zlib_stream(data : Bytes) -> ZlibStream raise PdfFilterError {
  if data.length() < 7 {
    raise PdfFilterError::DecodeError("FlateDecode", "truncated zlib stream")
  }

  let cmf = data[0].to_int()
  let flg = data[1].to_int()

  if (cmf & 0x0f) != 8 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "invalid zlib compression method",
    )
  }

  if cmf >> 4 > 7 {
    raise PdfFilterError::DecodeError("FlateDecode", "invalid zlib window size")
  }

  if (cmf * 256 + flg) % 31 != 0 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "invalid zlib header check bits",
    )
  }

  if (flg & 0x20) != 0 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "preset dictionary streams are not supported",
    )
  }

  let checksum_start = data.length() - 4
  ZlibStream::{
    deflate_data: data[2:checksum_start].to_bytes(),
    expected_adler32: read_u32_be(data, checksum_start),
  }
}

///|
fn adler32(data : Bytes) -> Int64 {
  let modulus = 65521L
  let mut s1 = 1L
  let mut s2 = 0L
  let mut index = 0

  while index < data.length() {
    s1 = (s1 + data[index].to_int64()) % modulus
    s2 = (s2 + s1) % modulus
    index = index + 1
  }

  (s2 << 16) | s1
}

///|
fn validate_adler32(
  filter_name : String,
  decoded : Bytes,
  expected : Int64,
) -> Unit raise PdfFilterError {
  let actual = adler32(decoded)
  if actual != expected {
    raise PdfFilterError::DecodeError(filter_name, "Adler-32 checksum mismatch")
  }
}

///|
fn read_u32_be(data : Bytes, start : Int) -> Int64 {
  (data[start].to_int64() << 24) |
  (data[start + 1].to_int64() << 16) |
  (data[start + 2].to_int64() << 8) |
  data[start + 3].to_int64()
}
