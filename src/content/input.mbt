///|
/// Cursor wrapper for decoded content bytes. The parser layer keeps the same
/// zero-based byte offsets as the lower lexer and object parser layers.
pub(all) struct ContentInput {
  cursor : @lexer.ByteCursor
}

///|
/// Creates a decoded-content cursor over already-decoded bytes.
pub fn ContentInput::new(input : Bytes) -> ContentInput {
  ContentInput::{ cursor: @lexer.ByteCursor::new(input) }
}

///|
/// Current byte offset within the decoded content input.
pub fn ContentInput::offset(self : ContentInput) -> Int64 {
  self.cursor.offset()
}

///|
/// Peeks at the current decoded content byte without consuming it.
pub fn ContentInput::peek(self : ContentInput) -> Byte? {
  self.cursor.peek()
}

///|
/// Peeks ahead within the decoded content input without consuming it.
pub fn ContentInput::peek_n(self : ContentInput, n : Int) -> Byte? {
  self.cursor.peek_n(n)
}

///|
/// Reads one decoded content byte while preserving byte offsets.
pub fn ContentInput::read_byte(
  self : ContentInput,
) -> Byte? raise @objects.PdfParseError {
  self.cursor.read_byte()
}

///|
/// Reads a logical EOL marker from the decoded content input.
pub fn ContentInput::read_eol(self : ContentInput) -> Bool {
  self.cursor.read_eol()
}

///|
/// Requires the stream EOL convention used by lower parsing layers.
pub fn ContentInput::require_stream_eol(
  self : ContentInput,
) -> Unit raise @objects.PdfParseError {
  self.cursor.require_stream_eol()
}

///|
/// Reads a raw byte span from the decoded content input.
pub fn ContentInput::read_bytes(
  self : ContentInput,
  length : Int64,
) -> Bytes raise @objects.PdfParseError {
  self.cursor.read_bytes(length)
}
