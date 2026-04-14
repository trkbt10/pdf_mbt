///|
pub fn parse_text_string(
  bytes : Bytes,
) -> PdfTextString raise PdfCommonDataError {
  if bytes.length() >= 2 && bytes[0] == b'\xfe' && bytes[1] == b'\xff' {
    let text = try
      @utf16.decode(
        bytes.view(start=2),
        ignore_bom=true,
        endianness=@utf16.Endian::Big,
      )
    catch {
      _ =>
        raise PdfCommonDataError::InvalidTextString(
          "malformed UTF-16BE text string",
        )
    } noraise {
      value => value
    }
    PdfTextString::{
      raw: bytes,
      text,
      encoding: PdfTextEncoding::UTF16BE,
      language_spans: scan_unicode_language_spans(text),
    }
  } else if bytes.length() >= 3 &&
    bytes[0] == b'\xef' &&
    bytes[1] == b'\xbb' &&
    bytes[2] == b'\xbf' {
    let text = try @utf8.decode(bytes.view(start=3), ignore_bom=true) catch {
      _ =>
        raise PdfCommonDataError::InvalidTextString(
          "malformed UTF-8 text string",
        )
    } noraise {
      value => value
    }
    PdfTextString::{
      raw: bytes,
      text,
      encoding: PdfTextEncoding::UTF8,
      language_spans: scan_unicode_language_spans(text),
    }
  } else {
    PdfTextString::{
      raw: bytes,
      text: decode_pdf_doc_encoding(bytes),
      encoding: PdfTextEncoding::PDFDocEncoding,
      language_spans: [],
    }
  }
}

///|
pub fn parse_text_string_object(
  object : @objects.PdfObject,
) -> PdfTextString raise PdfCommonDataError {
  match object {
    @objects.PdfObject::String(bytes) => parse_text_string(bytes)
    _ =>
      raise PdfCommonDataError::ExpectedString(
        "expected string object, got " + common_object_kind(object),
      )
  }
}

///|
pub fn validate_text_stream_bytes(
  bytes : Bytes,
) -> PdfTextString raise PdfCommonDataError {
  parse_text_string(bytes)
}

///|
pub fn validate_ascii_string(bytes : Bytes) -> Bytes raise PdfCommonDataError {
  for pair in bytes.iter2() {
    let (index, byte) = pair
    if byte.to_int() > 0x7f {
      raise PdfCommonDataError::InvalidAsciiString(
        "non-ASCII byte at offset " + index.to_string(),
      )
    }
  }
  bytes
}

///|
pub fn validate_byte_string(bytes : Bytes) -> Bytes {
  bytes
}

///|
fn scan_unicode_language_spans(
  text : String,
) -> Array[PdfLanguageSpan] raise PdfCommonDataError {
  let chars = text.to_array()
  let spans : Array[PdfLanguageSpan] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index].to_int() == 0x1b {
      if index + 3 < chars.length() && chars[index + 3].to_int() == 0x1b {
        let lang = language_bytes(chars[index + 1], chars[index + 2], index)
        spans.push(PdfLanguageSpan::{
          language: lang,
          country: None,
          start: index,
          end: index + 4,
        })
        index += 4
      } else if index + 5 < chars.length() && chars[index + 5].to_int() == 0x1b {
        let lang = language_bytes(chars[index + 1], chars[index + 2], index)
        let country = language_bytes(chars[index + 3], chars[index + 4], index)
        spans.push(PdfLanguageSpan::{
          language: lang,
          country: Some(country),
          start: index,
          end: index + 6,
        })
        index += 6
      } else {
        raise PdfCommonDataError::InvalidTextString(
          "malformed Unicode language escape at character " + index.to_string(),
        )
      }
    } else {
      index += 1
    }
  }
  spans
}

///|
fn language_bytes(
  first : Char,
  second : Char,
  offset : Int,
) -> Bytes raise PdfCommonDataError {
  if first.to_int() > 0x7f || second.to_int() > 0x7f {
    raise PdfCommonDataError::InvalidTextString(
      "language escape code at character " +
      offset.to_string() +
      " must use ASCII bytes",
    )
  }
  Bytes::from_array([first.to_int().to_byte(), second.to_int().to_byte()])
}
