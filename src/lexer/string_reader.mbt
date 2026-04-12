///|
pub fn read_literal_string(
  cursor : ByteCursor,
) -> Bytes raise @objects.PdfParseError {
  require_opening(cursor, b'(', "literal string")
  let output : Array[Byte] = []
  let mut depth = 0
  while true {
    let offset = cursor.offset()
    match cursor.peek() {
      None =>
        raise @objects.PdfParseError::UnexpectedEof(offset, "literal string")
      Some(b')') if depth == 0 => {
        cursor.read_byte() |> ignore
        break
      }
      Some(b')') => {
        cursor.read_byte() |> ignore
        depth -= 1
        output.push(b')')
      }
      Some(b'(') => {
        cursor.read_byte() |> ignore
        depth += 1
        output.push(b'(')
      }
      Some(b'\\') => {
        cursor.read_byte() |> ignore
        read_literal_escape(cursor, output)
      }
      Some(b'\r') | Some(b'\n') => {
        cursor.read_eol() |> ignore
        output.push(b'\n')
      }
      Some(byte) => {
        cursor.read_byte() |> ignore
        output.push(byte)
      }
    }
  }
  Bytes::from_array(output)
}

///|
pub fn read_hex_string(
  cursor : ByteCursor,
) -> Bytes raise @objects.PdfParseError {
  require_opening(cursor, b'<', "hex string")
  let output : Array[Byte] = []
  let mut pending : Int? = None
  while true {
    let offset = cursor.offset()
    match cursor.peek() {
      None => raise @objects.PdfParseError::UnexpectedEof(offset, "hex string")
      Some(b'>') => {
        cursor.read_byte() |> ignore
        if pending is Some(high) {
          output.push((high * 16).to_byte())
        }
        break
      }
      Some(byte) if is_pdf_string_space(byte) => cursor.read_byte() |> ignore
      Some(byte) =>
        match hex_value(byte) {
          Some(value) => {
            cursor.read_byte() |> ignore
            match pending {
              None => pending = Some(value)
              Some(high) => {
                output.push((high * 16 + value).to_byte())
                pending = None
              }
            }
          }
          None =>
            raise @objects.PdfParseError::UnexpectedToken(
              offset,
              "hex digit or >",
              byte_to_text(byte),
            )
        }
    }
  }
  Bytes::from_array(output)
}

///|
fn require_opening(
  cursor : ByteCursor,
  expected : Byte,
  context : String,
) -> Unit raise @objects.PdfParseError {
  let offset = cursor.offset()
  match cursor.read_byte() {
    Some(byte) if byte == expected => ()
    Some(byte) =>
      raise @objects.PdfParseError::UnexpectedToken(
        offset,
        byte_to_text(expected),
        byte_to_text(byte),
      )
    None => raise @objects.PdfParseError::UnexpectedEof(offset, context)
  }
}

///|
fn read_literal_escape(
  cursor : ByteCursor,
  output : Array[Byte],
) -> Unit raise @objects.PdfParseError {
  let offset = cursor.offset()
  match cursor.peek() {
    None =>
      raise @objects.PdfParseError::UnexpectedEof(
        offset, "literal string escape",
      )
    Some(b'\r') | Some(b'\n') => cursor.read_eol() |> ignore
    Some(byte) if is_octal_digit(byte) => output.push(read_octal_escape(cursor))
    Some(byte) => {
      cursor.read_byte() |> ignore
      output.push(
        match byte {
          b'n' => b'\n'
          b'r' => b'\r'
          b't' => b'\t'
          b'b' => b'\b'
          b'f' => b'\f'
          b'(' => b'('
          b')' => b')'
          b'\\' => b'\\'
          other => other
        },
      )
    }
  }
}

///|
fn read_octal_escape(cursor : ByteCursor) -> Byte raise @objects.PdfParseError {
  let mut value = 0
  let mut digits = 0
  while digits < 3 {
    match cursor.peek() {
      Some(byte) if is_octal_digit(byte) => {
        cursor.read_byte() |> ignore
        value = value * 8 + octal_value(byte)
        digits += 1
      }
      _ => break
    }
  }
  (value % 256).to_byte()
}

///|
fn is_octal_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'7'
}

///|
fn octal_value(byte : Byte) -> Int {
  byte.to_int() - b'0'.to_int()
}

///|
fn hex_value(byte : Byte) -> Int? {
  if byte >= b'0' && byte <= b'9' {
    Some(byte.to_int() - b'0'.to_int())
  } else if byte >= b'A' && byte <= b'F' {
    Some(byte.to_int() - b'A'.to_int() + 10)
  } else if byte >= b'a' && byte <= b'f' {
    Some(byte.to_int() - b'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn is_pdf_string_space(byte : Byte) -> Bool {
  match byte {
    b'\x00' | b'\t' | b'\n' | b'\f' | b'\r' | b' ' => true
    _ => false
  }
}

///|
fn byte_to_text(byte : Byte) -> String {
  String::from_array([byte.to_char()])
}
