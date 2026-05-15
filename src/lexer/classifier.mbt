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

///|
/// Returns true when the byte is an ASCII decimal digit (0-9). Used by PDF
/// number-token classification when distinguishing Integer and Real lexemes.
pub fn is_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
/// Returns 1 if the lexeme begins with a `+` or `-` sign byte, otherwise 0.
/// Used to skip the optional sign prefix before checking that the remainder
/// of a PDF Integer or Real token is well formed.
pub fn sign_prefix_length(lexeme : Bytes) -> Int {
  if lexeme.length() > 0 && (lexeme[0] == b'+' || lexeme[0] == b'-') {
    1
  } else {
    0
  }
}

///|
/// Returns true when every byte from `start` (inclusive) through the end of
/// `lexeme` is an ASCII decimal digit. Empty ranges return true; callers
/// should reject empty lexemes before consulting this predicate.
pub fn all_digits_from(lexeme : Bytes, start : Int) -> Bool {
  let mut valid = true
  for i in start..<lexeme.length() {
    if !is_digit(lexeme[i]) {
      valid = false
    }
  }
  valid
}

///|
/// Recognizes a signed decimal Integer token as defined by ISO 32000 §7.3.3.
/// Returns true when the lexeme starts with an optional sign followed by one
/// or more decimal digits and contains no PERIOD.
pub fn is_integer_lexeme(lexeme : Bytes) -> Bool {
  let start = sign_prefix_length(lexeme)
  start < lexeme.length() && all_digits_from(lexeme, start)
}

///|
/// Recognizes a Real object token containing exactly one PERIOD as the
/// decimal separator per ISO 32000 §7.3.3. Accepts a leading sign and
/// requires at least one digit on either side of the PERIOD.
pub fn is_real_lexeme(lexeme : Bytes) -> Bool {
  let start = sign_prefix_length(lexeme)
  let mut period_count = 0
  let mut digit_count = 0
  let mut valid = start < lexeme.length()
  for i in start..<lexeme.length() {
    let byte = lexeme[i]
    if byte == b'.' {
      period_count = period_count + 1
    } else if is_digit(byte) {
      digit_count = digit_count + 1
    } else {
      valid = false
    }
  }
  valid && period_count == 1 && digit_count > 0
}

///|
/// Returns true when the lexeme begins with a byte that could plausibly
/// introduce a number token (digit, sign, or PERIOD). Used by recovery
/// paths that decide whether to attempt numeric repair on a malformed
/// token versus surfacing it as an unknown keyword.
pub fn is_numeric_like(lexeme : Bytes) -> Bool {
  if lexeme.length() == 0 {
    false
  } else {
    let first = lexeme[0]
    is_digit(first) || first == b'+' || first == b'-' || first == b'.'
  }
}
