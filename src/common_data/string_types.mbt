///|
/// Qualifies the fundamental PDF string object as a 7.9.2 text string, ASCII
/// string, or byte string. The qualification is supplied by the
/// document-hierarchy context: text strings decode human-readable characters,
/// ASCII strings reject non-7-bit bytes, and byte strings preserve arbitrary
/// binary data.
pub fn qualify_pdf_string(
  bytes : Bytes,
  qualification : PdfStringQualification,
) -> PdfStringKind raise PdfCommonDataError {
  match qualification {
    TextString => PdfStringKind::Text(parse_text_string(bytes))
    ASCIIString => PdfStringKind::Ascii(validate_ascii_string(bytes))
    ByteString => PdfStringKind::Byte(validate_byte_string(bytes))
  }
}

///|
/// Parses a 7.9.2 text string from raw string bytes. A leading 254, 255 byte
/// order marker selects UTF-16BE, a leading 239, 187, 191 byte order marker
/// selects UTF-8, and all other bytes are decoded as PDFDocEncoding.
pub fn parse_text_string(
  bytes : Bytes,
) -> PdfTextString raise PdfCommonDataError {
  if bytes.length() >= 2 && bytes[0].to_int() == 254 && bytes[1].to_int() == 255 {
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
    bytes[0].to_int() == 239 &&
    bytes[1].to_int() == 187 &&
    bytes[2].to_int() == 191 {
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
/// Parses a PDF string object as a document-hierarchy text string and rejects
/// non-string objects with a common-data diagnostic.
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
/// Validates unencoded text stream bytes using the same byte order and lead
/// byte requirements as a 7.9.2.2 text string.
pub fn validate_text_stream_bytes(
  bytes : Bytes,
) -> PdfTextString raise PdfCommonDataError {
  parse_text_string(bytes)
}

///|
/// Validates a 7.9.2 ASCII string by accepting only 7-bit bytes.
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
/// Validates a 7.9.2 byte string by preserving arbitrary 8-bit payload bytes
/// without making character encoding assumptions.
pub fn validate_byte_string(bytes : Bytes) -> Bytes {
  bytes
}

///|
/// Scans decoded Unicode text for 7.9.2.2.2 language escape sequences. Each
/// sequence consists of ESCAPE U+001B, a 2-byte BCP 47 language code, an
/// optional 2-byte ISO 3166 country code, and a closing ESCAPE U+001B. Registry
/// validation and language negotiation are intentionally outside this parser.
pub fn scan_unicode_language_spans(
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
