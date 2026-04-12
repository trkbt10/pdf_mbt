///|
fn iso_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
test "parser follows ISO comment separation and scalar fragments" {
  let objects = @parser.parse_all_objects(
    b"true%comment (/%) blah\n123 34.5 -98 null",
  )
  assert_eq(objects.length(), 5)
  assert_eq(objects[0] == @objects.PdfObject::Boolean(true), true)
  assert_eq(objects[1] == @objects.PdfObject::Integer(123L), true)
  assert_eq(objects[2] == @objects.PdfObject::Real(34.5), true)
  assert_eq(objects[3] == @objects.PdfObject::Integer(-98L), true)
  assert_eq(objects[4] == @objects.PdfObject::Null, true)
}

///|
test "parser reads ISO numeric fragments and preserves integer fallback" {
  let objects = @parser.parse_all_objects(b"43445 +17 +123.6 4. -.002 0")
  assert_eq(objects.length(), 6)
  assert_eq(objects[0] == @objects.PdfObject::Integer(43445L), true)
  assert_eq(objects[1] == @objects.PdfObject::Integer(17L), true)
  assert_eq(objects[2] == @objects.PdfObject::Real(123.6), true)
  assert_eq(objects[3] == @objects.PdfObject::Real(4.0), true)
  assert_eq(objects[4] == @objects.PdfObject::Real(-0.002), true)
  assert_eq(objects[5] == @objects.PdfObject::Integer(0L), true)
}

///|
test "parser reads ISO literal and hexadecimal string examples" {
  assert_eq(
    @parser.parse_object(b"(This is a string)") ==
    @objects.PdfObject::String(b"This is a string"),
    true,
  )
  assert_eq(
    @parser.parse_object(b"()") == @objects.PdfObject::String(b""),
    true,
  )
  assert_eq(
    @parser.parse_object(b"<4E6F762073686D6F7A206B6120706F702E>") ==
    @objects.PdfObject::String(b"Nov shmoz ka pop."),
    true,
  )
  assert_eq(
    @parser.parse_object(b"<901FA3>") ==
    @objects.PdfObject::String(Bytes::from_array([b'\x90', b'\x1f', b'\xa3'])),
    true,
  )
  assert_eq(
    @parser.parse_object(b"<901FA>") ==
    @objects.PdfObject::String(Bytes::from_array([b'\x90', b'\x1f', b'\xa0'])),
    true,
  )
}

///|
test "parser reads ISO name examples" {
  assert_eq(
    @parser.parse_object(b"/Name1") ==
    @objects.PdfObject::Name(iso_name(b"Name1")),
    true,
  )
  assert_eq(
    @parser.parse_object(b"/Lime#20Green") ==
    @objects.PdfObject::Name(iso_name(b"Lime Green")),
    true,
  )
  assert_eq(
    @parser.parse_object(b"/paired#28#29parentheses") ==
    @objects.PdfObject::Name(iso_name(b"paired()parentheses")),
    true,
  )
  assert_eq(
    @parser.parse_object(b"/The_Key_of_F#23_Minor") ==
    @objects.PdfObject::Name(iso_name(b"The_Key_of_F#_Minor")),
    true,
  )
  assert_eq(
    @parser.parse_object(b"/A#42") == @objects.PdfObject::Name(iso_name(b"AB")),
    true,
  )
}

///|
test "parser reads ISO array and dictionary examples" {
  assert_eq(
    @parser.parse_object(b"[549 3.14 false (Ralph) /SomeName]") ==
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(549L),
      @objects.PdfObject::Real(3.14),
      @objects.PdfObject::Boolean(false),
      @objects.PdfObject::String(b"Ralph"),
      @objects.PdfObject::Name(iso_name(b"SomeName")),
    ]),
    true,
  )

  let object = @parser.parse_object(
    b"<< /Type /Example /Subtype /DictionaryExample /Version 0.01 /IntegerItem 12 /StringItem (a string) /Subdictionary << /Item1 0.4 /Item2 true /LastItem (not !) /VeryLastItem (OK) >> >>",
  )
  match object {
    Dictionary(dict) => {
      assert_eq(
        dict.get(iso_name(b"Type")) ==
        Some(@objects.PdfObject::Name(iso_name(b"Example"))),
        true,
      )
      assert_eq(
        dict.get(iso_name(b"Subtype")) ==
        Some(@objects.PdfObject::Name(iso_name(b"DictionaryExample"))),
        true,
      )
      assert_eq(
        dict.get(iso_name(b"Version")) == Some(@objects.PdfObject::Real(0.01)),
        true,
      )
      assert_eq(
        dict.get(iso_name(b"IntegerItem")) ==
        Some(@objects.PdfObject::Integer(12L)),
        true,
      )
      assert_eq(
        dict.get(iso_name(b"StringItem")) ==
        Some(@objects.PdfObject::String(b"a string")),
        true,
      )
      match dict.get(iso_name(b"Subdictionary")) {
        Some(Dictionary(nested)) => {
          assert_eq(
            nested.get(iso_name(b"Item1")) ==
            Some(@objects.PdfObject::Real(0.4)),
            true,
          )
          assert_eq(
            nested.get(iso_name(b"Item2")) ==
            Some(@objects.PdfObject::Boolean(true)),
            true,
          )
          assert_eq(
            nested.get(iso_name(b"LastItem")) ==
            Some(@objects.PdfObject::String(b"not !")),
            true,
          )
          assert_eq(
            nested.get(iso_name(b"VeryLastItem")) ==
            Some(@objects.PdfObject::String(b"OK")),
            true,
          )
        }
        _ => fail("expected nested dictionary")
      }
    }
    _ => fail("expected dictionary")
  }
}

///|
test "parser reads ISO indirect object and stream fragments" {
  let indirect = @parser.parse_indirect_object(b"12 0 obj (Brillig) endobj")
  assert_eq(
    indirect.id ==
    @objects.ObjectId::{ object_number: 12, generation_number: 0 },
    true,
  )
  match indirect.value {
    String(value) => assert_eq(value, b"Brillig")
    _ => fail("expected indirect string object")
  }

  let stream_object = @parser.parse_indirect_object(
    b"13 0 obj << /Length 4 >> stream\nDATA\nendstream endobj",
  )
  match stream_object.value {
    Stream(stream) => {
      assert_eq(stream.data, b"DATA")
      assert_eq(
        stream.dict.get(iso_name(b"Length")) ==
        Some(@objects.PdfObject::Integer(4L)),
        true,
      )
    }
    _ => fail("expected stream object")
  }
}

///|
test "parser reads ISO indirect references and preserves integer fallback" {
  assert_eq(
    @parser.parse_object(b"12 0 R") ==
    @objects.PdfObject::Ref(@objects.ObjectId::{
      object_number: 12,
      generation_number: 0,
    }),
    true,
  )
  let objects = @parser.parse_all_objects(b"1 2 true")
  assert_eq(
    objects ==
    [
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::Boolean(true),
    ],
    true,
  )
}
