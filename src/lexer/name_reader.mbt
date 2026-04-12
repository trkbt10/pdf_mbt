///|
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
          let high = name_hex_value(cursor.read_byte().unwrap())
          let low = name_hex_value(cursor.read_byte().unwrap())
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
fn has_name_hex_escape(cursor : ByteCursor) -> Bool {
  match (cursor.peek_n(1), cursor.peek_n(2)) {
    (Some(high), Some(low)) => is_name_hex_digit(high) && is_name_hex_digit(low)
    _ => false
  }
}

///|
fn is_name_hex_digit(byte : Byte) -> Bool {
  (byte >= b'0' && byte <= b'9') ||
  (byte >= b'A' && byte <= b'F') ||
  (byte >= b'a' && byte <= b'f')
}

///|
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
