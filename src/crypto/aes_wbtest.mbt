///|
test "AES block operations match FIPS vectors" {
  let block = unhex("00112233445566778899aabbccddeeff")
  let aes128_key = unhex("000102030405060708090a0b0c0d0e0f")
  let aes128_cipher = unhex("69c4e0d86a7b0430d8cdb78070b4c55a")
  assert_eq(aes_encrypt_block(aes128_key, block), aes128_cipher)
  assert_eq(aes_decrypt_block(aes128_key, aes128_cipher), block)

  let aes256_key = unhex(
    "000102030405060708090a0b0c0d0e0f" + "101112131415161718191a1b1c1d1e1f",
  )
  let aes256_cipher = unhex("8ea2b7ca516745bfeafc49904b496089")
  assert_eq(aes_encrypt_block(aes256_key, block), aes256_cipher)
  assert_eq(aes_ecb_decrypt_block(aes256_key, aes256_cipher), block)
}

///|
test "AES CBC validates IV, no-padding alignment, and PKCS7 round trips" {
  let key = unhex("2b7e151628aed2a6abf7158809cf4f3c")
  let iv = unhex("000102030405060708090a0b0c0d0e0f")
  let plain = unhex("6bc1bee22e409f96e93d7e117393172a")
  let cipher = unhex("7649abac8119b246cee98e9b12e9197d")
  assert_eq(aes_cbc_encrypt(key, iv, plain, NoPadding), cipher)
  assert_eq(aes_cbc_decrypt(key, iv, cipher, NoPadding), plain)

  let padded = aes_cbc_encrypt(key, iv, b"pdf", PKCS7)
  assert_eq(aes_cbc_decrypt(key, iv, padded, PKCS7), b"pdf")

  let bad_iv : Result[Bytes, PdfCryptoError] = try? aes_cbc_encrypt(
    key,
    b"short",
    plain,
    NoPadding,
  )
  match bad_iv {
    Err(InvalidLength(_)) => ()
    _ => fail("expected invalid IV length to fail")
  }

  let bad_block : Result[Bytes, PdfCryptoError] = try? aes_cbc_decrypt(
    key,
    iv,
    b"abc",
    NoPadding,
  )
  match bad_block {
    Err(InvalidBlockSize(_)) => ()
    _ => fail("expected unaligned ciphertext to fail")
  }
}
