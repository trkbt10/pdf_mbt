///|
test "render_page_svg positions Simple PDF text without page group flip" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/Simple PDF 2.0 file.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.has_prefix("<svg"), true)
  assert_eq(svg.contains("<text"), true)
  assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">H</tspan>"), true)
  assert_eq(svg.contains("<tspan x=\"4.333\" y=\"0\">d</tspan>"), true)
  assert_eq(svg.contains("xml:space=\"preserve\">HelloWorld</tspan>"), false)
  assert_eq(svg.contains("<g transform=\"matrix(1 0 0 -1"), false)
  assert_eq(svg.contains("<text transform=\"matrix(24 0 0 24 100 296)"), true)
  assert_eq(svg.contains("font-size=\"1\""), true)
}

///|
test "write_svg_text_matrix_scaled applies Tf font size to identity Tm" {
  let builder = StringBuilder::new()
  write_svg_text_matrix_scaled(
    builder,
    @text.TextMatrix::from_six(1.0, 0.0, 0.0, 1.0, 10.0, 20.0),
    100.0,
    12.0,
  )
  assert_eq(builder.to_string(), "12 0 0 12 10 80")
}

///|
test "render_page_svg scales web PDF identity text matrix by Tf font size" {
  let document = @reader.PdfDocument::open(build_identity_tm_text_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<text transform=\"matrix(12 0 0 12 10 80)"), true)
  assert_eq(svg.contains("font-size=\"1\""), true)
  assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">A</tspan>"), true)
}

///|
test "render_page_svg positions UTF-8 text with text matrix path" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/pdf20-utf8-test.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<text transform=\"matrix(16 0 0 16 72 99.26)"), true)
  assert_eq(svg.contains("text-rendering=\"geometricPrecision\""), true)
  assert_eq(svg.contains("<tspan x=\"0 0.667 1.389 2 2.278"), true)
}

///|
test "write_svg_image uses unit image with CTM transform" {
  let builder = StringBuilder::new()
  write_svg_image(
    builder,
    "data:image/png;base64,AA==",
    @graphics.GraphicsMatrix::from_six(100.0, 0.0, 0.0, 100.0, 72.0, 172.0),
    true,
    true,
    396.0,
  )
  assert_eq(
    builder.to_string(),
    "<image x=\"0\" y=\"0\" width=\"1\" height=\"1\" href=\"data:image/png;base64,AA==\" transform=\"matrix(100.5 0 0 100.5 72 124)\"/>",
  )
}

///|
test "write_svg_image does not expand multi-pixel image CTM" {
  let builder = StringBuilder::new()
  write_svg_image(
    builder,
    "data:image/png;base64,AA==",
    @graphics.GraphicsMatrix::from_six(175.7, 0.0, 0.0, 87.85, 72.0, 590.0),
    false,
    false,
    841.92,
  )
  assert_eq(
    builder.to_string(),
    "<image x=\"72\" y=\"164.07\" width=\"175.7\" height=\"87.85\" href=\"data:image/png;base64,AA==\"/>",
  )
}

///|
test "render_page_svg starts wrapped CalRGB continuation text at line origin" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/PDF 2.0 image with BPC.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<text transform=\"matrix(12 0 0 12 36 110)"), true)
  assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">T</tspan>"), true)
  assert_eq(
    svg.contains("<text transform=\"matrix(12 0 0 12 170.028 110)"),
    false,
  )
}

///|
test "render_page_svg writes transformed path coordinates in SVG space" {
  let document = @reader.PdfDocument::open(build_svg_path_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path"), true)
  assert_eq(svg.contains("d=\"M 12 76 L 16 72 "), true)
  assert_eq(svg.contains("fill=\"none\" stroke=\"#000000\""), true)
}

///|
test "render_page_svg skips unsupported encoded image data without crashing" {
  let document = @reader.PdfDocument::open(build_encoded_image_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.has_prefix("<svg"), true)
  assert_eq(svg.contains("</svg>"), true)
}

///|
fn build_svg_path_fixture() -> Bytes {
  let content = b"2 0 0 2 10 20 cm 1 2 m 3 4 l S"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn build_encoded_image_fixture() -> Bytes {
  let content = b"q 10 0 0 10 5 5 cm /Im1 Do Q"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /JPXDecode /Length 4 >>\nstream\nxxxx\nendstream",
    ],
  )
}

///|
fn build_identity_tm_text_fixture() -> Bytes {
  let content = b"BT /F1 12 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn build_single_page_pdf(
  page_body : Bytes,
  content : Bytes,
  extra_objects : Array[Bytes],
) -> Bytes {
  let header = b"%PDF-2.0\n"
  let header_base = 0L
  let bytes = header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, page_body,
  )
  let content_stream = build_stream_object_body(content)
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let offsets : Array[Int64] = [
    catalog_offset, pages_offset, page_offset, content_offset,
  ]
  let mut bytes = bytes
  let mut object_number = 5
  for object in extra_objects {
    let appended = append_indirect_object(
      bytes, header_base, object_number, 0, object,
    )
    bytes = appended.0
    offsets.push(appended.1)
    object_number += 1
  }

  finish_pdf(bytes, header_base, offsets)
}

///|
fn build_stream_object_body(content : Bytes) -> Bytes {
  b"<< /Length " +
  decimal_bytes(content.length().to_int64()) +
  b" >>\nstream\n" +
  content +
  b"\nendstream"
}

///|
fn append_indirect_object(
  bytes : Bytes,
  header_base : Int64,
  object_number : Int,
  generation : Int,
  body : Bytes,
) -> (Bytes, Int64) {
  let offset = object_offset(bytes, header_base)
  let bytes = bytes +
    decimal_bytes(object_number.to_int64()) +
    b" " +
    decimal_bytes(generation.to_int64()) +
    b" obj\n" +
    body +
    b"\nendobj\n"
  (bytes, offset)
}

///|
fn finish_pdf(
  bytes : Bytes,
  header_base : Int64,
  offsets : Array[Int64],
) -> Bytes {
  let xref_offset = object_offset(bytes, header_base)
  let mut out = bytes +
    b"xref\n0 " +
    decimal_bytes((offsets.length() + 1).to_int64()) +
    b"\n" +
    xref_entry_line(0L, 65535, b'f')
  for offset in offsets {
    out = out + xref_entry_line(offset, 0, b'n')
  }
  out +
  b"trailer\n<< /Size " +
  decimal_bytes((offsets.length() + 1).to_int64()) +
  b" /Root 1 0 R >>\nstartxref\n" +
  decimal_bytes(xref_offset) +
  b"\n%%EOF\n"
}

///|
fn object_offset(bytes : Bytes, header_base : Int64) -> Int64 {
  bytes.length().to_int64() - header_base
}

///|
fn xref_entry_line(
  next_or_offset : Int64,
  generation : Int,
  marker : Byte,
) -> Bytes {
  fixed_width_decimal(next_or_offset, 10) +
  b" " +
  fixed_width_decimal(generation.to_int64(), 5) +
  b" " +
  Bytes::from_array([marker, b' ', b'\n'])
}

///|
fn fixed_width_decimal(value : Int64, width : Int) -> Bytes {
  let digits = decimal_bytes(value)
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
fn decimal_bytes(value : Int64) -> Bytes {
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
  for index in 0..<digits.length() {
    out.push(digits[digits.length() - 1 - index])
  }
  Bytes::from_array(out)
}
