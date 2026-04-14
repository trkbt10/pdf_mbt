///|
test "SHA-2 matches independent known-answer vectors" {
  assert_eq(
    hex(sha256_digest(b"")),
    b"e3b0c44298fc1c149afbf4c8996fb924" + b"27ae41e4649b934ca495991b7852b855",
  )
  assert_eq(
    hex(sha256_digest(b"abc")),
    b"ba7816bf8f01cfea414140de5dae2223" + b"b00361a396177a9cb410ff61f20015ad",
  )
  assert_eq(
    hex(sha384_digest(b"")),
    b"38b060a751ac96384cd9327eb1b1e36a" +
    b"21fdb71114be07434c0cc7bf63f6e1da" +
    b"274edebfe76f65fbd51ad2f14898b95b",
  )
  assert_eq(
    hex(sha384_digest(b"abc")),
    b"cb00753f45a35e8bb5a03d699ac65007" +
    b"272c32ab0eded1631a8b605a43ff5bed" +
    b"8086072ba1e7cc2358baeca134c825a7",
  )
  assert_eq(
    hex(sha512_digest(b"")),
    b"cf83e1357eefb8bdf1542850d66d8007" +
    b"d620e4050b5715dc83f4a921d36ce9ce" +
    b"47d0d13c5d85f2b0ff8318d2877eec2f" +
    b"63b931bd47417a81a538327af927da3e",
  )
  assert_eq(
    hex(sha512_digest(b"abc")),
    b"ddaf35a193617abacc417349ae204131" +
    b"12e6fa4e89a97ea20a9eeee64b55d39a" +
    b"2192992a274fc1a836ba3c23a3feebbd" +
    b"454d4423643ce80e2a9ac94fa54ca49f",
  )
}
