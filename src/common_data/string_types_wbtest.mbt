///|
test "text string codecs decode BOMs PDFDocEncoding ASCII byte and stream cases" {
  let doc = parse_text_string(
    Bytes::from_array([b't', b'e', b'x', b't', b'\x8b']),
  )
  assert_eq(doc.encoding == PdfTextEncoding::PDFDocEncoding, true)
  inspect(doc.text, content="text‰")
  let utf16 = parse_text_string(
    Bytes::from_array([
      b'\xfe', b'\xff', b'\x00', b'A', b'\xd8', b'\x3d', b'\xde', b'\x00',
    ]),
  )
  assert_eq(utf16.encoding == PdfTextEncoding::UTF16BE, true)
  inspect(utf16.text, content="A😀")
  let utf8 = parse_text_string(
    Bytes::from_array([b'\xef', b'\xbb', b'\xbf', b'j', b'a']),
  )
  assert_eq(utf8.encoding == PdfTextEncoding::UTF8, true)
  inspect(utf8.text, content="ja")
  let ascii = validate_ascii_string(b"ASCII")
  assert_eq(ascii, b"ASCII")
  let byte_string = validate_byte_string(Bytes::from_array([b'\x00', b'\xff']))
  assert_eq(byte_string, Bytes::from_array([b'\x00', b'\xff']))
  assert_eq(validate_text_stream_bytes(b"stream").text, "stream")
}

///|
test "text string diagnostics reject malformed encodings and ASCII high bytes" {
  let bad_doc : Result[String, PdfCommonDataError] = try? decode_pdf_doc_encoding(
    Bytes::from_array([b'\x00']),
  )
  match bad_doc {
    Err(PdfCommonDataError::InvalidTextString(_)) => ()
    _ => fail("expected invalid PDFDocEncoding byte")
  }
  let bad_utf8 : Result[PdfTextString, PdfCommonDataError] = try? parse_text_string(
    Bytes::from_array([b'\xef', b'\xbb', b'\xbf', b'\xff']),
  )
  match bad_utf8 {
    Err(PdfCommonDataError::InvalidTextString(_)) => ()
    _ => fail("expected invalid UTF-8")
  }
  let bad_ascii : Result[Bytes, PdfCommonDataError] = try? validate_ascii_string(
    Bytes::from_array([b'A', b'\x80']),
  )
  match bad_ascii {
    Err(PdfCommonDataError::InvalidAsciiString(_)) => ()
    _ => fail("expected invalid ASCII string")
  }
}

///|
test "unicode language escapes are exposed as metadata" {
  let text = parse_text_string(
    Bytes::from_array([
      b'\xef', b'\xbb', b'\xbf', b'\x1b', b'e', b'n', b'U', b'S', b'\x1b', b'H',
      b'i',
    ]),
  )
  assert_eq(text.language_spans.length(), 1)
  assert_eq(text.language_spans[0].language, b"en")
  assert_eq(text.language_spans[0].country, Some(b"US"))
  let bad : Result[PdfTextString, PdfCommonDataError] = try? parse_text_string(
    Bytes::from_array([b'\xef', b'\xbb', b'\xbf', b'\x1b', b'e']),
  )
  match bad {
    Err(PdfCommonDataError::InvalidTextString(_)) => ()
    _ => fail("expected malformed language escape")
  }
}

///|
test "large PDFDocEncoding text string processes linearly" {
  let data = Bytes::make(4096, b'a')
  let value = parse_text_string(data)
  assert_eq(value.text.length(), 4096)
  assert_eq(value.raw.length(), 4096)
}
