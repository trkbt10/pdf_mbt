///|
test "decode_ascii_hex handles digit pairs and pdf whitespace" {
  let encoded = Bytes::from_array([
    b'6', b'1', b' ', b'\t', b'\n', b'4', b'2', b'\r', b'\f', b'7', b'f', b'>',
  ])
  let decoded = decode_ascii_hex(encoded)
  assert_eq(decoded, Bytes::from_array([b'a', b'B', b'\x7f']))
}

///|
test "decode_ascii_hex pads an odd final digit before the end marker" {
  let encoded = Bytes::from_array([b'7', b'>'])
  let decoded = decode_ascii_hex(encoded)
  assert_eq(decoded, Bytes::from_array([b'\x70']))
}

///|
test "decode_ascii_hex stops at the end marker and ignores trailing bytes" {
  let encoded = Bytes::from_array([b'4', b'1', b'>', b'G', b'Z'])
  let decoded = decode_ascii_hex(encoded)
  assert_eq(decoded, Bytes::from_array([b'A']))
}

///|
test "decode_ascii_hex rejects invalid bytes before the end marker" {
  let encoded = Bytes::from_array([b'4', b'G', b'>'])
  let decoded : Result[Bytes, PdfFilterError] = try? decode_ascii_hex(encoded)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCIIHexDecode")
      assert_eq(reason.contains("invalid"), true)
    }
    _ => fail("expected invalid ASCIIHex input to fail")
  }
}
