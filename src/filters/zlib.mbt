///|
/// Decodes a zlib-wrapped Flate stream without DecodeParms predictors.
pub fn decode_flate(data : Bytes) -> Bytes raise PdfFilterError {
  decode_zlib_stream(data)
}

///|
/// Validates a 6+ byte zlib container, decodes the contained DEFLATE
/// stream, then verifies the Adler-32 checksum that immediately follows
/// the final deflate block.
///
/// Earlier versions assumed `[2-byte header][deflate][4-byte adler32]` was
/// always tightly packed and read the checksum from `data.length() - 4`.
/// That heuristic breaks on a non-trivial population of real PDFs whose
/// stream `Length` value includes one or more trailing bytes (typically a
/// stray `\n` left over from PDF's stream/endstream EOL convention) sitting
/// AFTER the Adler-32. CID-font ToUnicode CMaps from several common PDF
/// producers exhibit this: every stream carries one extra trailing byte,
/// which made the old reader read the wrong four bytes as Adler-32 and
/// reject the stream as corrupt — the page silently fell back to
/// Latin-encoded glyphs and the document rendered as garbage. The fix is
/// to ask the deflate decoder where it actually stopped and read the
/// Adler-32 immediately after.
fn decode_zlib_stream(data : Bytes) -> Bytes raise PdfFilterError {
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
  let deflate_start = 2
  let max_deflate = data.length() - deflate_start
  // Hand the deflate decoder the entire post-header buffer; it consumes
  // exactly as much as the encoded blocks require and reports its stop
  // position so we can locate the Adler-32 immediately after.
  let deflate_view = data[deflate_start:data.length()].to_bytes()
  let (decoded, deflate_consumed) = decode_deflate_with_position(deflate_view)
  if deflate_consumed > max_deflate - 4 {
    raise PdfFilterError::DecodeError(
      "FlateDecode",
      "deflate body extends past end of zlib stream — Adler-32 missing",
    )
  }
  let checksum_start = deflate_start + deflate_consumed
  let expected = read_u32_be(data, checksum_start)
  validate_adler32("FlateDecode", decoded, expected)
  decoded
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
/// Reads a big-endian unsigned 32-bit integer from `data` starting at `start`.
/// The caller is responsible for bounds checking; values outside [0, 2^32-1]
/// cannot be produced because each byte contributes at most 8 bits.
pub fn read_u32_be(data : Bytes, start : Int) -> Int64 {
  (data[start].to_int64() << 24) |
  (data[start + 1].to_int64() << 16) |
  (data[start + 2].to_int64() << 8) |
  data[start + 3].to_int64()
}
