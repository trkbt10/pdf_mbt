///|
test "lexer package can use object model types" {
  let name = @objects.PdfName::new(b"LexerName")
  match _object_from_lexed_name(name) {
    Name(value) => assert_eq(value == name, true)
    _ => fail("expected name object")
  }
}
