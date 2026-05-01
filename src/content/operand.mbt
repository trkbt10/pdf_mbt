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
  // Pending lexeme produced by splitting a producer-quirk lexeme such as
  // `0.00-50` (two numbers run together). When set, `read_value` consumes
  // it before reaching for the underlying tokenizer so the caller observes
  // the same "two numeric operands" sequence a conforming producer would
  // have written. Cleared as soon as it is read.
  mut pending : (Bytes, Int64)?
}

///|
/// Creates a reader over already-decoded content bytes.
pub fn ContentOperandReader::new(input : Bytes) -> ContentOperandReader {
  let cursor = @lexer.ByteCursor::new(input)
  ContentOperandReader::{ cursor, lexer: @lexer.Lexer::new(cursor), pending: None }
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
    EndOfInput(offset) => raise MalformedSyntax(offset, "unterminated operand")
  }
}

///|
fn ContentOperandReader::read_value(
  self : ContentOperandReader,
  allow_operator_candidate : Bool,
) -> OperandReadResult raise PdfContentError {
  // Drain the split-number queue first. See `pending` doc on the struct.
  match self.pending {
    Some((lexeme, lexeme_offset)) => {
      self.pending = None
      return self.classify_regular_token(
        lexeme, lexeme_offset, allow_operator_candidate,
      )
    }
    None => ()
  }
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
    Some(b'<') if self.cursor.peek_n(1) == Some(b'<') =>
      Operand(@objects.PdfObject::Dictionary(self.read_dictionary()))
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
            lexeme, token_offset, allow_operator_candidate,
          )
        Delimiter(_, token_offset) =>
          raise MalformedSyntax(token_offset, "unexpected delimiter")
        DictStart(token_offset) =>
          Operand(
            @objects.PdfObject::Dictionary(
              self.read_dictionary_body(token_offset),
            ),
          )
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
  self : ContentOperandReader,
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
        // Producer-quirk recovery: some PDF generators (Marp, certain
        // PowerPoint exports, etc.) emit two numbers run together when the
        // second is signed, e.g. `0.00-50` instead of `0.00 -50`. ISO 32000
        // §7.2.3 requires a delimiter between operands, so the strict
        // tokenizer rejects this as a single malformed number. PDFium,
        // pdftoppm and most other processors silently split at the
        // internal sign byte. We do the same when the split yields two
        // strictly conforming numeric lexemes; otherwise we still raise so
        // genuinely garbled input stays caught.
        match split_concatenated_numeric(lexeme) {
          Some((first, second_offset_in_lexeme)) => {
            let first_bytes = bytes_slice(lexeme, 0, first)
            let rest_bytes = bytes_slice(
              lexeme, first, lexeme.length() - first,
            )
            self.pending = Some(
              (rest_bytes, offset + second_offset_in_lexeme.to_int64()),
            )
            self.classify_regular_token(
              first_bytes, offset, allow_operator_candidate,
            )
          }
          None => raise MalformedSyntax(offset, "invalid number")
        }
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
/// Detects a lexeme that looks like two conformant numbers concatenated
/// without a separator (`0.00-50`, `1+2`, `.5-.7`, etc.), and returns the
/// length of the first numeric segment plus the offset of the second
/// segment relative to the lexeme start. Returns None when no split
/// produces two valid numeric tokens, leaving the caller to raise the
/// usual "invalid number" syntax error.
fn split_concatenated_numeric(lexeme : Bytes) -> (Int, Int)? {
  // The split point is the first +/- byte at index >= 1 (index 0 is the
  // optional sign of the first number). After the split, both halves must
  // independently parse as integer or real to count as a recovery; we do
  // not invent fragments.
  let mut split_at = 1
  while split_at < lexeme.length() {
    let byte = lexeme[split_at]
    if byte == b'+' || byte == b'-' {
      let first = bytes_slice(lexeme, 0, split_at)
      let rest = bytes_slice(lexeme, split_at, lexeme.length() - split_at)
      let first_ok = is_integer_lexeme(first) || is_real_lexeme(first)
      let rest_ok = is_integer_lexeme(rest) || is_real_lexeme(rest)
      if first_ok && rest_ok {
        return Some((split_at, split_at))
      }
    }
    split_at = split_at + 1
  }
  None
}

///|
fn bytes_slice(source : Bytes, start : Int, length : Int) -> Bytes {
  let buf = FixedArray::make(length, b'\x00')
  for i in 0..<length {
    buf[i] = source[start + i]
  }
  Bytes::from_fixedarray(buf)
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
      None => raise MalformedSyntax(offset, "unterminated array")
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
      None => raise MalformedSyntax(offset, "unterminated dictionary")
      _ => ()
    }

    let key_offset = self.cursor.offset()
    let key = match self.read_direct_operand() {
      Name(name) => name
      _ => raise MalformedSyntax(key_offset, "dictionary key must be a name")
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
      None => raise MalformedSyntax(value_offset, "unterminated dictionary")
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
    b"obj"
    | b"endobj"
    | b"stream"
    | b"endstream"
    | b"xref"
    | b"trailer"
    | b"startxref" => true
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
fn parse_int64_lexeme(
  lexeme : Bytes,
  offset : Int64,
) -> Int64 raise PdfContentError {
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
