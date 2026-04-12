///|
test "pdf name uses byte equality and explicit text conversion" {
  let a = @objects.PdfName::new(b"Name")
  let b = @objects.PdfName::new(b"\x4e\x61\x6d\x65")
  let c = @objects.PdfName::new(b"name")
  assert_eq(a == b, true)
  assert_eq(a == c, false)
  inspect(a.to_text(), content="Name")
  inspect(
    @objects.PdfName::new(b"\xe4\xbd\xa0\xe5\xa5\xbd").to_text(),
    content="你好",
  )
}

///|
test "pdf object variants are constructible and matchable" {
  let name = @objects.PdfName::new(b"SomeName")
  let object_id = @objects.ObjectId::{ object_number: 12, generation_number: 0 }
  let dict : @objects.PdfDictionary = Map::new()
  dict[name] = @objects.PdfObject::Integer(549L)
  let stream = @objects.PdfStream::{ dict, data: b"raw bytes" }
  let values : Array[@objects.PdfObject] = [
    @objects.PdfObject::Boolean(true),
    @objects.PdfObject::Integer(43445L),
    @objects.PdfObject::Real(3.14),
    @objects.PdfObject::String(b"Ralph"),
    @objects.PdfObject::Name(name),
    @objects.PdfObject::Array([
      @objects.PdfObject::Boolean(false),
      @objects.PdfObject::Null,
    ]),
    @objects.PdfObject::Dictionary(dict),
    @objects.PdfObject::Stream(stream),
    @objects.PdfObject::Null,
    @objects.PdfObject::Ref(object_id),
  ]
  match values[0] {
    Boolean(value) => assert_eq(value, true)
    _ => fail("expected Boolean")
  }
  match values[4] {
    Name(value) => assert_eq(value == name, true)
    _ => fail("expected Name")
  }
  match values[7] {
    Stream(value) => {
      assert_eq(value.data, b"raw bytes")
      assert_eq(
        value.dict.get(name) == Some(@objects.PdfObject::Integer(549L)),
        true,
      )
    }
    _ => fail("expected Stream")
  }
  match values[9] {
    Ref(value) => assert_eq(value == object_id, true)
    _ => fail("expected Ref")
  }
}

///|
test "indirect object preserves object identity and offsets" {
  let id = @objects.ObjectId::{ object_number: 12, generation_number: 0 }
  let indirect = @objects.IndirectObject::{
    id,
    value: @objects.PdfObject::String(b"Brillig"),
    start_offset: 3L,
    end_offset: 27L,
  }
  assert_eq(indirect.id == id, true)
  match indirect.value {
    String(bytes) => assert_eq(bytes, b"Brillig")
    _ => fail("expected string object")
  }
  assert_eq(indirect.start_offset, 3L)
  assert_eq(indirect.end_offset, 27L)
}
