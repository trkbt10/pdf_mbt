///|
test "render_page_svg positions Simple PDF text without page group flip" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/Simple PDF 2.0 file.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.has_prefix("<svg"), true)
  assert_eq(svg.contains("<g transform=\"matrix(1 0 0 -1"), false)
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text"), true)
      assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">H</tspan>"), true)
      assert_eq(svg.contains("<tspan x=\"103.992\" y=\"0\">d</tspan>"), true)
      assert_eq(
        svg.contains("xml:space=\"preserve\">HelloWorld</tspan>"),
        false,
      )
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 100 296)"), true)
      assert_eq(svg.contains("font-size=\"24\""), true)
    }
  }
}

///|
test "write_svg_text_matrix writes factored text matrix in SVG coordinates" {
  let builder = StringBuilder::new()
  let matrix = @text.TextRenderingMatrix::from_text_state(
      @text.TextMatrix::from_six(1.0, 0.0, 0.0, 1.0, 10.0, 20.0),
      12.0,
      1.0,
      0.0,
      @text.TextMatrix::identity(),
    ).matrix
  let font_size = svg_extract_font_size(matrix)
  let svg_matrix = svg_text_transform_without_fontsize(matrix, font_size, 100.0)
  write_svg_text_matrix(builder, svg_matrix)
  assert_eq(builder.to_string(), "1 0 0 1 10 80")
}

///|
test "svg_extract_font_size uses y scale for non-rotated text" {
  let matrix = @text.TextMatrix::from_six(18.0, 0.0, 0.0, -12.0, 10.0, 20.0)
  assert_eq(svg_extract_font_size(matrix), 12.0)
}

///|
test "svg_extract_font_size uses first axis length for rotated text" {
  let matrix = @text.TextMatrix::from_six(0.0, 14.0, -14.0, 0.0, 10.0, 20.0)
  assert_eq(svg_extract_font_size(matrix), 14.0)
}

///|
test "svg_text_transform_without_fontsize preserves rotation and translation" {
  let matrix = @text.TextMatrix::from_six(0.0, 14.0, -14.0, 0.0, 10.0, 20.0)
  let svg_matrix = svg_text_transform_without_fontsize(matrix, 14.0, 100.0)
  assert_eq(svg_matrix.a, 0.0)
  assert_eq(svg_matrix.b, -1.0)
  assert_eq(svg_matrix.c, 1.0)
  assert_eq(svg_matrix.d, 0.0)
  assert_eq(svg_matrix.e, 10.0)
  assert_eq(svg_matrix.f, 80.0)
}

///|
test "rgb_hex_colour follows pdftoppm-style single precision rounding" {
  assert_eq(
    rgb_hex_colour(@graphics.DeviceRgbColour::{
      red: 0.7,
      green: 0.7,
      blue: 0.7,
    }),
    "#B2B2B2",
  )
  assert_eq(
    rgb_hex_colour(@graphics.DeviceRgbColour::{
      red: 0.5,
      green: 0.75,
      blue: 1.0,
    }),
    "#80BFFF",
  )
  assert_eq(
    rgb_hex_colour(@graphics.DeviceRgbColour::{
      red: 0.5,
      green: 0.1,
      blue: 0.2,
    }),
    "#801933",
  )
}

///|
test "render_page_svg scales web PDF identity text matrix by Tf font size" {
  let document = @reader.PdfDocument::open(build_identity_tm_text_fixture())
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 10 80)"), true)
      assert_eq(svg.contains("font-size=\"12\""), true)
      assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">A</tspan>"), true)
    }
  }
}

///|
test "render_page_svg renders embedded TrueType glyphs as paths" {
  let document = @reader.PdfDocument::open(
    build_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("font-family=\""), false)
  assert_eq(svg.contains("fill=\"#000000\""), true)
}

///|
test "render_page_svg uses nonstroking colour for embedded glyph paths" {
  let document = @reader.PdfDocument::open(
    build_coloured_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("fill=\"#FF0000\""), true)
}

///|
test "render_page_svg uses nonstroking colour for text fallback" {
  let document = @reader.PdfDocument::open(
    build_coloured_text_fallback_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<text"), true)
  assert_eq(svg.contains("<path d=\""), false)
  assert_eq(svg.contains("fill=\"#00FF00\""), true)
}

///|
test "render_page_svg renders FontFile3 OpenType glyphs as paths" {
  let document = @reader.PdfDocument::open(
    build_embedded_fontfile3_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("font-family=\""), false)
}

///|
test "render_page_svg uses system font paths for Standard 14 when available" {
  let document = @reader.PdfDocument::open(build_identity_tm_text_fixture())
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
      assert_eq(svg.contains("font-family=\""), false)
    }
    None => {
      assert_eq(svg.contains("<text"), true)
      assert_eq(svg.contains("<path d=\""), false)
    }
  }
}

///|
test "render_page_svg scales embedded TrueType path transform by units per em" {
  let document = @reader.PdfDocument::open(
    build_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("transform=\"matrix(0.01 0 0 -0.01 10 80)\""), true)
}

///|
test "render_page_svg uses rendering matrix with graphics CTM for text" {
  let document = @reader.PdfDocument::open(build_ctm_scaled_text_fixture())
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 20 68)"), true)
      assert_eq(svg.contains("<text transform=\"matrix(10 0 0 10 5 94)"), false)
      assert_eq(svg.contains("font-size=\"20\""), true)
    }
  }
}

///|
test "render_page_svg positions UTF-8 text with text matrix path" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/pdf20-utf8-test.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(
        svg.contains("<text transform=\"matrix(1 0 0 1 72 99.26)"),
        true,
      )
      assert_eq(svg.contains("text-rendering=\"geometricPrecision\""), true)
      assert_eq(svg.contains("<tspan x=\"0 10.672 22.224 32 36.448"), true)
    }
  }
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
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 36 110)"), true)
      assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">T</tspan>"), true)
      assert_eq(
        svg.contains("<text transform=\"matrix(1 0 0 1 170.028 110)"),
        false,
      )
    }
  }
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
fn build_embedded_truetype_text_fixture() -> Bytes {
  let content = b"BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let font_file = build_stream_object_body(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_coloured_embedded_truetype_text_fixture() -> Bytes {
  let content = b"1 0 0 rg BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let font_file = build_stream_object_body(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_coloured_text_fallback_fixture() -> Bytes {
  let content = b"0 1 0 rg BT /F1 12 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /ColourFallback /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding >> >> >> /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn build_embedded_fontfile3_text_fixture() -> Bytes {
  let content = b"BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let font_file = build_stream_object_body_with_entries(
    b"/Subtype /OpenType",
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile3 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_ctm_scaled_text_fixture() -> Bytes {
  let content = b"2 0 0 2 10 20 cm BT /F1 10 Tf 1 0 0 1 5 6 Tm (A) Tj ET"
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
fn build_stream_object_body_with_entries(
  entries : Bytes,
  content : Bytes,
) -> Bytes {
  b"<< /Length " +
  decimal_bytes(content.length().to_int64()) +
  b" " +
  entries +
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
