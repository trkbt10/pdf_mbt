///|
test "parser recognizes booleans and null case sensitively" {
  assert_eq(
    @parser.parse_object(b"true") == @objects.PdfObject::Boolean(true),
    true,
  )
  assert_eq(
    @parser.parse_object(b"false") == @objects.PdfObject::Boolean(false),
    true,
  )
  assert_eq(@parser.parse_object(b"null") == @objects.PdfObject::Null, true)
  let result : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"True",
  )
  match result {
    Err(UnexpectedToken(offset, expected, actual)) => {
      assert_eq(offset, 0L)
      assert_eq(expected, "object")
      assert_eq(actual, "True")
    }
    _ => fail("expected case-sensitive keyword rejection")
  }
}

///|
test "parser reads signed decimal integers" {
  assert_eq(
    @parser.parse_object(b"123") == @objects.PdfObject::Integer(123L),
    true,
  )
  assert_eq(
    @parser.parse_object(b"+17") == @objects.PdfObject::Integer(17L),
    true,
  )
  assert_eq(
    @parser.parse_object(b"-98") == @objects.PdfObject::Integer(-98L),
    true,
  )
  assert_eq(@parser.parse_object(b"0") == @objects.PdfObject::Integer(0L), true)
  assert_eq(
    @parser.parse_object(b"43445") == @objects.PdfObject::Integer(43445L),
    true,
  )
}

///|
test "parser reads decimal real numbers containing period" {
  assert_eq(
    @parser.parse_object(b"34.5") == @objects.PdfObject::Real(34.5),
    true,
  )
  assert_eq(
    @parser.parse_object(b"-3.62") == @objects.PdfObject::Real(-3.62),
    true,
  )
  assert_eq(
    @parser.parse_object(b"+123.6") == @objects.PdfObject::Real(123.6),
    true,
  )
  assert_eq(@parser.parse_object(b"4.") == @objects.PdfObject::Real(4.0), true)
  assert_eq(
    @parser.parse_object(b"-.002") == @objects.PdfObject::Real(-0.002),
    true,
  )
  assert_eq(@parser.parse_object(b"0.0") == @objects.PdfObject::Real(0.0), true)
}

///|
test "parser rejects invalid numeric syntaxes" {
  for invalid in [b"16#FFFE", b"6.02E23", b"+", b"-", b".", b"+."] {
    let result : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
      invalid,
    )
    match result {
      Err(InvalidNumber(offset, lexeme)) => {
        assert_eq(offset, 0L)
        assert_eq(lexeme, invalid)
      }
      _ => fail("expected invalid numeric diagnostic")
    }
  }
}

///|
test "parser reads all scalar fragments until end of input" {
  let parser = @parser.ObjectParser::new(b"true -98 4. null")
  assert_eq(
    parser.parse_all_objects() ==
    [
      @objects.PdfObject::Boolean(true),
      @objects.PdfObject::Integer(-98L),
      @objects.PdfObject::Real(4.0),
      @objects.PdfObject::Null,
    ],
    true,
  )
}
