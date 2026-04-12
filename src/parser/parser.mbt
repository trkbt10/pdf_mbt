///|
struct ObjectParser {
  cursor : @lexer.ByteCursor
  lexer : @lexer.Lexer
}

///|
pub fn ObjectParser::new(input : Bytes) -> ObjectParser {
  let cursor = @lexer.ByteCursor::new(input)
  ObjectParser::{ cursor, lexer: @lexer.Lexer::new(cursor) }
}

///|
pub fn ObjectParser::parse_object(
  self : ObjectParser,
) -> @objects.PdfObject raise @objects.PdfParseError {
  self.lexer.skip_separators()
  match self.cursor.peek() {
    Some(b'(') =>
      @objects.PdfObject::String(@lexer.read_literal_string(self.cursor))
    Some(b'<') if self.cursor.peek_n(1) != Some(b'<') =>
      @objects.PdfObject::String(@lexer.read_hex_string(self.cursor))
    Some(b'/') => @objects.PdfObject::Name(@lexer.read_name(self.cursor))
    _ => self.parse_ordinary_object()
  }
}

///|
fn ObjectParser::parse_ordinary_object(
  self : ObjectParser,
) -> @objects.PdfObject raise @objects.PdfParseError {
  match self.lexer.next_token() {
    Regular(lexeme, offset) => parse_regular_object(lexeme, offset)
    EndOfInput(offset) =>
      raise @objects.PdfParseError::UnexpectedEof(offset, "object")
    token =>
      raise @objects.PdfParseError::UnexpectedToken(
        token_offset(token),
        "object",
        token_kind(token),
      )
  }
}

///|
pub fn ObjectParser::parse_all_objects(
  self : ObjectParser,
) -> Array[@objects.PdfObject] raise @objects.PdfParseError {
  let objects : Array[@objects.PdfObject] = []
  while true {
    self.lexer.skip_separators()
    match self.cursor.peek() {
      None => break
      _ => objects.push(self.parse_object())
    }
  }
  objects
}

///|
pub fn parse_object(
  input : Bytes,
) -> @objects.PdfObject raise @objects.PdfParseError {
  ObjectParser::new(input).parse_object()
}

///|
fn parse_regular_object(
  lexeme : Bytes,
  offset : Int64,
) -> @objects.PdfObject raise @objects.PdfParseError {
  match lexeme {
    b"true" => @objects.PdfObject::Boolean(true)
    b"false" => @objects.PdfObject::Boolean(false)
    b"null" => @objects.PdfObject::Null
    _ =>
      if is_integer_lexeme(lexeme) {
        @objects.PdfObject::Integer(parse_int64_lexeme(lexeme, offset))
      } else if is_real_lexeme(lexeme) {
        @objects.PdfObject::Real(parse_double_lexeme(lexeme, offset))
      } else if is_numeric_like(lexeme) {
        raise @objects.PdfParseError::InvalidNumber(offset, lexeme)
      } else {
        raise @objects.PdfParseError::UnexpectedToken(
          offset,
          "object",
          bytes_to_text(lexeme),
        )
      }
  }
}

///|
fn parse_int64_lexeme(
  lexeme : Bytes,
  offset : Int64,
) -> Int64 raise @objects.PdfParseError {
  @string.parse_int64(bytes_to_text(lexeme).to_string_view()) catch {
    _ => raise @objects.PdfParseError::NumericOverflow(offset, lexeme)
  }
}

///|
fn parse_double_lexeme(
  lexeme : Bytes,
  offset : Int64,
) -> Double raise @objects.PdfParseError {
  @string.parse_double(bytes_to_text(lexeme).to_string_view()) catch {
    _ => raise @objects.PdfParseError::InvalidNumber(offset, lexeme)
  }
}

///|
fn is_integer_lexeme(lexeme : Bytes) -> Bool {
  let start = sign_prefix_length(lexeme)
  start < lexeme.length() && all_digits_from(lexeme, start)
}

///|
fn is_real_lexeme(lexeme : Bytes) -> Bool {
  let start = sign_prefix_length(lexeme)
  let mut period_count = 0
  let mut digit_count = 0
  let mut valid = start < lexeme.length()
  for i in start..<lexeme.length() {
    let byte = lexeme[i]
    if byte == b'.' {
      period_count += 1
    } else if is_digit(byte) {
      digit_count += 1
    } else {
      valid = false
    }
  }
  valid && period_count == 1 && digit_count > 0
}

///|
fn is_numeric_like(lexeme : Bytes) -> Bool {
  if lexeme.length() == 0 {
    false
  } else {
    let first = lexeme[0]
    is_digit(first) || first == b'+' || first == b'-' || first == b'.'
  }
}

///|
fn sign_prefix_length(lexeme : Bytes) -> Int {
  if lexeme.length() > 0 && (lexeme[0] == b'+' || lexeme[0] == b'-') {
    1
  } else {
    0
  }
}

///|
fn all_digits_from(lexeme : Bytes, start : Int) -> Bool {
  let mut valid = true
  for i in start..<lexeme.length() {
    if !is_digit(lexeme[i]) {
      valid = false
    }
  }
  valid
}

///|
fn is_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
fn token_offset(token : @lexer.PdfToken) -> Int64 {
  match token {
    Regular(_, offset)
    | Delimiter(_, offset)
    | DictStart(offset)
    | DictEnd(offset)
    | HeaderMarker(_, _, offset)
    | EofMarker(offset)
    | EndOfInput(offset) => offset
  }
}

///|
fn token_kind(token : @lexer.PdfToken) -> String {
  match token {
    Regular(bytes, _) => bytes_to_text(bytes)
    Delimiter(byte, _) => String::from_array([byte.to_char()])
    DictStart(_) => "<<"
    DictEnd(_) => ">>"
    HeaderMarker(_, _, _) => "%PDF marker"
    EofMarker(_) => "%%EOF"
    EndOfInput(_) => "end of input"
  }
}

///|
fn bytes_to_text(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(byte.to_char())
  }
  String::from_array(chars)
}
