///|
pub(all) enum CharClass {
  WhiteSpace
  Delimiter
  Regular
} derive(Eq, Debug)

///|
pub fn classify_byte(byte : Byte) -> CharClass {
  if is_white_space(byte) {
    WhiteSpace
  } else if is_delimiter(byte) {
    Delimiter
  } else {
    Regular
  }
}

///|
pub fn is_white_space(byte : Byte) -> Bool {
  match byte {
    b'\x00' | b'\t' | b'\n' | b'\f' | b'\r' | b' ' => true
    _ => false
  }
}

///|
pub fn is_delimiter(byte : Byte) -> Bool {
  match byte {
    b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'/' | b'%' => true
    _ => false
  }
}
