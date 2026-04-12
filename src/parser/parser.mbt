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
  if self.lexer.has_pushed_tokens() {
    return self.parse_ordinary_object()
  }
  self.lexer.skip_separators()
  match self.cursor.peek() {
    Some(b'(') =>
      @objects.PdfObject::String(@lexer.read_literal_string(self.cursor))
    Some(b'<') if self.cursor.peek_n(1) == Some(b'<') =>
      @objects.PdfObject::Dictionary(self.parse_dictionary())
    Some(b'<') if self.cursor.peek_n(1) != Some(b'<') =>
      @objects.PdfObject::String(@lexer.read_hex_string(self.cursor))
    Some(b'/') => @objects.PdfObject::Name(@lexer.read_name(self.cursor))
    Some(b'[') => @objects.PdfObject::Array(self.parse_array())
    _ => self.parse_ordinary_object()
  }
}

///|
fn ObjectParser::parse_ordinary_object(
  self : ObjectParser,
) -> @objects.PdfObject raise @objects.PdfParseError {
  match self.lexer.next_token() {
    Regular(lexeme, offset) =>
      if is_integer_lexeme(lexeme) {
        self.parse_integer_or_reference(lexeme, offset)
      } else {
        parse_regular_object(lexeme, offset)
      }
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
    let result : Result[@objects.PdfObject, @objects.PdfParseError] = try? self.parse_object()
    match result {
      Ok(object) => objects.push(object)
      Err(UnexpectedEof(_, context)) if context == "object" => break
      Err(error) => raise error
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
fn ObjectParser::parse_array(
  self : ObjectParser,
) -> Array[@objects.PdfObject] raise @objects.PdfParseError {
  let offset = self.cursor.offset()
  match self.cursor.read_byte() {
    Some(b'[') => ()
    Some(byte) =>
      raise @objects.PdfParseError::UnexpectedToken(
        offset,
        "[",
        String::from_array([byte.to_char()]),
      )
    None => raise @objects.PdfParseError::UnexpectedEof(offset, "array")
  }
  let values : Array[@objects.PdfObject] = []
  while true {
    if self.lexer.has_pushed_tokens() {
      values.push(self.parse_object())
      continue
    }
    self.lexer.skip_separators()
    match self.cursor.peek() {
      Some(b']') => {
        self.cursor.read_byte() |> ignore
        break
      }
      None =>
        raise @objects.PdfParseError::UnexpectedEof(
          self.cursor.offset(),
          "array",
        )
      _ => values.push(self.parse_object())
    }
  }
  values
}

///|
fn ObjectParser::parse_integer_or_reference(
  self : ObjectParser,
  first_lexeme : Bytes,
  first_offset : Int64,
) -> @objects.PdfObject raise @objects.PdfParseError {
  let first = parse_int64_lexeme(first_lexeme, first_offset)
  if !self.next_token_can_be_regular() {
    return @objects.PdfObject::Integer(first)
  }
  let second_token = self.lexer.next_token()
  match second_token {
    Regular(second_lexeme, _) if is_integer_lexeme(second_lexeme) => {
      if !self.next_token_can_be_regular() {
        self.lexer.push_back(second_token)
        return @objects.PdfObject::Integer(first)
      }
      let third_token = self.lexer.next_token()
      match third_token {
        Regular(b"R", _) =>
          build_ref_object(
            first,
            parse_int64_lexeme(second_lexeme, token_offset(second_token)),
            first_offset,
          )
        _ => {
          self.lexer.push_back(third_token)
          self.lexer.push_back(second_token)
          @objects.PdfObject::Integer(first)
        }
      }
    }
    _ => {
      self.lexer.push_back(second_token)
      @objects.PdfObject::Integer(first)
    }
  }
}

///|
fn ObjectParser::next_token_can_be_regular(
  self : ObjectParser,
) -> Bool raise @objects.PdfParseError {
  self.lexer.skip_separators()
  match self.cursor.peek() {
    Some(byte) => !@lexer.is_white_space(byte) && !@lexer.is_delimiter(byte)
    None => false
  }
}

///|
fn build_ref_object(
  object_number : Int64,
  generation_number : Int64,
  offset : Int64,
) -> @objects.PdfObject raise @objects.PdfParseError {
  if object_number <= 0L {
    raise @objects.PdfParseError::InvalidIndirectObject(
      offset, "object number must be positive",
    )
  }
  if generation_number < 0L {
    raise @objects.PdfParseError::InvalidIndirectObject(
      offset, "generation number must be non-negative",
    )
  }
  @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: object_number.to_int(),
    generation_number: generation_number.to_int(),
  })
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
