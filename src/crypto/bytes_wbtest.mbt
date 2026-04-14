///|
test "byte helpers validate endian xor and block sizes" {
  assert_eq(le_u32_bytes(0x01020304L), Bytes::from_array([4, 3, 2, 1]))
  assert_eq(be_u32_bytes(0x01020304L), Bytes::from_array([1, 2, 3, 4]))
  assert_eq(zero_iv(4), Bytes::from_array([0, 0, 0, 0]))
  assert_eq(
    bytes_xor(Bytes::from_array([0xff, 0x0f]), Bytes::from_array([0x0f, 0xf0])),
    Bytes::from_array([0xf0, 0xff]),
  )

  let xor_error : Result[Bytes, PdfCryptoError] = try? bytes_xor(b"a", b"ab")
  match xor_error {
    Err(InvalidLength(_)) => ()
    _ => fail("expected unequal xor length to fail")
  }

  let block_error : Result[Unit, PdfCryptoError] = try? require_block_aligned(
    b"abc", 2, "data",
  )
  match block_error {
    Err(InvalidBlockSize(_)) => ()
    _ => fail("expected unaligned block length to fail")
  }
}
