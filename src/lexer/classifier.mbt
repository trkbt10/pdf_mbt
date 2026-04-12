///|
/// PDF character class from ISO 32000-2 section 7.2.3.
/// Each byte outside strings, streams, and comments is classified as
/// white-space, delimiter, or regular.
pub(all) enum CharClass {
  WhiteSpace
  Delimiter
  Regular
} derive(Eq, Debug)

///|
/// Classifies one byte as white-space, delimiter, or regular according to
/// ISO 32000-2 section 7.2.3.
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
/// Returns true for the ISO 32000-2 section 7.2.3 white-space bytes:
/// NUL, HT, LF, FF, CR, and SP. CR, LF, and CRLF are normalized as an
/// EOL marker by ByteCursor::read_eol, and consecutive white-space is
/// collapsed by Lexer::skip_separators.
pub fn is_white_space(byte : Byte) -> Bool {
  match byte {
    b'\x00' | b'\t' | b'\n' | b'\f' | b'\r' | b' ' => true
    _ => false
  }
}

///|
/// Returns true for ISO 32000-2 section 7.2.3 delimiter bytes. A delimiter
/// terminates the preceding regular token without becoming part of it.
pub fn is_delimiter(byte : Byte) -> Bool {
  match byte {
    b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'/' | b'%' => true
    _ => false
  }
}
