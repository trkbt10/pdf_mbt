///|
fn parse_dict(
  input : Bytes,
) -> @objects.PdfDictionary raise @objects.PdfParseError {
  @parser.parse_object(input).as_dictionary(offset=0L)
}

///|
fn expect_integer_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
  value : Int64,
) -> Unit raise {
  match dict.get(@objects.PdfName::new(key)) {
    Some(Integer(actual)) => assert_eq(actual, value)
    _ => fail("expected integer dictionary entry")
  }
}

///|
fn expect_name_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
  value : Bytes,
) -> Unit raise {
  match dict.get(@objects.PdfName::new(key)) {
    Some(Name(actual)) =>
      assert_eq(actual == @objects.PdfName::new(value), true)
    _ => fail("expected name dictionary entry")
  }
}

///|
fn expect_missing_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> Unit raise {
  match dict.get(@objects.PdfName::new(key)) {
    None => ()
    _ => fail("expected missing dictionary entry")
  }
}

///|
fn expect_invalid_dictionary(input : Bytes) -> Unit raise {
  let result : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    input,
  )
  match result {
    Err(InvalidDictionary(_, _)) => ()
    _ => fail("expected invalid dictionary error")
  }
}

///|
test "parser reads empty and nested dictionaries" {
  let empty = parse_dict(b"<<>>")
  expect_missing_entry(empty, b"Any")
  let dict = parse_dict(
    b"<< /Type /Catalog /Count 1 /Nested << /Flag true >> >>",
  )
  expect_name_entry(dict, b"Type", b"Catalog")
  expect_integer_entry(dict, b"Count", 1L)
  match dict.get(@objects.PdfName::new(b"Nested")) {
    Some(Dictionary(nested)) =>
      match nested.get(@objects.PdfName::new(b"Flag")) {
        Some(Boolean(value)) => assert_eq(value, true)
        _ => fail("expected nested boolean entry")
      }
    _ => fail("expected nested dictionary entry")
  }
}

///|
test "parser omits null dictionary values from final map" {
  let dict = parse_dict(b"<< /Present 1 /Missing null >>")
  expect_integer_entry(dict, b"Present", 1L)
  expect_missing_entry(dict, b"Missing")
  assert_eq(
    @objects.dictionary_get_or_null(dict, @objects.PdfName::new(b"Missing")) ==
    @objects.PdfObject::Null,
    true,
  )
}

///|
test "parser rejects duplicate dictionary keys including null entries" {
  expect_invalid_dictionary(b"<< /A 1 /A 2 >>")
  expect_invalid_dictionary(b"<< /A null /A 1 >>")
  expect_invalid_dictionary(b"<< /A 1 /A null >>")
}

///|
test "parser rejects non-name dictionary keys" {
  expect_invalid_dictionary(b"<< 1 /Value >>")
}

///|
test "parser distinguishes dictionaries from hexadecimal strings" {
  assert_eq(
    @parser.parse_object(b"<41>") == @objects.PdfObject::String(b"A"),
    true,
  )
  match @parser.parse_object(b"<<>>") {
    Dictionary(dict) => expect_missing_entry(dict, b"Any")
    _ => fail("expected dictionary object")
  }
}
