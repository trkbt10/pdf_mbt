///|
pub fn pkcs7_pad(data : Bytes, block_size : Int) -> Bytes raise PdfCryptoError {
  if block_size <= 0 || block_size > 255 {
    raise PdfCryptoError::InvalidBlockSize("PKCS7 block size must be in 1..255")
  }
  let pad_len = block_size - data.length() % block_size
  let out = data.to_array()
  for _ in 0..<pad_len {
    out.push(pad_len.to_byte())
  }
  Bytes::from_array(out)
}

///|
pub fn pkcs7_unpad(
  data : Bytes,
  block_size : Int,
) -> Bytes raise PdfCryptoError {
  if block_size <= 0 || block_size > 255 {
    raise PdfCryptoError::InvalidBlockSize("PKCS7 block size must be in 1..255")
  }
  if data.length() == 0 || data.length() % block_size != 0 {
    raise PdfCryptoError::InvalidPadding(
      "PKCS7 data must be non-empty and block aligned",
    )
  }
  let pad_len = data[data.length() - 1].to_int()
  if pad_len == 0 || pad_len > block_size || pad_len > data.length() {
    raise PdfCryptoError::InvalidPadding("invalid PKCS7 padding length")
  }
  let padding_start = data.length() - pad_len
  for index in padding_start..<data.length() {
    if data[index].to_int() != pad_len {
      raise PdfCryptoError::InvalidPadding("malformed PKCS7 padding bytes")
    }
  }
  bytes_slice(data, 0, data.length() - pad_len)
}
