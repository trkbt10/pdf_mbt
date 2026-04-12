///|
test "literal string reader decodes balanced strings and escapes" {
  let empty = ByteCursor::new(b"()")
  assert_eq(read_literal_string(empty), b"")
  assert_eq(empty.offset(), 2L)
  let balanced = ByteCursor::new(b"(a(b)c)")
  assert_eq(read_literal_string(balanced), b"a(b)c")
  assert_eq(balanced.offset(), 7L)
  let escaped = ByteCursor::new(b"(\\n\\r\\t\\b\\f\\(\\)\\\\)")
  assert_eq(read_literal_string(escaped), b"\n\r\t\b\f()\\")
}

///|
test "literal string reader decodes octal escapes and eol rules" {
  let octal = ByteCursor::new(b"(\\053 \\0053 \\400)")
  assert_eq(
    read_literal_string(octal),
    Bytes::from_array([b'+', b' ', b'\x05', b'3', b' ', b'\x00']),
  )
  let continuation = ByteCursor::new(b"(a\\\r\nb\\\nc\\\rd)")
  assert_eq(read_literal_string(continuation), b"abcd")
  let eol = ByteCursor::new(b"(a\rb\r\nc\nd)")
  assert_eq(read_literal_string(eol), b"a\nb\nc\nd")
  let unknown = ByteCursor::new(b"(a\\qb)")
  assert_eq(read_literal_string(unknown), b"aqb")
}

///|
test "literal string reader reports eof before closing delimiter" {
  let cursor = ByteCursor::new(b"(unterminated")
  let result : Result[Bytes, @objects.PdfParseError] = try? read_literal_string(
    cursor,
  )
  match result {
    Err(UnexpectedEof(offset, context)) => {
      assert_eq(offset, 13L)
      assert_eq(context, "literal string")
    }
    _ => fail("expected literal string eof")
  }
}

///|
test "hex string reader decodes pairs whitespace odd digit and empty" {
  let empty = ByteCursor::new(b"<>")
  assert_eq(read_hex_string(empty), b"")
  assert_eq(empty.offset(), 2L)
  assert_eq(read_hex_string(ByteCursor::new(b"<901FA>")), b"\x90\x1f\xa0")
  assert_eq(
    read_hex_string(ByteCursor::new(b"<61 62\n63\t64\r\x00\x0c65>")),
    b"abcde",
  )
  assert_eq(read_hex_string(ByteCursor::new(b"<AaFf>")), b"\xaa\xff")
}

///|
test "hex string reader reports invalid hex and eof" {
  let invalid = ByteCursor::new(b"<0G>")
  let invalid_result : Result[Bytes, @objects.PdfParseError] = try? read_hex_string(
    invalid,
  )
  match invalid_result {
    Err(UnexpectedToken(offset, expected, actual)) => {
      assert_eq(offset, 2L)
      assert_eq(expected, "hex digit or >")
      assert_eq(actual, "G")
    }
    _ => fail("expected invalid hex diagnostic")
  }
  let eof = ByteCursor::new(b"<01")
  let eof_result : Result[Bytes, @objects.PdfParseError] = try? read_hex_string(
    eof,
  )
  match eof_result {
    Err(UnexpectedEof(offset, context)) => {
      assert_eq(offset, 3L)
      assert_eq(context, "hex string")
    }
    _ => fail("expected hex string eof")
  }
}
