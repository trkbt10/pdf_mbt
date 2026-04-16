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

///|
fn fixed_width_decimal(value : Int64, width : Int) -> Bytes {
  let digits = decimal_bytes(value)
  let out : Array[Byte] = []
  let mut padding = width - digits.length()
  while padding > 0 {
    out.push(b'0')
    padding = padding - 1
  }

  let mut index = 0
  while index < digits.length() {
    out.push(digits[index])
    index = index + 1
  }
  Bytes::from_array(out)
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
fn object_offset(bytes : Bytes, header_base : Int64) -> Int64 {
  bytes.length().to_int64() - header_base
}

///|
fn append_initial_objects(
  bytes : Bytes,
  header_base : Int64,
) -> (Bytes, Int64, Int64, Int64, Int64, Int64) {
  let catalog_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"1 0 obj\n" +
    b"<< /Type /Catalog /Pages 2 0 R /Metadata 5 0 R >>\n" +
    b"endobj\n"

  let pages_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"2 0 obj\n" +
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n" +
    b"endobj\n"

  let page_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"3 0 obj\n" +
    b"<< /Type /Page /Parent 2 0 R /Contents 4 0 R /MediaBox [0 0 612 792] >>\n" +
    b"endobj\n"

  let content_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"4 0 obj\n" +
    b"<< /Length 5 >>\n" +
    b"stream\n" +
    b"Hello\n" +
    b"endstream\n" +
    b"endobj\n"

  let metadata_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"5 0 obj\n" +
    b"<< /Type /Metadata /Subtype /XML /Length 7 >>\n" +
    b"stream\n" +
    b"<meta/>\n" +
    b"endstream\n" +
    b"endobj\n"

  (
    bytes, catalog_offset, pages_offset, page_offset, content_offset, metadata_offset,
  )
}

///|
fn build_traditional_fixture() -> Bytes {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header
  let (
    bytes,
    catalog_offset,
    pages_offset,
    page_offset,
    content_offset,
    metadata_offset,
  ) = append_initial_objects(bytes, header_base)

  let xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 6\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(catalog_offset, 0, b'n') +
    xref_entry_line(pages_offset, 0, b'n') +
    xref_entry_line(page_offset, 0, b'n') +
    xref_entry_line(content_offset, 0, b'n') +
    xref_entry_line(metadata_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 6 /Root 1 0 R >>\r\n" +
    b"startxref\r\n" +
    decimal_bytes(xref_offset) +
    b"\r\n%%EOF\r\n"
  bytes
}

///|
fn build_incremental_fixture() -> Bytes {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header
  let (
    bytes,
    catalog_offset,
    pages_offset,
    page_offset,
    content_offset,
    metadata_offset,
  ) = append_initial_objects(bytes, header_base)

  let first_xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 6\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(catalog_offset, 0, b'n') +
    xref_entry_line(pages_offset, 0, b'n') +
    xref_entry_line(page_offset, 0, b'n') +
    xref_entry_line(content_offset, 0, b'n') +
    xref_entry_line(metadata_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 6 /Root 1 0 R >>\r\n"

  let updated_content_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"4 0 obj\n" +
    b"<< /Length 3 >>\n" +
    b"stream\n" +
    b"Bye\n" +
    b"endstream\n" +
    b"endobj\n"

  let second_xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"4 2\r\n" +
    xref_entry_line(updated_content_offset, 0, b'n') +
    xref_entry_line(0L, 1, b'f') +
    b"trailer\r\n" +
    b"<< /Size 6 /Root 1 0 R /Prev " +
    decimal_bytes(first_xref_offset) +
    b" >>\r\n" +
    b"startxref\r\n" +
    decimal_bytes(second_xref_offset) +
    b"\r\n%%EOF\r\n"
  bytes
}

///|
fn build_rootless_final_trailer_fixture() -> Bytes {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, linearization_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Linearized 1 /L 0 /H [0 0] /O 2 /E 0 /N 1 /T 0 >>",
  )
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Catalog /Pages 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 3 0 R /Contents 5 0 R /MediaBox [0 0 72 72] >>",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    build_stream_object_body(b"<< /Length 2 >>", b"OK"),
  )
  let (bytes, info_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Producer (synthetic) >>",
  )

  let first_xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 7\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(linearization_offset, 0, b'n') +
    xref_entry_line(catalog_offset, 0, b'n') +
    xref_entry_line(pages_offset, 0, b'n') +
    xref_entry_line(page_offset, 0, b'n') +
    xref_entry_line(content_offset, 0, b'n') +
    xref_entry_line(info_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 7 /Root 2 0 R /Info 6 0 R >>\r\n"

  let final_xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 1\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    b"trailer\r\n" +
    b"<< /Size 7 /Prev " +
    decimal_bytes(first_xref_offset) +
    b" >>\r\n" +
    b"startxref\r\n" +
    decimal_bytes(final_xref_offset) +
    b"\r\n%%EOF\r\n"
  bytes
}

///|
fn bytes_to_u16_be(value : Int) -> Bytes {
  Bytes::from_array([(value / 256).to_byte(), (value % 256).to_byte()])
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
fn build_stream_object_body(dict : Bytes, data : Bytes) -> Bytes {
  dict + b"\r\nstream\r\n" + data + b"\r\nendstream"
}

///|
fn xref_stream_entry_bytes(
  entry_type : Int,
  field2 : Int,
  field3 : Int,
) -> Bytes {
  Bytes::from_array([entry_type.to_byte()]) +
  bytes_to_u16_be(field2) +
  bytes_to_u16_be(field3)
}

///|
fn build_hybrid_reference_fixture() -> Bytes {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog >>",
  )
  let (bytes, prev_current_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"(Prev)",
  )
  let (bytes, prev_stream_offset) = append_indirect_object(
    bytes, header_base, 20, 0, b"(Prev20)",
  )
  let (bytes, prev_only_offset) = append_indirect_object(
    bytes, header_base, 30, 0, b"(Prev30)",
  )

  let prev_xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"10 1\r\n" +
    xref_entry_line(prev_current_offset, 0, b'n') +
    b"20 1\r\n" +
    xref_entry_line(prev_stream_offset, 0, b'n') +
    b"30 1\r\n" +
    xref_entry_line(prev_only_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 31 /Root 1 0 R >>\r\n"

  let (bytes, stream_current_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"(Stream)",
  )
  let (bytes, stream_only_offset) = append_indirect_object(
    bytes, header_base, 20, 0, b"(Stream20)",
  )

  let xref_stream_offset = object_offset(bytes, header_base)
  let xref_stream_data = xref_stream_entry_bytes(
      1,
      stream_current_offset.to_int(),
      0,
    ) +
    xref_stream_entry_bytes(1, stream_only_offset.to_int(), 0)
  let xref_stream_body = build_stream_object_body(
    b"<< /Type /XRef /Size 31 /Index [10 1 20 1] /W [1 2 2] /Root 1 0 R /Length " +
    decimal_bytes(xref_stream_data.length().to_int64()) +
    b" >>",
    xref_stream_data,
  )
  let (bytes, _) = append_indirect_object(
    bytes, header_base, 11, 0, xref_stream_body,
  )

  let (bytes, current_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"(Current)",
  )

  let current_xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 2\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(catalog_offset, 0, b'n') +
    b"10 1\r\n" +
    xref_entry_line(current_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 31 /Root 1 0 R /XRefStm " +
    decimal_bytes(xref_stream_offset) +
    b" /Prev " +
    decimal_bytes(prev_xref_offset) +
    b" >>\r\n" +
    b"startxref\r\n" +
    decimal_bytes(current_xref_offset) +
    b"\r\n%%EOF\r\n"
  bytes
}

///|
fn build_object_stream_fixture() -> Bytes {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog >>",
  )
  let (bytes, object_stream_offset) = append_indirect_object(
    bytes,
    header_base,
    9,
    0,
    build_stream_object_body(
      b"<< /Type /ObjStm /N 2 /First 10 /Length 22 >>", b"40 0 41 2 1 << /A 1 >>",
    ),
  )

  let xref_stream_offset = object_offset(bytes, header_base)
  let xref_stream_data = xref_stream_entry_bytes(1, catalog_offset.to_int(), 0) +
    xref_stream_entry_bytes(1, object_stream_offset.to_int(), 0) +
    xref_stream_entry_bytes(2, 9, 0) +
    xref_stream_entry_bytes(2, 9, 1) +
    xref_stream_entry_bytes(2, 9, 2)
  let xref_stream_body = build_stream_object_body(
    b"<< /Type /XRef /Size 43 /Index [1 1 9 1 40 3] /W [1 2 2] /Root 1 0 R /Length " +
    decimal_bytes(xref_stream_data.length().to_int64()) +
    b" >>",
    xref_stream_data,
  )
  let (bytes, _) = append_indirect_object(
    bytes, header_base, 11, 0, xref_stream_body,
  )

  let startxref_offset = xref_stream_offset
  let bytes = bytes +
    b"startxref\r\n" +
    decimal_bytes(startxref_offset) +
    b"\r\n%%EOF\r\n"
  bytes
}

///|
fn build_pdf2_fixture_prefix() -> (Bytes, Int64) {
  let prefix = b"garbage\n"
  let header = b"%PDF-2.0\r\n"
  let binary_indicator = b"%\x80\x80\x80\x80\r\n"
  (prefix + header + binary_indicator, prefix.length().to_int64())
}

///|
fn build_annex_content_stream_data() -> Bytes {
  b"q\nQ\n"
}

///|
fn build_annex_h3_content_stream_data() -> Bytes {
  b"BT\n" +
  b"/F1 24 Tf\n" +
  b"72 696 Td\n" +
  b"(Hello ) Tj\n" +
  b"/F2 24 Tf\n" +
  b"(32000-2) Tj\n" +
  b"/F1 24 Tf\n" +
  b"156.1 0 Td\n" +
  b"(Wor) Tj\n" +
  b"(ld) Tj\n" +
  b"ET\n"
}

///|
fn build_metadata_stream_data(producer : Bytes, creator_tool : Bytes) -> Bytes {
  b"<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n" +
  b"<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n" +
  b"<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n" +
  b"<rdf:Description rdf:about=\"\" xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\">\n" +
  b"<pdf:Producer>" +
  producer +
  b"</pdf:Producer>\n" +
  b"</rdf:Description>\n" +
  b"<rdf:Description rdf:about=\"\" xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\">\n" +
  b"<xmp:CreatorTool>" +
  creator_tool +
  b"</xmp:CreatorTool>\n" +
  b"</rdf:Description>\n" +
  b"</rdf:RDF>\n" +
  b"</x:xmpmeta>\n" +
  b"<?xpacket end=\"w\"?>"
}

///|
fn build_annex_h2_fixture() -> Bytes {
  let (bytes, header_base) = build_pdf2_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Metadata 5 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
  )
  let content_stream_data = build_annex_content_stream_data()
  let (bytes, content_offset) = append_indirect_object(
    bytes,
    header_base,
    4,
    0,
    build_stream_object_body(
      b"<< /Length " +
      decimal_bytes(content_stream_data.length().to_int64()) +
      b" >>",
      content_stream_data,
    ),
  )
  let metadata_stream_data = build_metadata_stream_data(
    b"Annex H.2 Producer", b"Annex H.2 Tool",
  )
  let (bytes, metadata_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    build_stream_object_body(
      b"<< /Type /Metadata /Subtype /XML /Length " +
      decimal_bytes(metadata_stream_data.length().to_int64()) +
      b" >>",
      metadata_stream_data,
    ),
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 6\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(content_offset, 0, b'n') +
  xref_entry_line(metadata_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 6 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_annex_h3_fixture() -> Bytes {
  let (bytes, header_base) = build_pdf2_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Metadata 7 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources <</Font <</F1 5 0 R /F2 6 0 R>> >> >>",
  )
  let content_stream_data = build_annex_h3_content_stream_data()
  let (bytes, content_offset) = append_indirect_object(
    bytes,
    header_base,
    4,
    0,
    build_stream_object_body(
      b"<< /Length " +
      decimal_bytes(content_stream_data.length().to_int64()) +
      b" >>",
      content_stream_data,
    ),
  )
  let (bytes, font1_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
  )
  let (bytes, font2_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>",
  )
  let metadata_stream_data = build_metadata_stream_data(
    b"Annex H.3 Producer", b"Annex H.3 Tool",
  )
  let (bytes, metadata_offset) = append_indirect_object(
    bytes,
    header_base,
    7,
    0,
    build_stream_object_body(
      b"<< /Type /Metadata /Subtype /XML /Length " +
      decimal_bytes(metadata_stream_data.length().to_int64()) +
      b" >>",
      metadata_stream_data,
    ),
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 8\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(content_offset, 0, b'n') +
  xref_entry_line(font1_offset, 0, b'n') +
  xref_entry_line(font2_offset, 0, b'n') +
  xref_entry_line(metadata_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 8 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
test "PdfFile::open reads a synthetic traditional table file end to end" {
  let file = PdfFile::open(build_traditional_fixture())
  let trailer = file.trailer()
  let root_ref = file.root_ref()
  let catalog_ref = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let pages_ref = @objects.ObjectId::{ object_number: 2, generation_number: 0 }
  let page_ref = @objects.ObjectId::{ object_number: 3, generation_number: 0 }
  let content_ref = @objects.ObjectId::{
    object_number: 4,
    generation_number: 0,
  }
  let metadata_ref = @objects.ObjectId::{
    object_number: 5,
    generation_number: 0,
  }

  assert_eq(file.version() == PdfVersion::{ major: 1, minor: 7 }, true)
  assert_eq(trailer.size, 6)
  assert_eq(trailer.root == Some(root_ref), true)
  assert_eq(root_ref == catalog_ref, true)

  let catalog = file.load_object(catalog_ref)
  let pages = file.load_object(pages_ref)
  let page = file.load_object(page_ref)
  let content = file.load_object(content_ref)
  let metadata = file.load_object(metadata_ref)

  match catalog {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(@objects.PdfObject::Ref(pages_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Metadata")) ==
        Some(@objects.PdfObject::Ref(metadata_ref)),
        true,
      )
    }
    _ => fail("expected catalog dictionary")
  }

  match pages {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Pages"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Count")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
      match dict.get(@objects.PdfName::new(b"Kids")) {
        Some(@objects.PdfObject::Array(kids)) => {
          assert_eq(kids.length(), 1)
          assert_eq(kids[0] == @objects.PdfObject::Ref(page_ref), true)
        }
        _ => fail("expected page kids array")
      }
    }
    _ => fail("expected pages dictionary")
  }

  match page {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Page"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Parent")) ==
        Some(@objects.PdfObject::Ref(pages_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Contents")) ==
        Some(@objects.PdfObject::Ref(content_ref)),
        true,
      )
    }
    _ => fail("expected page dictionary")
  }

  match content {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(stream.data, b"Hello")
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Length")) ==
        Some(@objects.PdfObject::Integer(5L)),
        true,
      )
    }
    _ => fail("expected content stream")
  }

  match metadata {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(stream.data, b"<meta/>")
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Metadata"))),
        true,
      )
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Subtype")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"XML"))),
        true,
      )
    }
    _ => fail("expected metadata stream")
  }

  assert_eq(file.load_object(catalog_ref) == catalog, true)
  assert_eq(
    file.load_object(@objects.ObjectId::{
      object_number: 99,
      generation_number: 0,
    }) ==
    @objects.PdfObject::Null,
    true,
  )
}

///|
test "PdfFile::open merges incremental updates and keeps deleted objects null" {
  let file = PdfFile::open(build_incremental_fixture())
  let catalog_ref = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let pages_ref = @objects.ObjectId::{ object_number: 2, generation_number: 0 }
  let page_ref = @objects.ObjectId::{ object_number: 3, generation_number: 0 }
  let content_ref = @objects.ObjectId::{
    object_number: 4,
    generation_number: 0,
  }
  let metadata_ref = @objects.ObjectId::{
    object_number: 5,
    generation_number: 0,
  }

  assert_eq(file.version() == PdfVersion::{ major: 1, minor: 7 }, true)
  assert_eq(file.root_ref() == catalog_ref, true)
  assert_eq(file.trailer().root == Some(catalog_ref), true)

  match file.load_object(catalog_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(@objects.PdfObject::Ref(pages_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Metadata")) ==
        Some(@objects.PdfObject::Ref(metadata_ref)),
        true,
      )
    }
    _ => fail("expected catalog dictionary")
  }

  match file.load_object(pages_ref) {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"Kids")) ==
        Some(@objects.PdfObject::Array([@objects.PdfObject::Ref(page_ref)])),
        true,
      )
    _ => fail("expected pages dictionary")
  }

  match file.load_object(page_ref) {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"Contents")) ==
        Some(@objects.PdfObject::Ref(content_ref)),
        true,
      )
    _ => fail("expected page dictionary")
  }

  match file.load_object(content_ref) {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(stream.data, b"Bye")
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Length")) ==
        Some(@objects.PdfObject::Integer(3L)),
        true,
      )
    }
    _ => fail("expected updated content stream")
  }

  assert_eq(file.load_object(metadata_ref) == @objects.PdfObject::Null, true)
  assert_eq(
    file.load_object(@objects.ObjectId::{
      object_number: 99,
      generation_number: 0,
    }) ==
    @objects.PdfObject::Null,
    true,
  )
}

///|
test "PdfFile::open resolves root and info through a rootless final trailer" {
  let file = PdfFile::open(build_rootless_final_trailer_fixture())
  let catalog_ref = @objects.ObjectId::{
    object_number: 2,
    generation_number: 0,
  }
  let info_ref = @objects.ObjectId::{ object_number: 6, generation_number: 0 }
  let trailer = file.trailer()

  assert_eq(file.sections[0].trailer.root is None, true)
  assert_eq(file.root_ref() == catalog_ref, true)
  assert_eq(trailer.root == Some(catalog_ref), true)
  assert_eq(trailer.info == Some(info_ref), true)
  assert_eq(
    trailer.raw_dict.get(@objects.PdfName::new(b"Root")) ==
    Some(@objects.PdfObject::Ref(catalog_ref)),
    true,
  )

  match file.load_object(catalog_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(
          @objects.PdfObject::Ref(@objects.ObjectId::{
            object_number: 3,
            generation_number: 0,
          }),
        ),
        true,
      )
    }
    _ => fail("expected resolved catalog dictionary")
  }
}

///|
test "PdfFile::open respects hybrid xref priority from current table to xref stream to prev" {
  let file = PdfFile::open(build_hybrid_reference_fixture())
  let root_ref = @objects.ObjectId::{ object_number: 1, generation_number: 0 }
  let current_ref = @objects.ObjectId::{
    object_number: 10,
    generation_number: 0,
  }
  let stream_ref = @objects.ObjectId::{
    object_number: 20,
    generation_number: 0,
  }
  let prev_ref = @objects.ObjectId::{ object_number: 30, generation_number: 0 }

  assert_eq(file.root_ref() == root_ref, true)
  match file.load_object(root_ref) {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
    _ => fail("expected catalog dictionary")
  }

  assert_eq(
    file.load_object(current_ref) == @objects.PdfObject::String(b"Current"),
    true,
  )
  assert_eq(
    file.load_object(stream_ref) == @objects.PdfObject::String(b"Stream20"),
    true,
  )
  assert_eq(
    file.load_object(prev_ref) == @objects.PdfObject::String(b"Prev30"),
    true,
  )
}

///|
test "PdfFile::open resolves compressed xref stream members and rejects invalid indexes" {
  let file = PdfFile::open(build_object_stream_fixture())
  let catalog_ref = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let first_ref = @objects.ObjectId::{ object_number: 40, generation_number: 0 }
  let second_ref = @objects.ObjectId::{
    object_number: 41,
    generation_number: 0,
  }
  let invalid_ref = @objects.ObjectId::{
    object_number: 42,
    generation_number: 0,
  }

  assert_eq(file.root_ref() == catalog_ref, true)
  match file.load_object(catalog_ref) {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
    _ => fail("expected catalog dictionary")
  }

  assert_eq(
    file.load_object(first_ref) == @objects.PdfObject::Integer(1L),
    true,
  )
  match file.load_object(second_ref) {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"A")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    _ => fail("expected object stream dictionary member")
  }

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    invalid_ref,
  )
  match result {
    Err(InvalidObjectStream(_, reason)) =>
      assert_eq(reason.contains("index"), true)
    _ => fail("expected invalid compressed member index")
  }
}

///|
/// Validates ISO 32000-2 Annex H sample coverage for the Annex H.2 minimal PDF:
/// Catalog, Pages, Page, Content stream, and Metadata are accessed through
/// public APIs.
test "PdfFile::open reads Annex H.2 fixtures through public APIs" {
  let file = PdfFile::open(build_annex_h2_fixture())
  let trailer = file.trailer()
  let catalog_ref = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let pages_ref = @objects.ObjectId::{ object_number: 2, generation_number: 0 }
  let page_ref = @objects.ObjectId::{ object_number: 3, generation_number: 0 }
  let content_ref = @objects.ObjectId::{
    object_number: 4,
    generation_number: 0,
  }
  let metadata_ref = @objects.ObjectId::{
    object_number: 5,
    generation_number: 0,
  }

  assert_eq(file.version() == PdfVersion::{ major: 2, minor: 0 }, true)
  assert_eq(file.root_ref() == catalog_ref, true)
  assert_eq(trailer.size, 6)

  match file.load_object(catalog_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(@objects.PdfObject::Ref(pages_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Metadata")) ==
        Some(@objects.PdfObject::Ref(metadata_ref)),
        true,
      )
    }
    _ => fail("expected Annex H.2 catalog dictionary")
  }

  match file.load_object(pages_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Pages"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Kids")) ==
        Some(@objects.PdfObject::Array([@objects.PdfObject::Ref(page_ref)])),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Count")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    }
    _ => fail("expected Annex H.2 pages dictionary")
  }

  match file.load_object(page_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Page"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Parent")) ==
        Some(@objects.PdfObject::Ref(pages_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Contents")) ==
        Some(@objects.PdfObject::Ref(content_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"MediaBox")) ==
        Some(
          @objects.PdfObject::Array([
            @objects.PdfObject::Integer(0L),
            @objects.PdfObject::Integer(0L),
            @objects.PdfObject::Integer(612L),
            @objects.PdfObject::Integer(792L),
          ]),
        ),
        true,
      )
    }
    _ => fail("expected Annex H.2 page dictionary")
  }

  match file.load_object(content_ref) {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(stream.data, build_annex_content_stream_data())
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Length")) ==
        Some(@objects.PdfObject::Integer(4L)),
        true,
      )
    }
    _ => fail("expected Annex H.2 content stream")
  }

  match file.load_object(metadata_ref) {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Metadata"))),
        true,
      )
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Subtype")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"XML"))),
        true,
      )
      assert_eq(
        stream.data,
        build_metadata_stream_data(b"Annex H.2 Producer", b"Annex H.2 Tool"),
      )
    }
    _ => fail("expected Annex H.2 metadata stream")
  }
}

///|
/// Continues ISO 32000-2 Annex H sample validation with the text example's
/// Pages tree, font resources, Content stream, and Metadata access.
test "PdfFile::open reads Annex H.3 resources and text stream objects" {
  let file = PdfFile::open(build_annex_h3_fixture())
  let trailer = file.trailer()
  let catalog_ref = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let pages_ref = @objects.ObjectId::{ object_number: 2, generation_number: 0 }
  let page_ref = @objects.ObjectId::{ object_number: 3, generation_number: 0 }
  let content_ref = @objects.ObjectId::{
    object_number: 4,
    generation_number: 0,
  }
  let font1_ref = @objects.ObjectId::{ object_number: 5, generation_number: 0 }
  let font2_ref = @objects.ObjectId::{ object_number: 6, generation_number: 0 }
  let metadata_ref = @objects.ObjectId::{
    object_number: 7,
    generation_number: 0,
  }

  assert_eq(file.version() == PdfVersion::{ major: 2, minor: 0 }, true)
  assert_eq(file.root_ref() == catalog_ref, true)
  assert_eq(trailer.size, 8)

  match file.load_object(catalog_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(@objects.PdfObject::Ref(pages_ref)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Metadata")) ==
        Some(@objects.PdfObject::Ref(metadata_ref)),
        true,
      )
    }
    _ => fail("expected Annex H.3 catalog dictionary")
  }

  match file.load_object(pages_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Kids")) ==
        Some(@objects.PdfObject::Array([@objects.PdfObject::Ref(page_ref)])),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Count")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    }
    _ => fail("expected Annex H.3 pages dictionary")
  }

  match file.load_object(page_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Contents")) ==
        Some(@objects.PdfObject::Ref(content_ref)),
        true,
      )
      match dict.get(@objects.PdfName::new(b"Resources")) {
        Some(@objects.PdfObject::Dictionary(resources)) =>
          match resources.get(@objects.PdfName::new(b"Font")) {
            Some(@objects.PdfObject::Dictionary(fonts)) => {
              assert_eq(
                fonts.get(@objects.PdfName::new(b"F1")) ==
                Some(@objects.PdfObject::Ref(font1_ref)),
                true,
              )
              assert_eq(
                fonts.get(@objects.PdfName::new(b"F2")) ==
                Some(@objects.PdfObject::Ref(font2_ref)),
                true,
              )
            }
            _ => fail("expected Annex H.3 font resource dictionary")
          }
        _ => fail("expected Annex H.3 resources dictionary")
      }
    }
    _ => fail("expected Annex H.3 page dictionary")
  }

  match file.load_object(content_ref) {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(stream.data, build_annex_h3_content_stream_data())
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Length")) ==
        Some(
          @objects.PdfObject::Integer(
            build_annex_h3_content_stream_data().length().to_int64(),
          ),
        ),
        true,
      )
    }
    _ => fail("expected Annex H.3 content stream")
  }

  match file.load_object(font1_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Font"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Subtype")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Type1"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"BaseFont")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Helvetica"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Encoding")) ==
        Some(
          @objects.PdfObject::Name(@objects.PdfName::new(b"WinAnsiEncoding")),
        ),
        true,
      )
    }
    _ => fail("expected Annex H.3 first font dictionary")
  }

  match file.load_object(font2_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Font"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Subtype")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Type1"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"BaseFont")) ==
        Some(
          @objects.PdfObject::Name(@objects.PdfName::new(b"Helvetica-Oblique")),
        ),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Encoding")) ==
        Some(
          @objects.PdfObject::Name(@objects.PdfName::new(b"WinAnsiEncoding")),
        ),
        true,
      )
    }
    _ => fail("expected Annex H.3 second font dictionary")
  }

  match file.load_object(metadata_ref) {
    @objects.PdfObject::Stream(stream) => {
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Metadata"))),
        true,
      )
      assert_eq(
        stream.dict.get(@objects.PdfName::new(b"Subtype")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"XML"))),
        true,
      )
      assert_eq(
        stream.data,
        build_metadata_stream_data(b"Annex H.3 Producer", b"Annex H.3 Tool"),
      )
    }
    _ => fail("expected Annex H.3 metadata stream")
  }
}
