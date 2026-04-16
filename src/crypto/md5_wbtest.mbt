///|
test "MD5 matches RFC 1321 known-answer vectors" {
  assert_eq(hex(md5_digest(b"")), "d41d8cd98f00b204e9800998ecf8427e")
  assert_eq(hex(md5_digest(b"abc")), "900150983cd24fb0d6963f7d28e17f72")
  assert_eq(
    hex(md5_digest(b"message digest")),
    "f96b697d7cb7938d525a2f31aaf161d0",
  )
}
