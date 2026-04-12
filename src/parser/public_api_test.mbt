///|
test "parser exposes package-level fragment parsing and public object values" {
  let objects = @parser.parse_all_objects(b"null 12 0 R << /A 1 /B null >>")
  assert_eq(objects.length(), 3)
  assert_eq(objects[0] == @objects.PdfObject::Null, true)
  assert_eq(
    objects[1] ==
    @objects.PdfObject::Ref(@objects.ObjectId::{
      object_number: 12,
      generation_number: 0,
    }),
    true,
  )
  match objects[2] {
    Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"A")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
      assert_eq(dict.get(@objects.PdfName::new(b"B")) is None, true)
    }
    _ => fail("expected dictionary object")
  }
}

///|
test "parser exposes package-level single-object and indirect-object parsing" {
  assert_eq(
    @parser.parse_object(b"false") == @objects.PdfObject::Boolean(false),
    true,
  )
  let indirect = @parser.parse_indirect_object(b"7 0 obj (hi) endobj")
  assert_eq(
    indirect.id == @objects.ObjectId::{ object_number: 7, generation_number: 0 },
    true,
  )
  match indirect.value {
    String(value) => assert_eq(value, b"hi")
    _ => fail("expected string indirect object")
  }

  let stream_object = @parser.parse_indirect_object(
    b"8 0 obj << /Length 0 >> stream\r\nendstream endobj",
  )
  match stream_object.value {
    Stream(stream) => {
      assert_eq(stream.data, b"")
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Length")) ==
        Some(@objects.PdfObject::Integer(0L)),
        true,
      )
    }
    _ => fail("expected stream indirect object")
  }
}
