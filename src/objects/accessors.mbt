///|
fn PdfObject::kind_name(self : PdfObject) -> String {
  match self {
    Boolean(_) => "boolean"
    Integer(_) => "integer"
    Real(_) => "real"
    String(_) => "string"
    Name(_) => "name"
    Array(_) => "array"
    Dictionary(_) => "dictionary"
    Stream(_) => "stream"
    Null => "null"
    Ref(_) => "ref"
  }
}

///|
fn expect_token_error(
  offset~ : Int64,
  expected~ : String,
  actual~ : PdfObject,
) -> PdfParseError {
  PdfParseError::UnexpectedToken(offset, expected, actual.kind_name())
}

///|
pub fn PdfObject::as_integer(
  self : PdfObject,
  offset~ : Int64,
) -> Int64 raise PdfParseError {
  match self {
    Integer(value) => value
    _ => raise expect_token_error(offset~, expected="integer", actual=self)
  }
}

///|
pub fn PdfObject::as_number(
  self : PdfObject,
  offset~ : Int64,
) -> Double raise PdfParseError {
  match self {
    Integer(value) => value.to_double()
    Real(value) => value
    _ => raise expect_token_error(offset~, expected="number", actual=self)
  }
}

///|
pub fn PdfObject::as_name(
  self : PdfObject,
  offset~ : Int64,
) -> PdfName raise PdfParseError {
  match self {
    Name(value) => value
    _ => raise expect_token_error(offset~, expected="name", actual=self)
  }
}

///|
pub fn PdfObject::as_dictionary(
  self : PdfObject,
  offset~ : Int64,
) -> PdfDictionary raise PdfParseError {
  match self {
    Dictionary(value) => value
    _ => raise expect_token_error(offset~, expected="dictionary", actual=self)
  }
}

///|
pub fn PdfObject::as_stream(
  self : PdfObject,
  offset~ : Int64,
) -> PdfStream raise PdfParseError {
  match self {
    Stream(value) => value
    _ => raise expect_token_error(offset~, expected="stream", actual=self)
  }
}

///|
pub fn PdfObject::as_ref(
  self : PdfObject,
  offset~ : Int64,
) -> ObjectId raise PdfParseError {
  match self {
    Ref(value) => value
    _ => raise expect_token_error(offset~, expected="ref", actual=self)
  }
}

///|
pub fn PdfObject::is_null(self : PdfObject) -> Bool {
  match self {
    Null => true
    _ => false
  }
}

///|
pub fn dictionary_get_or_null(dict : PdfDictionary, key : PdfName) -> PdfObject {
  match dict.get(key) {
    Some(value) => value
    None => PdfObject::Null
  }
}
