///|
fn decode_ascii_hex(data : Bytes) -> Bytes raise PdfFilterError {
  let output : Array[Byte] = []
  let mut pending : Int? = None
  let mut index = 0

  while index < data.length() {
    let byte = data[index]
    match byte {
      b'>' => break
      _ if is_pdf_hex_white_space(byte) => ()
      _ =>
        match hex_digit_value(byte) {
          Some(value) =>
            match pending {
              None => pending = Some(value)
              Some(high) => {
                output.push((high * 16 + value).to_byte())
                pending = None
              }
            }
          None =>
            raise PdfFilterError::DecodeError(
              "ASCIIHexDecode", "invalid hexadecimal digit",
            )
        }
    }
    index = index + 1
  }

  match pending {
    Some(high) => output.push((high * 16).to_byte())
    None => ()
  }

  Bytes::from_array(output)
}

///|
/// Returns the integer value 0-15 of an ASCII hex digit byte (0-9, A-F, a-f),
/// or `None` if the byte is not a valid hex digit. Used both by the
/// ASCIIHexDecode filter and by PDF Unicode CMap parsing.
pub fn hex_digit_value(byte : Byte) -> Int? {
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
fn is_pdf_hex_white_space(byte : Byte) -> Bool {
  match byte {
    b'\x00' | b'\t' | b'\n' | b'\f' | b'\r' | b' ' => true
    _ => false
  }
}
