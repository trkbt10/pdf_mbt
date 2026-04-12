///|
fn recursive_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn recursive_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> @objects.PdfObject raise {
  match dict.get(recursive_name(key)) {
    Some(value) => value
    None => fail("expected recursive dictionary entry")
  }
}

///|
fn recursive_ref(
  object_number : Int,
  generation_number : Int,
) -> @objects.PdfObject {
  @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number,
    generation_number,
  })
}

///|
test "parser recursively reads combined direct aggregate values" {
  let object = @parser.parse_object(
    b"<< /Bool true /Int 42 /Real 3.5 /String (Hi) /Name /SomeName /Array [1 [2 null] false] /Dict << /NestedName /Value /NestedArray [(inner) 7 0 R] >> /Null null /Ref 12 0 R >>",
  )
  match object {
    Dictionary(dict) => {
      assert_eq(recursive_entry(dict, b"Bool") == Boolean(true), true)
      assert_eq(recursive_entry(dict, b"Int") == Integer(42L), true)
      assert_eq(recursive_entry(dict, b"Real") == Real(3.5), true)
      assert_eq(recursive_entry(dict, b"String") == String(b"Hi"), true)
      assert_eq(
        recursive_entry(dict, b"Name") == Name(recursive_name(b"SomeName")),
        true,
      )
      assert_eq(
        recursive_entry(dict, b"Array") ==
        Array([Integer(1L), Array([Integer(2L), Null]), Boolean(false)]),
        true,
      )
      match recursive_entry(dict, b"Dict") {
        Dictionary(nested) => {
          assert_eq(
            recursive_entry(nested, b"NestedName") ==
            Name(recursive_name(b"Value")),
            true,
          )
          assert_eq(
            recursive_entry(nested, b"NestedArray") ==
            Array([String(b"inner"), recursive_ref(7, 0)]),
            true,
          )
        }
        _ => fail("expected nested dictionary")
      }
      assert_eq(dict.get(recursive_name(b"Null")) is None, true)
      assert_eq(recursive_entry(dict, b"Ref") == recursive_ref(12, 0), true)
    }
    _ => fail("expected dictionary")
  }
}

///|
test "parser leaves following objects available after nested aggregates" {
  let parser = @parser.ObjectParser::new(
    b"[<< /A [1 2 true] /B << /C (done) >> >>] /Tail 9",
  )
  let objects = parser.parse_all_objects()
  assert_eq(objects.length(), 3)
  match objects[0] {
    Array(values) => {
      assert_eq(values.length(), 1)
      match values[0] {
        Dictionary(dict) => {
          assert_eq(
            recursive_entry(dict, b"A") ==
            Array([Integer(1L), Integer(2L), Boolean(true)]),
            true,
          )
          match recursive_entry(dict, b"B") {
            Dictionary(nested) =>
              assert_eq(recursive_entry(nested, b"C") == String(b"done"), true)
            _ => fail("expected nested dictionary")
          }
        }
        _ => fail("expected dictionary array element")
      }
    }
    _ => fail("expected array object")
  }
  assert_eq(objects[1] == Name(recursive_name(b"Tail")), true)
  assert_eq(objects[2] == Integer(9L), true)
}

///|
test "parser preserves integer fallback tokens inside aggregate contexts" {
  let parser = @parser.ObjectParser::new(b"[1 2 true] << /A 1 /B 2 /C true >>")
  let objects = parser.parse_all_objects()
  assert_eq(objects.length(), 2)
  assert_eq(
    objects[0] == Array([Integer(1L), Integer(2L), Boolean(true)]),
    true,
  )
  match objects[1] {
    Dictionary(dict) => {
      assert_eq(recursive_entry(dict, b"A") == Integer(1L), true)
      assert_eq(recursive_entry(dict, b"B") == Integer(2L), true)
      assert_eq(recursive_entry(dict, b"C") == Boolean(true), true)
    }
    _ => fail("expected dictionary")
  }
}
