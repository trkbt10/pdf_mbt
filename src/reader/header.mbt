///|
#warnings("-unused_value")
priv struct HeaderScanResult {
  /// Parsed header scan result with the version and the byte index after the
  /// required end-of-line marker.
  version : PdfVersion
  header_end : Int
}

///|
fn parse_header(input : Bytes) -> PdfHeader raise PdfReaderError {
  let base_offset = find_header_offset(input)
  let scan = parse_header_version(input, base_offset)
  let has_binary_indicator = detect_binary_indicator(input, scan.header_end)
  PdfHeader::{
    version: scan.version,
    base_offset: base_offset.to_int64(),
    has_binary_indicator,
  }
}

///|
fn find_header_offset(input : Bytes) -> Int raise PdfReaderError {
  let length = input.length()
  let mut offset = 0
  while offset + 4 < length {
    if header_marker_at(input, offset) {
      return offset
    }
    offset += 1
  }
  raise PdfReaderError::InvalidHeader(0L, "missing %PDF- header")
}

///|
fn header_marker_at(input : Bytes, offset : Int) -> Bool {
  match
    (
      input.get(offset),
      input.get(offset + 1),
      input.get(offset + 2),
      input.get(offset + 3),
      input.get(offset + 4),
    ) {
    (Some(b'%'), Some(b'P'), Some(b'D'), Some(b'F'), Some(b'-')) => true
    _ => false
  }
}

///|
fn parse_header_version(
  input : Bytes,
  base_offset : Int,
) -> HeaderScanResult raise PdfReaderError {
  let major_index = base_offset + 5
  let minor_index = base_offset + 7
  let eol_index = base_offset + 8
  let major = parse_version_digit(input, major_index, "PDF version major digit")
  let dot = require_header_byte(input, base_offset + 6, "PDF version separator")
  if dot != b'.' {
    raise PdfReaderError::InvalidHeader(
      (base_offset + 6).to_int64(),
      "expected '.' in PDF version",
    )
  }
  let minor = parse_version_digit(input, minor_index, "PDF version minor digit")
  validate_supported_version(major, minor, (base_offset + 5).to_int64())
  let header_end = consume_header_eol(input, eol_index)
  HeaderScanResult::{ version: PdfVersion::{ major, minor }, header_end }
}

///|
fn validate_supported_version(
  major : Int,
  minor : Int,
  offset : Int64,
) -> Unit raise PdfReaderError {
  if major == 1 && minor >= 0 && minor <= 7 {
    ()
  } else if major == 2 && minor == 0 {
    ()
  } else {
    raise PdfReaderError::InvalidHeader(offset, "unsupported PDF version")
  }
}

///|
fn parse_version_digit(
  input : Bytes,
  index : Int,
  context : String,
) -> Int raise PdfReaderError {
  let byte = require_header_byte(input, index, context)
  if byte >= b'0' && byte <= b'9' {
    byte.to_int() - b'0'.to_int()
  } else {
    raise PdfReaderError::InvalidHeader(
      index.to_int64(),
      "expected decimal digit in PDF version",
    )
  }
}

///|
fn require_header_byte(
  input : Bytes,
  index : Int,
  context : String,
) -> Byte raise PdfReaderError {
  match input.get(index) {
    Some(byte) => byte
    None =>
      raise PdfReaderError::InvalidHeader(
        index.to_int64(),
        "unterminated header: missing \{context}",
      )
  }
}

///|
fn consume_header_eol(input : Bytes, index : Int) -> Int raise PdfReaderError {
  match input.get(index) {
    Some(b'\r') =>
      if input.get(index + 1) == Some(b'\n') {
        index + 2
      } else {
        index + 1
      }
    Some(b'\n') => index + 1
    Some(byte) =>
      raise PdfReaderError::InvalidHeader(
        index.to_int64(),
        "expected EOL after PDF version, found \{byte.to_char()}",
      )
    None =>
      raise PdfReaderError::InvalidHeader(
        index.to_int64(),
        "unterminated header: missing EOL after PDF version",
      )
  }
}

///|
fn detect_binary_indicator(input : Bytes, header_end : Int) -> Bool {
  match input.get(header_end) {
    Some(b'%') => scan_binary_indicator_comment(input, header_end + 1)
    _ => false
  }
}

///|
fn scan_binary_indicator_comment(input : Bytes, start : Int) -> Bool {
  let mut high_bit_bytes = 0
  let mut index = start
  while true {
    match input.get(index) {
      Some(b'\r') => {
        if input.get(index + 1) == Some(b'\n') {
          index += 2
        } else {
          index += 1
        }
        break
      }
      Some(b'\n') => {
        index += 1
        break
      }
      Some(byte) => {
        if byte >= b'\x80' {
          high_bit_bytes += 1
        }
        index += 1
      }
      None => break
    }
  }
  high_bit_bytes >= 4
}
