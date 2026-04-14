///|
pub fn decode_pdf_doc_encoding(
  bytes : Bytes,
) -> String raise PdfCommonDataError {
  let builder = StringBuilder::new(size_hint=bytes.length())
  for pair in bytes.iter2() {
    let (index, byte) = pair
    match pdf_doc_codepoint(byte) {
      Some(codepoint) =>
        match codepoint.to_char() {
          Some(char) => builder.write_char(char)
          None =>
            raise PdfCommonDataError::InvalidTextString(
              "PDFDocEncoding maps byte offset " +
              index.to_string() +
              " to an invalid Unicode scalar",
            )
        }
      None =>
        raise PdfCommonDataError::InvalidTextString(
          "undefined PDFDocEncoding byte at offset " + index.to_string(),
        )
    }
  }
  builder.to_string()
}

///|
fn pdf_doc_codepoint(byte : Byte) -> Int? {
  let code = byte.to_int()
  if code >= 0x20 && code <= 0x7e {
    Some(code)
  } else if code >= 0xa1 && code <= 0xac {
    Some(code)
  } else if code >= 0xae && code <= 0xd6 {
    Some(code)
  } else if code >= 0xd8 && code <= 0xf6 {
    Some(code)
  } else if code >= 0xf8 && code <= 0xff {
    Some(code)
  } else {
    match code {
      0x18 => Some(0x02d8)
      0x19 => Some(0x02c7)
      0x1a => Some(0x02c6)
      0x1b => Some(0x02d9)
      0x1c => Some(0x02dd)
      0x1d => Some(0x02db)
      0x1e => Some(0x02da)
      0x1f => Some(0x02dc)
      0x80 => Some(0x2022)
      0x81 => Some(0x2020)
      0x82 => Some(0x2021)
      0x83 => Some(0x2026)
      0x84 => Some(0x2014)
      0x85 => Some(0x2013)
      0x86 => Some(0x0192)
      0x87 => Some(0x2044)
      0x88 => Some(0x2039)
      0x89 => Some(0x203a)
      0x8a => Some(0x2212)
      0x8b => Some(0x2030)
      0x8c => Some(0x201e)
      0x8d => Some(0x201c)
      0x8e => Some(0x201d)
      0x8f => Some(0x2018)
      0x90 => Some(0x2019)
      0x91 => Some(0x201a)
      0x92 => Some(0x2122)
      0x93 => Some(0xfb01)
      0x94 => Some(0xfb02)
      0x95 => Some(0x0141)
      0x96 => Some(0x0152)
      0x97 => Some(0x0160)
      0x98 => Some(0x0178)
      0x99 => Some(0x017d)
      0x9a => Some(0x0131)
      0x9b => Some(0x0142)
      0x9c => Some(0x0153)
      0x9d => Some(0x0161)
      0x9e => Some(0x017e)
      0xa0 => Some(0x20ac)
      _ => None
    }
  }
}
