///|
test "text extraction layout mode preserves word gaps and lines" {
  let document = @reader.PdfDocument::open(build_cli_text_layout_fixture())
  assert_eq(extract_document_text(document, (1, 1), layout=true), "A B\nC")
  assert_eq(extract_document_text(document, (1, 1)), "ABC")
}

///|
fn build_cli_text_layout_fixture() -> Bytes {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header
  let (bytes, catalog_offset) = append_cli_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_cli_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources << /Font << /F1 5 0 R >> >> >>",
  )
  let (bytes, page_offset) = append_cli_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
  )
  let content = cli_stream_body(
    b"<< /Length 89 >>", b"BT /F1 10 Tf 1 0 0 1 10 100 Tm (A) Tj 1 0 0 1 22 100 Tm (B) Tj 1 0 0 1 10 80 Tm (C) Tj ET",
  )
  let (bytes, content_offset) = append_cli_indirect_object(
    bytes, header_base, 4, 0, content,
  )
  let (bytes, font_offset) = append_cli_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /FirstChar 65 /Widths [600 600 600] /ToUnicode 6 0 R >>",
  )
  let to_unicode = cli_stream_body(
    b"<< /Length 109 >>", b"1 begincodespacerange\n<00> <ff>\nendcodespacerange\n3 beginbfchar\n<41> <0041>\n<42> <0042>\n<43> <0043>\nendbfchar",
  )
  let (bytes, unicode_offset) = append_cli_indirect_object(
    bytes, header_base, 6, 0, to_unicode,
  )
  finish_cli_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, font_offset, unicode_offset,
  ])
}

///|
fn append_cli_indirect_object(
  bytes : Bytes,
  header_base : Int64,
  object_number : Int,
  generation : Int,
  body : Bytes,
) -> (Bytes, Int64) {
  let offset = cli_object_offset(bytes, header_base)
  let bytes = bytes +
    cli_decimal_bytes(object_number.to_int64()) +
    b" " +
    cli_decimal_bytes(generation.to_int64()) +
    b" obj\n" +
    body +
    b"\nendobj\n"
  (bytes, offset)
}

///|
fn cli_stream_body(dict : Bytes, data : Bytes) -> Bytes {
  dict + b"\r\nstream\r\n" + data + b"\r\nendstream"
}

///|
fn finish_cli_fixture(
  bytes : Bytes,
  header_base : Int64,
  offsets : Array[Int64],
) -> Bytes {
  let xref_offset = cli_object_offset(bytes, header_base)
  let mut out = bytes +
    b"xref\r\n" +
    b"0 " +
    cli_decimal_bytes((offsets.length() + 1).to_int64()) +
    b"\r\n" +
    cli_xref_entry_line(0L, 65535, b'f')
  for offset in offsets {
    out = out + cli_xref_entry_line(offset, 0, b'n')
  }
  out +
  b"trailer\r\n" +
  b"<< /Size " +
  cli_decimal_bytes((offsets.length() + 1).to_int64()) +
  b" /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  cli_decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn cli_object_offset(bytes : Bytes, header_base : Int64) -> Int64 {
  bytes.length().to_int64() - header_base
}

///|
fn cli_xref_entry_line(
  offset : Int64,
  generation : Int,
  marker : Byte,
) -> Bytes {
  cli_fixed_width_decimal(offset, 10) +
  b" " +
  cli_fixed_width_decimal(generation.to_int64(), 5) +
  b" " +
  Bytes::from_array([marker, b'\r', b'\n'])
}

///|
fn cli_fixed_width_decimal(value : Int64, width : Int) -> Bytes {
  let digits = cli_decimal_bytes(value)
  let out : Array[Byte] = []
  let mut padding = width - digits.length()
  while padding > 0 {
    out.push(b'0')
    padding = padding - 1
  }
  for digit in digits {
    out.push(digit)
  }
  Bytes::from_array(out)
}

///|
fn cli_decimal_bytes(value : Int64) -> Bytes {
  let digits : Array[Byte] = []
  let mut current = value
  if current == 0L {
    digits.push(b'0')
  } else {
    while current > 0L {
      let digit = (current % 10L).to_int()
      digits.push((b'0'.to_int() + digit).to_byte())
      current = current / 10L
    }
  }
  let out : Array[Byte] = []
  let mut index = digits.length() - 1
  while index >= 0 {
    out.push(digits[index])
    index = index - 1
  }
  Bytes::from_array(out)
}
