///|
test "RC4 preserves length and matches compatibility vectors" {
  assert_eq(hex(rc4_transform(b"Key", b"Plaintext")), b"bbf316e8d940af0ad3")
  assert_eq(hex(rc4_transform(b"Wiki", b"pedia")), b"1021bf0420")
  assert_eq(rc4_transform(b"Secret", b"").length(), 0)

  let empty_key : Result[Bytes, PdfCryptoError] = try? rc4_transform(b"", b"x")
  match empty_key {
    Err(InvalidKey(_)) => ()
    _ => fail("expected empty RC4 key to fail")
  }
}
