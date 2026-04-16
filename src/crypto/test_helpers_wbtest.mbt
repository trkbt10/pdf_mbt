///|
fn hex(data : Bytes) -> String {
  @x_crypto.bytes_to_hex_string(data)
}

///|
fn unhex(text : String) -> Bytes {
  let chars = text.to_array()
  if chars.length() % 2 != 0 {
    abort("hex text must have even length")
  }
  let out : Array[Byte] = []
  let mut index = 0
  while index < chars.length() {
    out.push(
      ((hex_value(chars[index]) << 4) | hex_value(chars[index + 1])).to_byte(),
    )
    index += 2
  }
  Bytes::from_array(out)
}

///|
fn hex_value(char : Char) -> Int {
  let code = char.to_int()
  if code >= b'0'.to_int() && code <= b'9'.to_int() {
    code - b'0'.to_int()
  } else if code >= b'a'.to_int() && code <= b'f'.to_int() {
    code - b'a'.to_int() + 10
  } else if code >= b'A'.to_int() && code <= b'F'.to_int() {
    code - b'A'.to_int() + 10
  } else {
    abort("invalid hex character")
  }
}
