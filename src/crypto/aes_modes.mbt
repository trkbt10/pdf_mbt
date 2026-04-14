///|
pub fn aes_cbc_encrypt(
  key : Bytes,
  iv : Bytes,
  data : Bytes,
  padding : PaddingMode,
) -> Bytes raise PdfCryptoError {
  require_fixed_length(iv, 16, "AES-CBC IV")
  let input = match padding {
    PKCS7 => pkcs7_pad(data, 16)
    NoPadding => {
      require_block_aligned(data, 16, "AES-CBC no-padding input")
      data
    }
  }
  let out : Array[Byte] = []
  let mut previous = iv
  let mut offset = 0
  while offset < input.length() {
    let block = bytes_xor(bytes_slice(input, offset, offset + 16), previous)
    let encrypted = aes_encrypt_block(key, block)
    out.append(encrypted.to_array().view())
    previous = encrypted
    offset += 16
  }
  Bytes::from_array(out)
}

///|
pub fn aes_cbc_decrypt(
  key : Bytes,
  iv : Bytes,
  data : Bytes,
  padding : PaddingMode,
) -> Bytes raise PdfCryptoError {
  require_fixed_length(iv, 16, "AES-CBC IV")
  require_block_aligned(data, 16, "AES-CBC ciphertext")
  let out : Array[Byte] = []
  let mut previous = iv
  let mut offset = 0
  while offset < data.length() {
    let cipher_block = bytes_slice(data, offset, offset + 16)
    let plain_block = bytes_xor(aes_decrypt_block(key, cipher_block), previous)
    out.append(plain_block.to_array().view())
    previous = cipher_block
    offset += 16
  }
  let plain = Bytes::from_array(out)
  match padding {
    PKCS7 => pkcs7_unpad(plain, 16)
    NoPadding => plain
  }
}
