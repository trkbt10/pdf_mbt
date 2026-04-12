///|
test "parser reads empty and nested arrays" {
  assert_eq(@parser.parse_object(b"[]") == @objects.PdfObject::Array([]), true)
  assert_eq(
    @parser.parse_object(b"[1 [2 3] false]") ==
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Array([
        @objects.PdfObject::Integer(2L),
        @objects.PdfObject::Integer(3L),
      ]),
      @objects.PdfObject::Boolean(false),
    ]),
    true,
  )
}

///|
test "parser reads heterogeneous direct object arrays" {
  assert_eq(
    @parser.parse_object(b"[549 3.14 false (Ralph) /SomeName]") ==
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(549L),
      @objects.PdfObject::Real(3.14),
      @objects.PdfObject::Boolean(false),
      @objects.PdfObject::String(b"Ralph"),
      @objects.PdfObject::Name(@objects.PdfName::new(b"SomeName")),
    ]),
    true,
  )
}

///|
test "parser reads references inside arrays and reports array eof" {
  assert_eq(
    @parser.parse_object(b"[1 2 R]") ==
    @objects.PdfObject::Array([
      @objects.PdfObject::Ref(@objects.ObjectId::{
        object_number: 1,
        generation_number: 2,
      }),
    ]),
    true,
  )
  let result : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"[1 2",
  )
  match result {
    Err(UnexpectedEof(_, context)) => assert_eq(context, "array")
    _ => fail("expected array EOF")
  }
}
