///|
test "parser reads indirect references with bounded lookahead" {
  assert_eq(
    @parser.parse_object(b"1 2 R") ==
    @objects.PdfObject::Ref(@objects.ObjectId::{
      object_number: 1,
      generation_number: 2,
    }),
    true,
  )
}

///|
test "parser preserves integer fallback tokens after failed reference lookahead" {
  let parser = @parser.ObjectParser::new(b"1 2 true")
  assert_eq(
    parser.parse_all_objects() ==
    [
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::Boolean(true),
    ],
    true,
  )
  let mixed = @parser.ObjectParser::new(b"1 2 true /Name")
  assert_eq(
    mixed.parse_all_objects() ==
    [
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::Boolean(true),
      @objects.PdfObject::Name(@objects.PdfName::new(b"Name")),
    ],
    true,
  )
  let integers = @parser.ObjectParser::new(b"1 2 3")
  assert_eq(
    integers.parse_all_objects() ==
    [
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::Integer(3L),
    ],
    true,
  )
}

///|
test "parser rejects invalid indirect reference identifiers" {
  let zero_object : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"0 2 R",
  )
  match zero_object {
    Err(InvalidIndirectObject(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("object number"), true)
    }
    _ => fail("expected invalid object number")
  }
  let negative_generation : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"1 -1 R",
  )
  match negative_generation {
    Err(InvalidIndirectObject(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("generation"), true)
    }
    _ => fail("expected invalid generation number")
  }
}
