///|
test "parser package can use lexer and object model types" {
  let name = @objects.PdfName::new(b"ParserName")
  match _object_from_lexer_name(name) {
    Name(value) => assert_eq(value == name, true)
    _ => fail("expected name object")
  }
}
