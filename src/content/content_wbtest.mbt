///|
test "decoded content input starts at offset zero" {
  let input = ContentInput::new(b"BT")
  assert_eq(input.offset(), 0L)
}

///|
test "decoded content input delegates cursor semantics" {
  let input = ContentInput::new(b"AB")
  assert_eq(input.peek(), Some(b'A'))
  assert_eq(input.read_byte(), Some(b'A'))
  assert_eq(input.offset(), 1L)
}
