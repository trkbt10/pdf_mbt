///|
/// Reads an ISO 32000-2 section 7.3.5 Name object. The SOLIDUS prefix is
/// excluded, regular bytes form the name, and each #XX hex escape expands to
/// the corresponding byte.
pub fn read_name(
  cursor : ByteCursor,
) -> @objects.PdfName raise @objects.PdfParseError {
  require_name_opening(cursor)
  let bytes : Array[Byte] = []
  while true {
    match cursor.peek() {
      Some(byte) if !is_white_space(byte) && !is_delimiter(byte) =>
        if byte == b'#' && has_name_hex_escape(cursor) {
          let offset = cursor.offset()
          cursor.read_byte() |> ignore
          let high = name_hex_value(read_name_escape_byte(cursor, offset))
          let low = name_hex_value(read_name_escape_byte(cursor, offset))
          let decoded = (high * 16 + low).to_byte()
          if decoded == b'\x00' {
            raise @objects.PdfParseError::InvalidName(
              offset, "name escape decoded to NUL",
            )
          }
          bytes.push(decoded)
        } else {
          cursor.read_byte() |> ignore
          bytes.push(byte)
        }
      _ => break
    }
  }
  @objects.PdfName::new(Bytes::from_array(bytes))
}

///|
fn read_name_escape_byte(
  cursor : ByteCursor,
  offset : Int64,
) -> Byte raise @objects.PdfParseError {
  match cursor.read_byte() {
    Some(byte) => byte
    None => raise @objects.PdfParseError::UnexpectedEof(offset, "name escape")
  }
}

///|
/// Requires the SOLIDUS prefix for an ISO 32000-2 section 7.3.5 Name object.
fn require_name_opening(
  cursor : ByteCursor,
) -> Unit raise @objects.PdfParseError {
  let offset = cursor.offset()
  match cursor.read_byte() {
    Some(b'/') => ()
    Some(byte) =>
      raise @objects.PdfParseError::UnexpectedToken(
        offset,
        "/",
        name_byte_to_text(byte),
      )
    None => raise @objects.PdfParseError::UnexpectedEof(offset, "name")
  }
}

///|
/// Detects the #XX hex escape form used inside a Name object.
fn has_name_hex_escape(cursor : ByteCursor) -> Bool {
  match (cursor.peek_n(1), cursor.peek_n(2)) {
    (Some(high), Some(low)) => is_name_hex_digit(high) && is_name_hex_digit(low)
    _ => false
  }
}

///|
/// Returns true for one hexadecimal digit in a #XX hex escape.
fn is_name_hex_digit(byte : Byte) -> Bool {
  (byte >= b'0' && byte <= b'9') ||
  (byte >= b'A' && byte <= b'F') ||
  (byte >= b'a' && byte <= b'f')
}

///|
/// Converts a #XX hex escape digit to its nibble value.
fn name_hex_value(byte : Byte) -> Int {
  if byte >= b'0' && byte <= b'9' {
    byte.to_int() - b'0'.to_int()
  } else if byte >= b'A' && byte <= b'F' {
    byte.to_int() - b'A'.to_int() + 10
  } else {
    byte.to_int() - b'a'.to_int() + 10
  }
}

///|
fn name_byte_to_text(byte : Byte) -> String {
  String::from_array([byte.to_char()])
}
