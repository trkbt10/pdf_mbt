///|
/// Byte cursor for ISO 32000-2 section 7.2.3 lexical scanning.
struct ByteCursor {
  input : Bytes
  mut position : Int
}

///|
/// Creates a cursor over PDF bytes while preserving byte offsets.
pub fn ByteCursor::new(input : Bytes) -> ByteCursor {
  ByteCursor::{ input, position: 0 }
}

///|
/// Current byte offset used in parser diagnostics.
pub fn ByteCursor::offset(self : ByteCursor) -> Int64 {
  self.position.to_int64()
}

///|
/// Peeks at the current byte without consuming it.
pub fn ByteCursor::peek(self : ByteCursor) -> Byte? {
  self.peek_n(0)
}

///|
/// Peeks ahead by n bytes without consuming input.
pub fn ByteCursor::peek_n(self : ByteCursor, n : Int) -> Byte? {
  if n < 0 {
    None
  } else {
    self.input.get(self.position + n)
  }
}

///|
/// Reads one raw byte, preserving stream and string byte semantics.
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
/// Consumes one ISO 32000-2 section 7.2.3 EOL marker. CR, LF, and CR
/// followed by LF are treated as one marker.
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
/// Requires the ISO 32000-2 section 7.3.8 stream keyword to be followed by
/// an EOL marker, accepting LF or CRLF and rejecting CR alone.
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
/// Reads an exact raw byte count, used for stream data after the Length entry.
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
