///|
fn find_latest_startxref(source : ByteSource) -> Int64 raise PdfReaderError {
  let tail = source.slice_from_pdf_offset(0L)
  let eof_index = find_last_marker_before(tail, b"%%EOF", tail.length())
  match eof_index {
    Some(eof_index) => {
      let startxref_index = find_last_startxref_before(tail, eof_index)
      match startxref_index {
        Some(startxref_index) =>
          read_startxref_offset(tail, startxref_index, eof_index)
        None =>
          raise PdfReaderError::MissingTailMarker(
            "startxref not found before final %%EOF",
          )
      }
    }
    None =>
      raise PdfReaderError::MissingTailMarker("%%EOF not found in file tail")
  }
}

///|
fn read_startxref_offset(
  tail : Bytes,
  startxref_index : Int,
  eof_index : Int,
) -> Int64 raise PdfReaderError {
  if !has_startxref_prefix_boundary(tail, startxref_index) {
    raise PdfReaderError::InvalidXref(
      startxref_index.to_int64(),
      "startxref keyword must start at a PDF token boundary",
    )
  }

  let keyword_end = startxref_index + b"startxref".length()
  if !has_startxref_whitespace_after_keyword(tail, keyword_end) {
    raise PdfReaderError::InvalidXref(
      keyword_end.to_int64(),
      "missing whitespace delimiter after startxref",
    )
  }

  let integer_start = skip_tail_whitespace(tail, keyword_end)
  if integer_start >= eof_index {
    raise PdfReaderError::InvalidXref(
      integer_start.to_int64(),
      "missing decimal integer after startxref",
    )
  }

  let mut index = integer_start
  let mut value : Int64 = 0L
  let mut digits = 0
  let max_int64 = 9223372036854775807L
  let zero = b'0'.to_int64()
  while index < eof_index {
    match tail.get(index) {
      Some(byte) if byte >= b'0' && byte <= b'9' => {
        let digit = byte.to_int64() - zero
        let max_before_digit = (max_int64 - digit) / 10L
        if value > max_before_digit {
          raise PdfReaderError::InvalidXref(
            integer_start.to_int64(),
            "startxref integer is too large",
          )
        }
        value = value * 10L + digit
        index = index + 1
        digits = digits + 1
      }
      _ => break
    }
  }

  if digits == 0 {
    raise PdfReaderError::InvalidXref(
      integer_start.to_int64(),
      "expected decimal integer after startxref",
    )
  }

  let after_integer = skip_tail_whitespace(tail, index)
  if after_integer != eof_index {
    raise PdfReaderError::InvalidXref(
      after_integer.to_int64(),
      "unexpected tail content before %%EOF",
    )
  }

  value
}

///|
fn has_startxref_prefix_boundary(tail : Bytes, startxref_index : Int) -> Bool {
  if startxref_index == 0 {
    true
  } else {
    match tail.get(startxref_index - 1) {
      Some(byte) => @lexer.is_white_space(byte) || @lexer.is_delimiter(byte)
      None => false
    }
  }
}

///|
fn find_last_startxref_before(tail : Bytes, exclusive_end : Int) -> Int? {
  let needle = b"startxref"
  let needle_length = needle.length()
  if needle_length > exclusive_end {
    None
  } else {
    let mut index = exclusive_end - needle_length
    let mut found : Int? = None
    while index >= 0 {
      if bytes_match_at(tail, index, needle) &&
        has_startxref_prefix_boundary(tail, index) {
        found = Some(index)
        break
      }
      index = index - 1
    }
    found
  }
}

///|
fn has_startxref_whitespace_after_keyword(
  tail : Bytes,
  keyword_end : Int,
) -> Bool {
  match tail.get(keyword_end) {
    Some(byte) => @lexer.is_white_space(byte)
    None => false
  }
}

///|
fn skip_tail_whitespace(tail : Bytes, index : Int) -> Int {
  let mut index = index
  while index < tail.length() {
    match tail.get(index) {
      Some(byte) if is_tail_whitespace(byte) => index = index + 1
      _ => break
    }
  }
  index
}

///|
fn is_tail_whitespace(byte : Byte) -> Bool {
  match byte {
    b'\x00' | b'\t' | b'\n' | b'\f' | b'\r' | b' ' => true
    _ => false
  }
}

///|
fn find_last_marker_before(
  haystack : Bytes,
  needle : Bytes,
  exclusive_end : Int,
) -> Int? {
  let needle_length = needle.length()
  if needle_length > exclusive_end {
    None
  } else {
    let mut index = exclusive_end - needle_length
    let mut found : Int? = None
    while index >= 0 {
      if bytes_match_at(haystack, index, needle) {
        found = Some(index)
        break
      }
      index = index - 1
    }
    found
  }
}

///|
fn bytes_match_at(haystack : Bytes, offset : Int, needle : Bytes) -> Bool {
  if offset < 0 || offset + needle.length() > haystack.length() {
    false
  } else {
    let mut matched = true
    for i in 0..<needle.length() {
      if haystack[offset + i] != needle[i] {
        matched = false
      }
    }
    matched
  }
}
