///|
fn parse_xref_table_section(
  source : ByteSource,
  pdf_offset : Int64,
) -> XrefSection raise PdfReaderError {
  let bytes = source.slice_from_pdf_offset(pdf_offset)
  let mut index = require_xref_keyword(bytes, 0, pdf_offset)
  index = skip_all_xref_whitespace(bytes, index)
  parse_xref_table_body(bytes, index, [], pdf_offset)
}

///|
fn parse_xref_table_body(
  bytes : Bytes,
  index : Int,
  entries : Array[XrefSectionEntry],
  pdf_offset : Int64,
) -> XrefSection raise PdfReaderError {
  if index >= bytes.length() {
    raise PdfReaderError::InvalidXref(
      pdf_offset + index.to_int64(),
      "missing trailer keyword",
    )
  }

  if bytes[index] == b'%' {
    raise PdfReaderError::InvalidXref(
      pdf_offset + index.to_int64(),
      "comments are not allowed between xref and trailer",
    )
  }

  if matches_keyword_at(bytes, index, b"trailer") {
    let trailer = parse_xref_trailer(bytes, index, pdf_offset)
    XrefSection::{
      provenance: XrefSectionProvenance::{
        source: XrefSectionSource::Table,
        pdf_offset,
      },
      entries,
      trailer,
    }
  } else {
    let (first_object_number, entry_count, next_index) = parse_xref_subsection_header(
      bytes, index, pdf_offset,
    )
    let mut index = next_index
    for i in 0..<entry_count {
      let object_number = first_object_number + i
      let (entry, entry_end) = parse_xref_entry(
        bytes, index, object_number, pdf_offset,
      )
      entries.push(XrefSectionEntry::{ object_number, entry })
      index = entry_end
    }
    parse_xref_table_body(
      bytes,
      skip_all_xref_whitespace(bytes, index),
      entries,
      pdf_offset,
    )
  }
}

///|
fn require_xref_keyword(
  bytes : Bytes,
  index : Int,
  pdf_offset : Int64,
) -> Int raise PdfReaderError {
  if !matches_keyword_at(bytes, index, b"xref") {
    raise PdfReaderError::InvalidXref(
      pdf_offset + index.to_int64(),
      "xref keyword not found at section offset",
    )
  }

  let after_keyword = index + b"xref".length()
  let after_padding = skip_inline_xref_whitespace(bytes, after_keyword)
  consume_xref_line_ending(
    bytes,
    after_padding,
    pdf_offset + after_padding.to_int64(),
  )
}

///|
fn parse_xref_subsection_header(
  bytes : Bytes,
  index : Int,
  pdf_offset : Int64,
) -> (Int, Int, Int) raise PdfReaderError {
  let header_offset = pdf_offset + index.to_int64()
  let (first_object_number_value, after_first) = parse_xref_decimal(
    bytes, index, header_offset, "subsection header first object number",
  )
  let first_object_number = require_xref_int(
    first_object_number_value, header_offset, "subsection header first object number",
  )
  let after_first_separator = skip_inline_xref_whitespace(bytes, after_first)
  if after_first_separator == after_first {
    raise PdfReaderError::InvalidXref(
      header_offset, "subsection header must contain two integers",
    )
  }

  let entry_count_offset = pdf_offset + after_first_separator.to_int64()
  let (entry_count_value, after_second) = parse_xref_decimal(
    bytes, after_first_separator, entry_count_offset, "subsection header entry count",
  )
  let entry_count = require_xref_int(
    entry_count_value, entry_count_offset, "subsection header entry count",
  )
  let after_second_separator = skip_inline_xref_whitespace(bytes, after_second)
  let next_index = consume_xref_line_ending(
    bytes, after_second_separator, header_offset,
  )
  require_xref_subsection_object_number_range(
    first_object_number_value, entry_count_value, header_offset,
  )
  (first_object_number, entry_count, next_index)
}

///|
fn parse_xref_entry(
  bytes : Bytes,
  index : Int,
  object_number : Int,
  pdf_offset : Int64,
) -> (XrefEntry, Int) raise PdfReaderError {
  let row_offset = pdf_offset + index.to_int64()
  if index < 0 || index + 20 > bytes.length() {
    raise PdfReaderError::InvalidXref(
      row_offset, "xref entry must be exactly 20 bytes",
    )
  }

  let object_offset = parse_xref_fixed_width_decimal(
    bytes, index, 10, row_offset, "xref entry object offset",
  )
  require_xref_ascii_space(bytes, index + 10, row_offset)

  let generation = parse_xref_fixed_width_decimal(
    bytes,
    index + 11,
    5,
    row_offset,
    "xref entry generation number",
  )
  require_xref_ascii_space(bytes, index + 16, row_offset)

  let marker = bytes[index + 17]
  let entry = match marker {
    b'n' =>
      XrefEntry::InUse(
        object_offset,
        require_xref_int(
          generation,
          row_offset + 11L,
          "xref entry generation number",
        ),
      )
    b'f' =>
      XrefEntry::Free(
        require_xref_int(
          object_offset, row_offset, "xref free entry next object number",
        ),
        require_xref_int(
          generation,
          row_offset + 11L,
          "xref entry generation number",
        ),
      )
    _ =>
      raise PdfReaderError::InvalidXref(
        row_offset + 17L,
        "xref entry marker must be n or f",
      )
  }

  require_xref_entry_eol(bytes, index + 18, row_offset)

  if object_number == 0 {
    match entry {
      Free(_, 65535) => ()
      Free(_, _) =>
        raise PdfReaderError::InvalidXref(
          row_offset, "object 0 must be free with generation 65535",
        )
      InUse(_, _) =>
        raise PdfReaderError::InvalidXref(
          row_offset, "object 0 must be free with generation 65535",
        )
      Compressed(_, _) =>
        raise PdfReaderError::InvalidXref(
          row_offset, "object 0 must be free with generation 65535",
        )
    }
  }

  (entry, index + 20)
}

///|
fn parse_xref_trailer(
  bytes : Bytes,
  index : Int,
  pdf_offset : Int64,
) -> TrailerInfo raise PdfReaderError {
  let keyword_offset = pdf_offset + index.to_int64()
  let after_keyword = index + b"trailer".length()
  let after_padding = skip_all_xref_whitespace(bytes, after_keyword)
  if after_padding >= bytes.length() {
    raise PdfReaderError::InvalidTrailer(
      keyword_offset, "missing trailer dictionary",
    )
  }

  let trailer_bytes = bytes[after_padding:bytes.length()].to_bytes()
  let parsed = try? @parser.parse_object(trailer_bytes)
  match parsed {
    Ok(@objects.PdfObject::Dictionary(dict)) =>
      parse_trailer_info(
        dict,
        PdfVersion::{ major: 1, minor: 7 },
        offset=pdf_offset + after_padding.to_int64(),
      )
    Ok(_) =>
      raise PdfReaderError::InvalidTrailer(
        pdf_offset + after_padding.to_int64(),
        "trailer keyword must be followed by a dictionary",
      )
    Err(_) =>
      raise PdfReaderError::InvalidTrailer(
        pdf_offset + after_padding.to_int64(),
        "invalid trailer dictionary",
      )
  }
}

///|
fn require_xref_int(
  value : Int64,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  if value > 2147483647L {
    raise PdfReaderError::InvalidXref(offset, "\{context} is too large for Int")
  }
  value.to_int()
}

///|
fn require_xref_subsection_object_number_range(
  first_object_number : Int64,
  entry_count : Int64,
  offset : Int64,
) -> Unit raise PdfReaderError {
  if entry_count > 0L {
    let last_object_number = first_object_number + entry_count - 1L
    if last_object_number > 2147483647L {
      raise PdfReaderError::InvalidXref(
        offset, "xref subsection object numbers overflow Int",
      )
    }
  }
}

///|
fn parse_xref_decimal(
  bytes : Bytes,
  index : Int,
  offset : Int64,
  context : String,
) -> (Int64, Int) raise PdfReaderError {
  if index >= bytes.length() {
    raise PdfReaderError::InvalidXref(offset, "unexpected end of xref data")
  }

  let zero = b'0'.to_int64()
  let mut value = 0L
  let mut digits = 0
  let mut current = index
  while current < bytes.length() {
    match bytes[current] {
      byte if byte >= b'0' && byte <= b'9' => {
        let digit = byte.to_int64() - zero
        let max_before_digit = (9223372036854775807L - digit) / 10L
        if value > max_before_digit {
          raise PdfReaderError::InvalidXref(offset, "\{context} is too large")
        }
        value = value * 10L + digit
        current = current + 1
        digits = digits + 1
      }
      _ => break
    }
  }

  if digits == 0 {
    raise PdfReaderError::InvalidXref(
      offset,
      "\{context} must be a non-negative integer",
    )
  }

  (value, current)
}

///|
fn parse_xref_fixed_width_decimal(
  bytes : Bytes,
  index : Int,
  width : Int,
  offset : Int64,
  context : String,
) -> Int64 raise PdfReaderError {
  if index < 0 || index + width > bytes.length() {
    raise PdfReaderError::InvalidXref(
      offset, "xref entry must be exactly 20 bytes",
    )
  }

  let zero = b'0'.to_int64()
  let mut value = 0L
  for i in 0..<width {
    let byte = bytes[index + i]
    if byte < b'0' || byte > b'9' {
      raise PdfReaderError::InvalidXref(offset, "\{context} must be decimal")
    }
    let digit = byte.to_int64() - zero
    let max_before_digit = (9223372036854775807L - digit) / 10L
    if value > max_before_digit {
      raise PdfReaderError::InvalidXref(offset, "\{context} is too large")
    }
    value = value * 10L + digit
  }
  value
}

///|
fn require_xref_ascii_space(
  bytes : Bytes,
  index : Int,
  offset : Int64,
) -> Unit raise PdfReaderError {
  if index >= bytes.length() || bytes[index] != b' ' {
    raise PdfReaderError::InvalidXref(
      offset, "xref entry fields must be separated by spaces",
    )
  }
}

///|
fn require_xref_entry_eol(
  bytes : Bytes,
  index : Int,
  offset : Int64,
) -> Unit raise PdfReaderError {
  if index >= bytes.length() {
    raise PdfReaderError::InvalidXref(
      offset, "xref entry must be exactly 20 bytes",
    )
  }

  match bytes[index] {
    b'\r' if index + 1 < bytes.length() && bytes[index + 1] == b'\n' => ()
    b' ' if index + 1 < bytes.length() &&
      (bytes[index + 1] == b'\r' || bytes[index + 1] == b'\n') => ()
    _ =>
      raise PdfReaderError::InvalidXref(
        offset, "xref entry must use CRLF, SP+CR, or SP+LF row endings",
      )
  }
}

///|
fn matches_keyword_at(bytes : Bytes, index : Int, keyword : Bytes) -> Bool {
  if index < 0 || index + keyword.length() > bytes.length() {
    false
  } else {
    let mut matched = true
    for i in 0..<keyword.length() {
      if bytes[index + i] != keyword[i] {
        matched = false
      }
    }
    matched && has_keyword_boundary(bytes, index + keyword.length())
  }
}

///|
fn has_keyword_boundary(bytes : Bytes, index : Int) -> Bool {
  match bytes.get(index) {
    Some(byte) => @lexer.is_white_space(byte) || @lexer.is_delimiter(byte)
    None => true
  }
}

///|
fn skip_all_xref_whitespace(bytes : Bytes, index : Int) -> Int {
  let mut current = index
  while current < bytes.length() {
    match bytes[current] {
      byte if @lexer.is_white_space(byte) => current = current + 1
      _ => break
    }
  }
  current
}

///|
fn skip_inline_xref_whitespace(bytes : Bytes, index : Int) -> Int {
  let mut current = index
  while current < bytes.length() {
    match bytes[current] {
      b'\x00' | b'\t' | b'\f' | b' ' => current = current + 1
      _ => break
    }
  }
  current
}

///|
fn consume_xref_line_ending(
  bytes : Bytes,
  index : Int,
  offset : Int64,
) -> Int raise PdfReaderError {
  if index >= bytes.length() {
    raise PdfReaderError::InvalidXref(offset, "missing xref line ending")
  }

  match bytes[index] {
    b'\r' if index + 1 < bytes.length() && bytes[index + 1] == b'\n' =>
      index + 2
    b'\r' => index + 1
    b'\n' => index + 1
    _ =>
      raise PdfReaderError::InvalidXref(
        offset, "xref subsection headers must end with EOL",
      )
  }
}
