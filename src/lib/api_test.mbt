///|
test "lib open reads Simple PDF 2.0 file" {
  let document = open(simple_pdf20_file_bytes())
  assert_eq(document.page_count(), 1)
}

///|
test "lib extract_page_text returns Simple PDF text" {
  let document = open(simple_pdf20_file_bytes())
  let page = document.page(0)
  assert_eq(extract_page_text(page), "HelloWorld")
  assert_eq(page.extract_text(), "HelloWorld")
  assert_eq(extract_page_text_layout(page), "HelloWorld")
  assert_eq(page.extract_text_layout(), "HelloWorld")
}

///|
test "lib extract_all_text returns document text" {
  let document = open(simple_pdf20_file_bytes())
  assert_eq(extract_all_text(document), "HelloWorld")
  assert_eq(document.extract_all_text(), "HelloWorld")
}

///|
test "lib page_images returns images from CalRGB PDF" {
  let document = open(
    @fs.read_file_to_bytes("spec/pdf20examples/PDF 2.0 image with BPC.pdf"),
  )
  let mut image_count = 0
  let mut rgba_count = 0
  for page in document.pages() {
    for image in page.images() {
      image_count += 1
      let rgba = image.to_rgba()
      if rgba.length() == image.width() * image.height() * 4 {
        rgba_count += 1
      }
    }
  }
  if image_count < 1 {
    fail("expected at least one image, got " + image_count.to_string())
  }
  if rgba_count < 1 {
    fail("expected at least one RGBA image, got " + rgba_count.to_string())
  }
}

///|
test "lib document_title returns Info dictionary metadata" {
  let document = open(metadata_fixture_bytes())
  assert_eq(document_title(document), Some("Doc"))
  assert_eq(document.title(), Some("Doc"))
  assert_eq(document_author(document), Some("Writer"))
  assert_eq(document.page(0).width(), 612.0)
  assert_eq(document.page(0).height(), 792.0)
}

///|
test "lib outline returns bookmark title destination page and level" {
  let document = open(outline_fixture_bytes())
  let outline = document.outline()
  assert_eq(outline.length(), 1)
  assert_eq(outline[0].title, "Chapter 1")
  assert_eq(outline[0].destination_page_index, Some(0))
  assert_eq(outline[0].level, 0)
}

///|
test "lib capability and warning APIs return structured results" {
  let document = open(simple_pdf20_file_bytes())
  let report = document.check()
  if report.entries.length() == 0 {
    fail("expected capability report entries")
  }
  let (text, text_warnings) = document.page(0).extract_text_with_warnings()
  assert_eq(text, "HelloWorld")
  assert_eq(text_warnings.length(), 0)
  let (images, image_warnings) = document.page(0).images_with_warnings()
  assert_eq(images.length(), 0)
  assert_eq(image_warnings.length(), 0)
}

///|
fn simple_pdf20_file_bytes() -> Bytes raise {
  @fs.read_file_to_bytes("spec/pdf20examples/Simple PDF 2.0 file.pdf")
}

///|
fn metadata_fixture_bytes() -> Bytes {
  let header = b"%PDF-2.0\r\n%\x80\x80\x80\x80\r\n"
  let header_base = 0L
  let bytes = header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
  )
  let (bytes, info_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Title (Doc) /Author (Writer) /Subject (Spec) /Creator (Unit) >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(info_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R /Info 4 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn outline_fixture_bytes() -> Bytes {
  let header = b"%PDF-2.0\r\n%\x80\x80\x80\x80\r\n"
  let header_base = 0L
  let bytes = header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
  )
  let (bytes, empty_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< >>",
  )
  let (bytes, outlines_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /First 6 0 R /Last 6 0 R /Count 1 >>",
  )
  let (bytes, item_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Title (Chapter 1) /Parent 5 0 R /Dest [3 0 R /Fit] >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(empty_offset, 0, b'n') +
  xref_entry_line(outlines_offset, 0, b'n') +
  xref_entry_line(item_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
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
  Bytes::from_array([marker, b'\r', b'\n'])
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
  let mut index = digits.length() - 1
  while index >= 0 {
    out.push(digits[index])
    index = index - 1
  }
  Bytes::from_array(out)
}
