///|
struct Lexer {
  cursor : ByteCursor
  pushed : Array[PdfToken]
}

///|
pub fn Lexer::new(cursor : ByteCursor) -> Lexer {
  Lexer::{ cursor, pushed: [] }
}

///|
pub fn Lexer::push_back(self : Lexer, token : PdfToken) -> Unit {
  self.pushed.push(token)
}

///|
pub fn Lexer::has_pushed_tokens(self : Lexer) -> Bool {
  self.pushed.length() > 0
}

///|
pub fn Lexer::peek_token(self : Lexer) -> PdfToken raise @objects.PdfParseError {
  let token = self.next_token()
  self.push_back(token)
  token
}

///|
pub fn Lexer::next_token(self : Lexer) -> PdfToken raise @objects.PdfParseError {
  match self.pushed.pop() {
    Some(token) => token
    None => self.read_next_token()
  }
}

///|
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
  let major = self.cursor.peek_n(5).unwrap().to_int() - b'0'.to_int()
  let minor = self.cursor.peek_n(7).unwrap().to_int() - b'0'.to_int()
  self.consume_bytes(8)
  PdfToken::HeaderMarker(major, minor, offset)
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
