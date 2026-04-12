///|
test "classifier maps all 256 bytes into exactly one class" {
  let whitespace = [b'\x00', b'\t', b'\n', b'\f', b'\r', b' ']
  let delimiters = [b'(', b')', b'<', b'>', b'[', b']', b'/', b'%']

  for byte in 0..<=255 {
    let b = byte.to_byte()
    let class = classify_byte(b)
    match class {
      WhiteSpace => assert_eq(whitespace.contains(b), true)
      Delimiter => assert_eq(delimiters.contains(b), true)
      Regular => {
        assert_eq(whitespace.contains(b), false)
        assert_eq(delimiters.contains(b), false)
      }
    }
  }

  assert_eq(is_white_space(b'\x00'), true)
  assert_eq(is_white_space(b'\x20'), true)
  assert_eq(is_delimiter(b'('), true)
  assert_eq(is_delimiter(b'%'), true)
  assert_eq(is_delimiter(b'\x7b'), false)
  match classify_byte(b'\x80') {
    Regular => ()
    _ => fail("expected high-bit bytes to classify as regular")
  }
  match classify_byte(b'\xff') {
    Regular => ()
    _ => fail("expected high-bit bytes to classify as regular")
  }
}
