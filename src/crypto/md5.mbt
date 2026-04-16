///|
pub fn md5_digest(input : Bytes) -> Bytes raise PdfCryptoError {
  require_hashable_input(input)
  Bytes::from_array(@x_crypto.md5(input))
}

///|
fn require_hashable_input(input : Bytes) -> Unit raise PdfCryptoError {
  if input.length().to_int64() > 0x1fffffffffffffffL {
    raise PdfCryptoError::InvalidLength("hash input is too large")
  }
}
