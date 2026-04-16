///|
test "SHA-2 matches independent known-answer vectors" {
  assert_eq(
    hex(sha256_digest(b"")),
    "e3b0c44298fc1c149afbf4c8996fb924" + "27ae41e4649b934ca495991b7852b855",
  )
  assert_eq(
    hex(sha256_digest(b"abc")),
    "ba7816bf8f01cfea414140de5dae2223" + "b00361a396177a9cb410ff61f20015ad",
  )
  assert_eq(
    hex(sha384_digest(b"")),
    "38b060a751ac96384cd9327eb1b1e36a" +
    "21fdb71114be07434c0cc7bf63f6e1da" +
    "274edebfe76f65fbd51ad2f14898b95b",
  )
  assert_eq(
    hex(sha384_digest(b"abc")),
    "cb00753f45a35e8bb5a03d699ac65007" +
    "272c32ab0eded1631a8b605a43ff5bed" +
    "8086072ba1e7cc2358baeca134c825a7",
  )
  assert_eq(
    hex(sha512_digest(b"")),
    "cf83e1357eefb8bdf1542850d66d8007" +
    "d620e4050b5715dc83f4a921d36ce9ce" +
    "47d0d13c5d85f2b0ff8318d2877eec2f" +
    "63b931bd47417a81a538327af927da3e",
  )
  assert_eq(
    hex(sha512_digest(b"abc")),
    "ddaf35a193617abacc417349ae204131" +
    "12e6fa4e89a97ea20a9eeee64b55d39a" +
    "2192992a274fc1a836ba3c23a3feebbd" +
    "454d4423643ce80e2a9ac94fa54ca49f",
  )
}
