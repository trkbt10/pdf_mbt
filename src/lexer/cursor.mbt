///|
struct ByteCursor {
  input : Bytes
  mut position : Int
}

///|
pub fn ByteCursor::new(input : Bytes) -> ByteCursor {
  ByteCursor::{ input, position: 0 }
}

///|
pub fn ByteCursor::offset(self : ByteCursor) -> Int64 {
  self.position.to_int64()
}

///|
pub fn ByteCursor::peek(self : ByteCursor) -> Byte? {
  self.peek_n(0)
}

///|
pub fn ByteCursor::peek_n(self : ByteCursor, n : Int) -> Byte? {
  if n < 0 {
    None
  } else {
    self.input.get(self.position + n)
  }
}

///|
pub fn ByteCursor::read_byte(
  self : ByteCursor,
) -> Byte? raise @objects.PdfParseError {
  if self.position < 0 {
    raise @objects.PdfParseError::InvalidStream(
      self.offset(),
      "cursor offset is negative",
    )
  }
  match self.peek() {
    Some(byte) => {
      self.position += 1
      Some(byte)
    }
    None => None
  }
}

///|
pub fn ByteCursor::read_eol(self : ByteCursor) -> Bool {
  match self.peek() {
    Some(b'\r') => {
      self.position += 1
      if self.peek() == Some(b'\n') {
        self.position += 1
      }
      true
    }
    Some(b'\n') => {
      self.position += 1
      true
    }
    _ => false
  }
}

///|
pub fn ByteCursor::require_stream_eol(
  self : ByteCursor,
) -> Unit raise @objects.PdfParseError {
  let offset = self.offset()
  match self.peek() {
    Some(b'\n') => self.position += 1
    Some(b'\r') => {
      self.position += 1
      if self.peek() == Some(b'\n') {
        self.position += 1
      } else {
        raise @objects.PdfParseError::InvalidStream(
          offset, "stream EOL must be LF or CRLF",
        )
      }
    }
    Some(_) =>
      raise @objects.PdfParseError::InvalidStream(
        offset, "stream EOL must follow stream keyword",
      )
    None => raise @objects.PdfParseError::UnexpectedEof(offset, "stream EOL")
  }
}

///|
pub fn ByteCursor::read_bytes(
  self : ByteCursor,
  length : Int64,
) -> Bytes raise @objects.PdfParseError {
  let offset = self.offset()
  if length < 0L {
    raise @objects.PdfParseError::InvalidStream(
      offset, "raw byte length must be non-negative",
    )
  }
  let remaining = self.input.length() - self.position
  if length > remaining.to_int64() {
    raise @objects.PdfParseError::UnexpectedEof(
      self.input.length().to_int64(),
      "raw bytes",
    )
  }
  let count = length.to_int()
  let start = self.position
  let bytes = Bytes::makei(count, i => self.input[start + i])
  self.position += count
  bytes
}
