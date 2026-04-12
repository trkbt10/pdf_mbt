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
  assert_eq(trailer.root == root_ref, true)
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
  assert_eq(file.trailer().root == catalog_ref, true)

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
