///|
/// Result of reading the next decoded content token.
pub(all) enum OperandReadResult {
  Operand(@objects.PdfObject)
  OperatorCandidate(Bytes, Int64)
  EndOfInput(Int64)
} derive(Eq, Debug)

///|
/// Reads direct operands from decoded content bytes without performing
/// indirect-reference lookahead.
pub(all) struct ContentOperandReader {
  cursor : @lexer.ByteCursor
  lexer : @lexer.Lexer
}

///|
/// Creates a reader over already-decoded content bytes.
pub fn ContentOperandReader::new(input : Bytes) -> ContentOperandReader {
  let cursor = @lexer.ByteCursor::new(input)
  ContentOperandReader::{ cursor, lexer: @lexer.Lexer::new(cursor) }
}

///|
/// Reads the next direct operand or operator candidate from the content
/// stream. Regular keywords that are not direct operands remain candidates.
pub fn ContentOperandReader::read_next(
  self : ContentOperandReader,
) -> OperandReadResult raise PdfContentError {
  self.read_value(true)
}

///|
fn ContentOperandReader::read_direct_operand(
  self : ContentOperandReader,
) -> @objects.PdfObject raise PdfContentError {
  match self.read_value(false) {
    Operand(object) => object
    OperatorCandidate(_, offset) =>
      raise IllegalOperand(offset, "operator keyword in operand position")
    EndOfInput(offset) =>
      raise MalformedSyntax(offset, "unterminated operand")
  }
}

///|
fn ContentOperandReader::read_value(
  self : ContentOperandReader,
  allow_operator_candidate : Bool,
) -> OperandReadResult raise PdfContentError {
  self.skip_separators()
  let offset = self.cursor.offset()
  match self.cursor.peek() {
    None => EndOfInput(offset)
    Some(b'(') => {
      let bytes = @lexer.read_literal_string(self.cursor) catch {
        error => raise wrap_parse_error(error)
      }
      Operand(@objects.PdfObject::String(bytes))
    }
    Some(b'<') if self.cursor.peek_n(1) == Some(b'<') => {
      Operand(@objects.PdfObject::Dictionary(self.read_dictionary()))
    }
    Some(b'<') => {
      let bytes = @lexer.read_hex_string(self.cursor) catch {
        error => raise wrap_parse_error(error)
      }
      Operand(@objects.PdfObject::String(bytes))
    }
    Some(b'/') => {
      let name = @lexer.read_name(self.cursor) catch {
        error => raise wrap_parse_error(error)
      }
      Operand(@objects.PdfObject::Name(name))
    }
    Some(b'[') => Operand(@objects.PdfObject::Array(self.read_array()))
    Some(byte) if @lexer.is_delimiter(byte) =>
      raise MalformedSyntax(offset, "unexpected delimiter")
    Some(_) => {
      let token = self.next_token()
      match token {
        Regular(lexeme, token_offset) =>
          self.classify_regular_token(
            lexeme,
            token_offset,
            allow_operator_candidate,
          )
        Delimiter(_, token_offset) =>
          raise MalformedSyntax(token_offset, "unexpected delimiter")
        DictStart(token_offset) => {
          Operand(@objects.PdfObject::Dictionary(self.read_dictionary_body(
            token_offset,
          )))
        }
        DictEnd(token_offset) =>
          raise MalformedSyntax(token_offset, "unexpected dictionary end")
        HeaderMarker(_, _, token_offset) =>
          raise MalformedSyntax(token_offset, "unexpected PDF header marker")
        EofMarker(token_offset) =>
          raise MalformedSyntax(token_offset, "unexpected EOF marker")
        EndOfInput(token_offset) => EndOfInput(token_offset)
      }
    }
  }
}

///|
fn ContentOperandReader::classify_regular_token(
  _self : ContentOperandReader,
  lexeme : Bytes,
  offset : Int64,
  allow_operator_candidate : Bool,
) -> OperandReadResult raise PdfContentError {
  match lexeme {
    b"true" => Operand(@objects.PdfObject::Boolean(true))
    b"false" => Operand(@objects.PdfObject::Boolean(false))
    b"null" => Operand(@objects.PdfObject::Null)
    _ =>
      if is_integer_lexeme(lexeme) {
        Operand(@objects.PdfObject::Integer(parse_int64_lexeme(lexeme, offset)))
      } else if is_real_lexeme(lexeme) {
        Operand(@objects.PdfObject::Real(parse_double_lexeme(lexeme, offset)))
      } else if is_numeric_like(lexeme) {
        raise MalformedSyntax(offset, "invalid number")
      } else if is_stream_like_keyword(lexeme) {
        raise IllegalOperand(offset, "illegal stream-like construct")
      } else if allow_operator_candidate {
        OperatorCandidate(lexeme, offset)
      } else {
        raise IllegalOperand(offset, "illegal operand keyword")
      }
  }
}

///|
fn ContentOperandReader::read_array(
  self : ContentOperandReader,
) -> Array[@objects.PdfObject] raise PdfContentError {
  self.consume_array_start()
  let values : Array[@objects.PdfObject] = []
  while true {
    self.skip_separators()
    let offset = self.cursor.offset()
    match self.cursor.peek() {
      Some(b']') => {
        self.read_byte() |> ignore
        break
      }
      None =>
        raise MalformedSyntax(offset, "unterminated array")
      _ => values.push(self.read_direct_operand())
    }
  }
  values
}

///|
fn ContentOperandReader::read_dictionary(
  self : ContentOperandReader,
) -> @objects.PdfDictionary raise PdfContentError {
  self.consume_dictionary_start()
  self.read_dictionary_body(0L)
}

///|
fn ContentOperandReader::read_dictionary_body(
  self : ContentOperandReader,
  _offset : Int64,
) -> @objects.PdfDictionary raise PdfContentError {
  let dict : @objects.PdfDictionary = Map::new()
  let seen : Map[@objects.PdfName, Bool] = Map::new()
  while true {
    self.skip_separators()
    let offset = self.cursor.offset()
    match self.cursor.peek() {
      Some(b'>') if self.cursor.peek_n(1) == Some(b'>') => {
        self.consume_dictionary_end()
        break
      }
      None =>
        raise MalformedSyntax(offset, "unterminated dictionary")
      _ => ()
    }

    let key_offset = self.cursor.offset()
    let key = match self.read_direct_operand() {
      Name(name) => name
      _ =>
        raise MalformedSyntax(
          key_offset,
          "dictionary key must be a name",
        )
    }
    if seen.get(key) is Some(_) {
      raise MalformedSyntax(key_offset, "duplicate dictionary key")
    }
    seen[key] = true

    self.skip_separators()
    let value_offset = self.cursor.offset()
    match self.cursor.peek() {
      Some(b'>') if self.cursor.peek_n(1) == Some(b'>') =>
        raise MalformedSyntax(value_offset, "dictionary key is missing a value")
      None =>
        raise MalformedSyntax(value_offset, "unterminated dictionary")
      _ => ()
    }

    let value = self.read_direct_operand()
    if !value.is_null() {
      dict[key] = value
    }
  }
  dict
}

///|
fn ContentOperandReader::consume_array_start(
  self : ContentOperandReader,
) -> Unit raise PdfContentError {
  let offset = self.cursor.offset()
  match self.read_byte() {
    Some(b'[') => ()
    Some(byte) =>
      raise MalformedSyntax(
        offset,
        "array must start with [ but found " + byte_to_text(byte),
      )
    None => raise MalformedSyntax(offset, "unterminated array")
  }
}

///|
fn ContentOperandReader::consume_dictionary_start(
  self : ContentOperandReader,
) -> Unit raise PdfContentError {
  let offset = self.cursor.offset()
  if self.cursor.peek() == Some(b'<') && self.cursor.peek_n(1) == Some(b'<') {
    self.read_byte() |> ignore
    self.read_byte() |> ignore
  } else {
    raise MalformedSyntax(offset, "dictionary must start with <<")
  }
}

///|
fn ContentOperandReader::consume_dictionary_end(
  self : ContentOperandReader,
) -> Unit raise PdfContentError {
  let offset = self.cursor.offset()
  if self.cursor.peek() == Some(b'>') && self.cursor.peek_n(1) == Some(b'>') {
    self.read_byte() |> ignore
    self.read_byte() |> ignore
  } else {
    raise MalformedSyntax(offset, "unterminated dictionary")
  }
}

///|
fn ContentOperandReader::skip_separators(
  self : ContentOperandReader,
) -> Unit raise PdfContentError {
  try self.lexer.skip_separators() catch {
    error => raise wrap_parse_error(error)
  } noraise {
    _ => ()
  }
}

///|
fn ContentOperandReader::next_token(
  self : ContentOperandReader,
) -> @lexer.PdfToken raise PdfContentError {
  try self.lexer.next_token() catch {
    error => raise wrap_parse_error(error)
  } noraise {
    token => token
  }
}

///|
fn ContentOperandReader::read_byte(
  self : ContentOperandReader,
) -> Byte? raise PdfContentError {
  try self.cursor.read_byte() catch {
    error => raise wrap_parse_error(error)
  } noraise {
    byte => byte
  }
}

///|
fn wrap_parse_error(error : @objects.PdfParseError) -> PdfContentError {
  ParseError(parse_error_offset(error), error)
}

///|
fn parse_error_offset(error : @objects.PdfParseError) -> Int64 {
  match error {
    UnexpectedToken(offset, _, _)
    | UnexpectedEof(offset, _)
    | InvalidNumber(offset, _)
    | NumericOverflow(offset, _)
    | InvalidName(offset, _)
    | InvalidDictionary(offset, _)
    | InvalidStream(offset, _)
    | InvalidIndirectObject(offset, _) => offset
  }
}

///|
fn is_stream_like_keyword(lexeme : Bytes) -> Bool {
  match lexeme {
    b"obj" | b"endobj" | b"stream" | b"endstream" | b"xref" | b"trailer" |
    b"startxref" => true
    _ => false
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
fn parse_int64_lexeme(lexeme : Bytes, offset : Int64) -> Int64 raise PdfContentError {
  @string.parse_int64(bytes_to_text(lexeme).to_string_view()) catch {
    _ => raise MalformedSyntax(offset, "invalid number")
  }
}

///|
fn parse_double_lexeme(
  lexeme : Bytes,
  offset : Int64,
) -> Double raise PdfContentError {
  @string.parse_double(bytes_to_text(lexeme).to_string_view()) catch {
    _ => raise MalformedSyntax(offset, "invalid number")
  }
}

///|
fn byte_to_text(byte : Byte) -> String {
  String::from_array([byte.to_char()])
}

///|
fn bytes_to_text(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(byte.to_char())
  }
  String::from_array(chars)
}
