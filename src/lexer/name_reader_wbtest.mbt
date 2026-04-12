///|
fn read_test_name(
  input : Bytes,
) -> @objects.PdfName raise @objects.PdfParseError {
  read_name(ByteCursor::new(input))
}

///|
test "name reader decodes required examples" {
  assert_eq(read_test_name(b"/Name1").bytes, b"Name1")
  assert_eq(read_test_name(b"/A#42").bytes, b"AB")
  assert_eq(read_test_name(b"/Lime#20Green").bytes, b"Lime Green")
  assert_eq(
    read_test_name(b"/paired#28#29parentheses").bytes,
    b"paired()parentheses",
  )
  assert_eq(
    read_test_name(b"/The_Key_of_F#23_Minor").bytes,
    b"The_Key_of_F#_Minor",
  )
}

///|
test "name reader supports empty names and stops at separators" {
  let eof_empty = ByteCursor::new(b"/")
  assert_eq(read_name(eof_empty).bytes, b"")
  assert_eq(eof_empty.offset(), 1L)
  let delimiter_empty = ByteCursor::new(b"//Next")
  assert_eq(read_name(delimiter_empty).bytes, b"")
  assert_eq(delimiter_empty.offset(), 1L)
  assert_eq(delimiter_empty.peek(), Some(b'/'))
  let with_delimiter = ByteCursor::new(b"/Name[1]")
  assert_eq(read_name(with_delimiter).bytes, b"Name")
  assert_eq(with_delimiter.offset(), 5L)
  assert_eq(with_delimiter.peek(), Some(b'['))
  let with_space = ByteCursor::new(b"/Name rest")
  assert_eq(read_name(with_space).bytes, b"Name")
  assert_eq(with_space.offset(), 5L)
  assert_eq(with_space.peek(), Some(b' '))
}

///|
test "name reader rejects decoded nul and preserves high-bit bytes" {
  let nul = ByteCursor::new(b"/A#00B")
  let result : Result[@objects.PdfName, @objects.PdfParseError] = try? read_name(
    nul,
  )
  match result {
    Err(InvalidName(offset, reason)) => {
      assert_eq(offset, 2L)
      assert_eq(reason.contains("NUL"), true)
    }
    _ => fail("expected NUL name escape rejection")
  }
  let high = read_test_name(Bytes::from_array([b'/', b'A', b'\x80', b'\xff']))
  assert_eq(high.bytes, Bytes::from_array([b'A', b'\x80', b'\xff']))
}

///|
test "name equality is decoded byte equality" {
  let escaped = read_test_name(b"/A#42")
  let plain = read_test_name(b"/AB")
  let different = read_test_name(b"/A#43")
  assert_eq(escaped == plain, true)
  assert_eq(escaped == different, false)
}
