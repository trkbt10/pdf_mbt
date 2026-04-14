///|
pub fn rc4_transform(key : Bytes, data : Bytes) -> Bytes raise PdfCryptoError {
  if key.length() == 0 {
    raise PdfCryptoError::InvalidKey("RC4 key must not be empty")
  }

  let state = Array::make(256, 0)
  for index in 0..<256 {
    state[index] = index
  }

  let mut j = 0
  for i in 0..<256 {
    j = (j + state[i] + key[i % key.length()].to_int()) & 0xff
    state.swap(i, j)
  }

  let out = Array::make(data.length(), b'\x00')
  let mut i = 0
  j = 0
  for index in 0..<data.length() {
    i = (i + 1) & 0xff
    j = (j + state[i]) & 0xff
    state.swap(i, j)
    let stream_byte = state[(state[i] + state[j]) & 0xff]
    out[index] = data[index] ^ stream_byte.to_byte()
  }
  Bytes::from_array(out)
}
