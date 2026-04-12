///|
test "parser reads literal strings through object parser" {
  assert_eq(
    @parser.parse_object(b"(Ralph)") == @objects.PdfObject::String(b"Ralph"),
    true,
  )
  assert_eq(
    @parser.parse_object(b"(a\\n(b)c)") ==
    @objects.PdfObject::String(b"a\n(b)c"),
    true,
  )
  assert_eq(
    @parser.parse_object(b"(a\\\r\nb\rc)") ==
    @objects.PdfObject::String(b"ab\nc"),
    true,
  )
}

///|
test "parser reads hexadecimal strings through object parser" {
  assert_eq(
    @parser.parse_object(b"<901FA>") ==
    @objects.PdfObject::String(b"\x90\x1f\xa0"),
    true,
  )
  assert_eq(
    @parser.parse_object(b"<61 62\n63>") == @objects.PdfObject::String(b"abc"),
    true,
  )
}

///|
test "parser reads names through object parser" {
  assert_eq(
    @parser.parse_object(b"/SomeName") ==
    @objects.PdfObject::Name(@objects.PdfName::new(b"SomeName")),
    true,
  )
  assert_eq(
    @parser.parse_object(b"/Lime#20Green") ==
    @objects.PdfObject::Name(@objects.PdfName::new(b"Lime Green")),
    true,
  )
  assert_eq(
    @parser.parse_object(Bytes::from_array([b'/', b'A', b'\x80'])) ==
    @objects.PdfObject::Name(
      @objects.PdfName::new(Bytes::from_array([b'A', b'\x80'])),
    ),
    true,
  )
}

///|
test "parser keeps cursor aligned after string and name objects" {
  let parser = @parser.ObjectParser::new(b"(Ralph) /SomeName <41> 42")
  assert_eq(
    parser.parse_all_objects() ==
    [
      @objects.PdfObject::String(b"Ralph"),
      @objects.PdfObject::Name(@objects.PdfName::new(b"SomeName")),
      @objects.PdfObject::String(b"A"),
      @objects.PdfObject::Integer(42L),
    ],
    true,
  )
}
