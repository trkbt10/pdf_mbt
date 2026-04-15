///|
/// Lexer state for ISO 32000-2 section 7.2 ordinary lexical scanning.
struct Lexer {
  cursor : ByteCursor
  pushed : Array[PdfToken]
}

///|
/// Creates a lexer over a byte cursor with a bounded push-back buffer.
pub fn Lexer::new(cursor : ByteCursor) -> Lexer {
  Lexer::{ cursor, pushed: [] }
}

///|
/// Pushes a token back so numeric lookahead can preserve fallback parsing.
pub fn Lexer::push_back(self : Lexer, token : PdfToken) -> Unit {
  self.pushed.push(token)
}

///|
/// Reports whether the parser has a token saved from lookahead.
pub fn Lexer::has_pushed_tokens(self : Lexer) -> Bool {
  self.pushed.length() > 0
}

///|
/// Reads and then restores the next token for parser lookahead.
pub fn Lexer::peek_token(self : Lexer) -> PdfToken raise @objects.PdfParseError {
  let token = self.next_token()
  self.push_back(token)
  token
}

///|
/// Returns the next PDF token after collapsing separators.
pub fn Lexer::next_token(self : Lexer) -> PdfToken raise @objects.PdfParseError {
  match self.pushed.pop() {
    Some(token) => token
    None => self.read_next_token()
  }
}

///|
/// Skips ISO 32000-2 section 7.2.3 separators: consecutive white-space,
/// EOL marker forms, and ordinary comments. A delimiter terminates a regular
/// token, so this stops before delimiters.
pub fn Lexer::skip_separators(
  self : Lexer,
) -> Unit raise @objects.PdfParseError {
  while true {
    match self.cursor.peek() {
      Some(byte) if is_white_space(byte) => {
        self.consume_white_space()
        continue
      }
      Some(b'%') if !self.is_header_marker() && !self.is_eof_marker() => {
        self.skip_comment()
        continue
      }
      _ => break
    }
  }
}

///|
/// Reads the next ordinary token or delimiter outside strings and streams.
fn Lexer::read_next_token(
  self : Lexer,
) -> PdfToken raise @objects.PdfParseError {
  self.skip_separators()
  let offset = self.cursor.offset()
  match self.cursor.peek() {
    None => PdfToken::EndOfInput(offset)
    Some(b'%') if self.is_header_marker() => self.read_header_marker(offset)
    Some(b'%') if self.is_eof_marker() => self.read_eof_marker(offset)
    Some(b'<') if self.cursor.peek_n(1) == Some(b'<') => {
      self.consume_bytes(2)
      PdfToken::DictStart(offset)
    }
    Some(b'>') if self.cursor.peek_n(1) == Some(b'>') => {
      self.consume_bytes(2)
      PdfToken::DictEnd(offset)
    }
    Some(byte) if is_delimiter(byte) => {
      self.consume_bytes(1)
      PdfToken::Delimiter(byte, offset)
    }
    Some(_) => self.read_regular_token(offset)
  }
}

///|
/// Reads a sequence of regular characters until white-space or delimiter.
/// ISO 32000-2 section 7.2.3 says a delimiter terminates the token without
/// being included in it.
fn Lexer::read_regular_token(
  self : Lexer,
  offset : Int64,
) -> PdfToken raise @objects.PdfParseError {
  let bytes : Array[Byte] = []
  while true {
    match self.cursor.peek() {
      Some(byte) if !is_white_space(byte) && !is_delimiter(byte) => {
        self.cursor.read_byte() |> ignore
        bytes.push(byte)
      }
      _ => break
    }
  }
  PdfToken::Regular(Bytes::from_array(bytes), offset)
}

///|
/// Consumes one white-space separator, normalizing an EOL marker first.
fn Lexer::consume_white_space(
  self : Lexer,
) -> Unit raise @objects.PdfParseError {
  if self.cursor.read_eol() {
    ()
  } else {
    self.consume_bytes(1)
  }
}

///|
/// Skips an ISO 32000-2 section 7.2.4 comment up to but not including the
/// EOL marker, treating it as white-space for token separation.
fn Lexer::skip_comment(self : Lexer) -> Unit raise @objects.PdfParseError {
  self.consume_bytes(1)
  while true {
    match self.cursor.peek() {
      Some(b'\r') | Some(b'\n') | None => break
      Some(_) => self.cursor.read_byte() |> ignore
    }
  }
}

///|
fn Lexer::read_eof_marker(
  self : Lexer,
  offset : Int64,
) -> PdfToken raise @objects.PdfParseError {
  self.consume_bytes(5)
  PdfToken::EofMarker(offset)
}

///|
fn Lexer::read_header_marker(
  self : Lexer,
  offset : Int64,
) -> PdfToken raise @objects.PdfParseError {
  let major = self.header_digit_at(5, offset)
  let minor = self.header_digit_at(7, offset)
  self.consume_bytes(8)
  PdfToken::HeaderMarker(major, minor, offset)
}

///|
fn Lexer::header_digit_at(
  self : Lexer,
  index : Int,
  offset : Int64,
) -> Int raise @objects.PdfParseError {
  match self.cursor.peek_n(index) {
    Some(byte) if byte >= b'0' && byte <= b'9' => byte.to_int() - b'0'.to_int()
    Some(byte) =>
      raise @objects.PdfParseError::UnexpectedToken(
        offset,
        "PDF header digit",
        String::from_array([byte.to_char()]),
      )
    None => raise @objects.PdfParseError::UnexpectedEof(offset, "PDF header")
  }
}

///|
fn Lexer::is_eof_marker(self : Lexer) -> Bool {
  self.matches_bytes(b"%%EOF")
}

///|
fn Lexer::is_header_marker(self : Lexer) -> Bool {
  self.matches_bytes(b"%PDF-") &&
  self.is_digit_at(5) &&
  self.cursor.peek_n(6) == Some(b'.') &&
  self.is_digit_at(7)
}

///|
fn Lexer::is_digit_at(self : Lexer, offset : Int) -> Bool {
  match self.cursor.peek_n(offset) {
    Some(byte) => byte >= b'0' && byte <= b'9'
    None => false
  }
}

///|
fn Lexer::matches_bytes(self : Lexer, expected : Bytes) -> Bool {
  let mut matched = true
  for i in 0..<expected.length() {
    if self.cursor.peek_n(i) != Some(expected[i]) {
      matched = false
    }
  }
  matched
}

///|
fn Lexer::consume_bytes(
  self : Lexer,
  count : Int,
) -> Unit raise @objects.PdfParseError {
  for _ in 0..<count {
    self.cursor.read_byte() |> ignore
  }
}
