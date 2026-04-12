///|
test "integer and number accessors preserve PDF numeric rules" {
  inspect(@objects.PdfObject::Integer(17L).as_integer(offset=4L), content="17")
  inspect(@objects.PdfObject::Integer(17L).as_number(offset=4L), content="17")
  inspect(@objects.PdfObject::Real(3.5).as_number(offset=5L), content="3.5")
  let real_as_integer : Result[Int64, @objects.PdfParseError] = try? @objects.PdfObject::Real(
    3.5,
  ).as_integer(offset=5L)
  match real_as_integer {
    Err(UnexpectedToken(offset, expected, actual)) => {
      assert_eq(offset, 5L)
      assert_eq(expected, "integer")
      assert_eq(actual, "real")
    }
    _ => fail("expected real to be rejected in integer context")
  }
}

///|
test "expectation helpers do not resolve indirect references" {
  let object_id = @objects.ObjectId::{ object_number: 12, generation_number: 0 }
  let ref_as_number : Result[Double, @objects.PdfParseError] = try? @objects.PdfObject::Ref(
    object_id,
  ).as_number(offset=9L)
  match ref_as_number {
    Err(UnexpectedToken(offset, expected, actual)) => {
      assert_eq(offset, 9L)
      assert_eq(expected, "number")
      assert_eq(actual, "ref")
    }
    _ => fail("expected indirect reference to remain unresolved")
  }
}

///|
test "dictionary lookup returns null for absent entries" {
  let key = @objects.PdfName::new(b"Length")
  let missing = @objects.PdfName::new(b"Missing")
  let dict : @objects.PdfDictionary = Map::new()
  dict[key] = @objects.PdfObject::Integer(42L)
  assert_eq(
    @objects.dictionary_get_or_null(dict, key) ==
    @objects.PdfObject::Integer(42L),
    true,
  )
  assert_eq(
    @objects.dictionary_get_or_null(dict, missing) == @objects.PdfObject::Null,
    true,
  )
  assert_eq(@objects.dictionary_get_or_null(dict, missing).is_null(), true)
}

///|
test "parse errors expose kind and byte offset" {
  let invalid = @objects.PdfParseError::InvalidNumber(23L, b"6.02E23")
  match invalid {
    InvalidNumber(offset, lexeme) => {
      assert_eq(offset, 23L)
      assert_eq(lexeme, b"6.02E23")
    }
    _ => fail("expected invalid number")
  }
  let duplicate = @objects.PdfParseError::InvalidDictionary(
    31L, "duplicate key",
  )
  match duplicate {
    InvalidDictionary(offset, reason) => {
      assert_eq(offset, 31L)
      assert_eq(reason, "duplicate key")
    }
    _ => fail("expected invalid dictionary")
  }
}
