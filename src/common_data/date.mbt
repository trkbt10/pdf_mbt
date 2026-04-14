///|
pub fn parse_pdf_date(bytes : Bytes) -> PdfDate raise PdfCommonDataError {
  let text = parse_text_string(bytes).text
  parse_pdf_date_text(bytes, text)
}

///|
pub fn parse_pdf_date_object(
  object : @objects.PdfObject,
) -> PdfDate raise PdfCommonDataError {
  match object {
    @objects.PdfObject::String(bytes) => parse_pdf_date(bytes)
    _ =>
      raise PdfCommonDataError::ExpectedString(
        "date must be a string object, got " + common_object_kind(object),
      )
  }
}

///|
fn parse_pdf_date_text(
  raw : Bytes,
  text : String,
) -> PdfDate raise PdfCommonDataError {
  let chars = text.to_array()
  for char in chars {
    if char.is_whitespace() {
      raise PdfCommonDataError::InvalidDate(
        raw, "date must not contain whitespace",
      )
    }
  }
  if chars.length() < 6 ||
    chars[0].to_int() != b'D'.to_int() ||
    chars[1].to_int() != b':'.to_int() {
    raise PdfCommonDataError::InvalidDate(raw, "date must start with D:YYYY")
  }
  let year = parse_fixed_digits(raw, chars, 2, 4, "year")
  let mut index = 6
  let month = if index < chars.length() {
    let value = parse_fixed_digits(raw, chars, index, 2, "month")
    if value < 1 || value > 12 {
      raise PdfCommonDataError::InvalidDate(raw, "month must be in 01..12")
    }
    index += 2
    value
  } else {
    1
  }
  let day = if index < chars.length() && is_digit(chars[index]) {
    let value = parse_fixed_digits(raw, chars, index, 2, "day")
    if value < 1 || value > 31 {
      raise PdfCommonDataError::InvalidDate(raw, "day must be in 01..31")
    }
    index += 2
    value
  } else {
    1
  }
  let hour = if index < chars.length() && is_digit(chars[index]) {
    let value = parse_fixed_digits(raw, chars, index, 2, "hour")
    if value > 23 {
      raise PdfCommonDataError::InvalidDate(raw, "hour must be in 00..23")
    }
    index += 2
    value
  } else {
    0
  }
  let minute = if index < chars.length() && is_digit(chars[index]) {
    let value = parse_fixed_digits(raw, chars, index, 2, "minute")
    if value > 59 {
      raise PdfCommonDataError::InvalidDate(raw, "minute must be in 00..59")
    }
    index += 2
    value
  } else {
    0
  }
  let second = if index < chars.length() && is_digit(chars[index]) {
    let value = parse_fixed_digits(raw, chars, index, 2, "second")
    if value > 59 {
      raise PdfCommonDataError::InvalidDate(raw, "second must be in 00..59")
    }
    index += 2
    value
  } else {
    0
  }
  let (utc_offset, end_index) = parse_date_offset(raw, chars, index)
  if end_index != chars.length() {
    raise PdfCommonDataError::InvalidDate(raw, "unexpected trailing date data")
  }
  PdfDate::{ raw, year, month, day, hour, minute, second, utc_offset }
}

///|
fn parse_date_offset(
  raw : Bytes,
  chars : Array[Char],
  index : Int,
) -> (PdfUtcOffset, Int) raise PdfCommonDataError {
  if index >= chars.length() {
    return (PdfUtcOffset::UnspecifiedGMT, index)
  }
  let marker = chars[index].to_int()
  if marker == b'Z'.to_int() {
    parse_z_offset(raw, chars, index + 1)
  } else if marker == b'+'.to_int() || marker == b'-'.to_int() {
    let hour = parse_fixed_digits(raw, chars, index + 1, 2, "offset hour")
    if hour > 23 {
      raise PdfCommonDataError::InvalidDate(
        raw, "offset hour must be in 00..23",
      )
    }
    let mut next = index + 3
    let mut minute = 0
    if next < chars.length() && chars[next].to_int() == b'\''.to_int() {
      next += 1
      minute = parse_fixed_digits(raw, chars, next, 2, "offset minute")
      if minute > 59 {
        raise PdfCommonDataError::InvalidDate(
          raw, "offset minute must be in 00..59",
        )
      }
      next += 2
      if next < chars.length() && chars[next].to_int() == b'\''.to_int() {
        next += 1
      }
    }
    if marker == b'+'.to_int() {
      (PdfUtcOffset::LaterThanUT(hour, minute), next)
    } else {
      (PdfUtcOffset::EarlierThanUT(hour, minute), next)
    }
  } else {
    raise PdfCommonDataError::InvalidDate(raw, "invalid UTC offset marker")
  }
}

///|
fn parse_z_offset(
  raw : Bytes,
  chars : Array[Char],
  index : Int,
) -> (PdfUtcOffset, Int) raise PdfCommonDataError {
  if index >= chars.length() {
    return (PdfUtcOffset::EqualUT, index)
  }
  let hour = parse_fixed_digits(raw, chars, index, 2, "Z offset hour")
  if hour != 0 {
    raise PdfCommonDataError::InvalidDate(raw, "Z offset hour must be 00")
  }
  let mut next = index + 2
  if next < chars.length() && chars[next].to_int() == b'\''.to_int() {
    next += 1
  }
  if next < chars.length() {
    let minute = parse_fixed_digits(raw, chars, next, 2, "Z offset minute")
    if minute != 0 {
      raise PdfCommonDataError::InvalidDate(raw, "Z offset minute must be 00")
    }
    next += 2
    if next < chars.length() && chars[next].to_int() == b'\''.to_int() {
      next += 1
    }
  }
  (PdfUtcOffset::EqualUT, next)
}

///|
fn parse_fixed_digits(
  raw : Bytes,
  chars : Array[Char],
  start : Int,
  count : Int,
  label : String,
) -> Int raise PdfCommonDataError {
  if start + count > chars.length() {
    raise PdfCommonDataError::InvalidDate(raw, "missing " + label)
  }
  let mut value = 0
  for index in start..<(start + count) {
    if !is_digit(chars[index]) {
      raise PdfCommonDataError::InvalidDate(raw, label + " must be digits")
    }
    value = value * 10 + chars[index].to_int() - b'0'.to_int()
  }
  value
}

///|
fn is_digit(char : Char) -> Bool {
  let code = char.to_int()
  code >= b'0'.to_int() && code <= b'9'.to_int()
}
