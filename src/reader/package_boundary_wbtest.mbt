///|
test "reader package boundary compiles with allowed downstream imports" {
  let _ = try? reader_boundary_probe()
  let object = @objects.PdfObject::Null
  assert_eq(object == @objects.PdfObject::Null, true)

  let cursor = @lexer.ByteCursor::new(b"")
  assert_eq(cursor.offset(), 0L)
  assert_eq(cursor.peek() is None, true)

  assert_eq(@parser.parse_object(b"null") == @objects.PdfObject::Null, true)
}
