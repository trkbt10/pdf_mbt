///|
test "PKCS7 padding adds full blocks and rejects malformed tails" {
  assert_eq(
    pkcs7_pad(b"abc", 8),
    Bytes::from_array([b'a', b'b', b'c', 5, 5, 5, 5, 5]),
  )
  assert_eq(
    pkcs7_pad(b"12345678", 8),
    Bytes::from_array([
      b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', 8, 8, 8, 8, 8, 8, 8, 8,
    ]),
  )
  assert_eq(
    pkcs7_unpad(Bytes::from_array([b'a', b'b', b'c', 5, 5, 5, 5, 5]), 8),
    b"abc",
  )

  let bad : Result[Bytes, PdfCryptoError] = try? pkcs7_unpad(
    Bytes::from_array([b'a', b'b', b'c', 1, 2, 3, 4, 5]),
    8,
  )
  match bad {
    Err(InvalidPadding(_)) => ()
    _ => fail("expected malformed padding to fail")
  }
}
