///|
test "cursor tracks offsets for peek and byte reads" {
  let cursor = ByteCursor::new(b"ABC")
  assert_eq(cursor.offset(), 0L)
  assert_eq(cursor.peek(), Some(b'A'))
  assert_eq(cursor.peek_n(1), Some(b'B'))
  assert_eq(cursor.peek_n(3), None)
  assert_eq(cursor.read_byte(), Some(b'A'))
  assert_eq(cursor.offset(), 1L)
  assert_eq(cursor.read_byte(), Some(b'B'))
  assert_eq(cursor.read_byte(), Some(b'C'))
  assert_eq(cursor.read_byte(), None)
  assert_eq(cursor.offset(), 3L)
}

///|
test "cursor normalizes CR LF and CRLF as one logical eol" {
  let cr = ByteCursor::new(b"\rX")
  assert_eq(cr.read_eol(), true)
  assert_eq(cr.offset(), 1L)
  assert_eq(cr.peek(), Some(b'X'))
  let lf = ByteCursor::new(b"\nX")
  assert_eq(lf.read_eol(), true)
  assert_eq(lf.offset(), 1L)
  assert_eq(lf.peek(), Some(b'X'))
  let crlf = ByteCursor::new(b"\r\nX")
  assert_eq(crlf.read_eol(), true)
  assert_eq(crlf.offset(), 2L)
  assert_eq(crlf.peek(), Some(b'X'))
  let other = ByteCursor::new(b"X")
  assert_eq(other.read_eol(), false)
  assert_eq(other.offset(), 0L)
}

///|
test "cursor stream eol accepts LF and CRLF but rejects CR alone" {
  let lf = ByteCursor::new(b"\nstream data")
  lf.require_stream_eol()
  assert_eq(lf.offset(), 1L)
  let crlf = ByteCursor::new(b"\r\nstream data")
  crlf.require_stream_eol()
  assert_eq(crlf.offset(), 2L)
  let cr = ByteCursor::new(b"\rstream data")
  let result : Result[Unit, @objects.PdfParseError] = try? cr.require_stream_eol()
  match result {
    Err(InvalidStream(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("stream EOL"), true)
    }
    _ => fail("expected CR-only stream EOL rejection")
  }
}

///|
test "cursor raw byte reads preserve physical eol bytes" {
  let cursor = ByteCursor::new(b"A\r\nB")
  assert_eq(cursor.read_bytes(3L), b"A\r\n")
  assert_eq(cursor.offset(), 3L)
  assert_eq(cursor.read_byte(), Some(b'B'))
  let eof = ByteCursor::new(b"AB")
  let result : Result[Bytes, @objects.PdfParseError] = try? eof.read_bytes(3L)
  match result {
    Err(UnexpectedEof(offset, context)) => {
      assert_eq(offset, 2L)
      assert_eq(context, "raw bytes")
    }
    _ => fail("expected short raw read to fail")
  }
}
