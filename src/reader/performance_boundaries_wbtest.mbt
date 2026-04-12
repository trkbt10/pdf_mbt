///|
fn build_lazy_open_fixture() -> (Bytes, Int64) {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header
  let lazy_object_offset = object_offset(bytes, header_base)
  let (bytes, _) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R",
  )
  let xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 2\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(lazy_object_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 2 /Root 1 0 R >>\r\n" +
    b"startxref\r\n" +
    decimal_bytes(xref_offset) +
    b"\r\n%%EOF\r\n"
  (bytes, lazy_object_offset)
}

///|
fn build_large_xref_table_fixture(entry_count : Int) -> Bytes {
  let mut bytes = b"xref\r\n"
  bytes = bytes + b"0 " + decimal_bytes((entry_count + 1).to_int64()) + b"\r\n"
  bytes = bytes + xref_entry_line(0L, 65535, b'f')

  let mut object_number = 1
  while object_number <= entry_count {
    bytes = bytes + xref_entry_line(object_number.to_int64() * 12L, 0, b'n')
    object_number = object_number + 1
  }

  bytes = bytes +
    b"trailer\r\n" +
    b"<< /Size " +
    decimal_bytes((entry_count + 1).to_int64()) +
    b" /Root 1 0 R >>"
  bytes
}

///|
fn expect_large_xref_table_section(entry_count : Int) -> XrefSection raise {
  let source = ByteSource::new(build_large_xref_table_fixture(entry_count), 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_table_section(
    source, 0L,
  )
  match result {
    Ok(section) => section
    Err(_) => fail("expected valid large xref table section")
  }
}

///|
test "PdfFile::open stays structural before first object load" {
  let (bytes, object_offset) = build_lazy_open_fixture()
  let file = PdfFile::open(bytes)
  let object_id = @objects.ObjectId::{ object_number: 1, generation_number: 0 }

  assert_eq(file.cache.length(), 0)
  assert_eq(file.object_stream_tables.length(), 0)

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    object_id,
  )
  match result {
    Err(ParseObjectError(offset, _)) => assert_eq(offset, object_offset)
    _ => fail("expected lazy load to parse the malformed object only on demand")
  }
}

///|
test "PdfFile::load_object memoizes repeated loads from the same object" {
  let file = PdfFile::open(build_traditional_fixture())
  let object_id = @objects.ObjectId::{ object_number: 1, generation_number: 0 }

  let first = file.load_object(object_id)
  file.xref_index[object_id] = ObjectLocation::Uncompressed(9999L, 0)
  let second = file.load_object(object_id)

  assert_eq(first == second, true)
  assert_eq(file.cache.length(), 1)
  assert_eq(file.cache.get(object_id) == Some(first), true)
}

///|
test "PdfFile::load_object decodes each object stream container once" {
  let file = make_object_stream_file()
  let first_id = @objects.ObjectId::{ object_number: 10, generation_number: 0 }
  let second_id = @objects.ObjectId::{ object_number: 20, generation_number: 0 }
  let object_stream_id = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }

  let first = file.load_object(first_id)
  file.cache[object_stream_id] = @objects.PdfObject::Null
  file.xref_index[object_stream_id] = ObjectLocation::Uncompressed(9999L, 0)
  let second = file.load_object(second_id)

  assert_eq(file.object_stream_tables.length(), 1)
  assert_eq(file.cache.get(object_stream_id) is Some(_), true)
  assert_eq(file.cache.get(first_id) == Some(first), true)
  assert_eq(file.cache.get(second_id) == Some(second), true)
  assert_eq(file.cache.length(), 3)
}

///|
test "parse_xref_table_section handles a large fixed-width table" {
  let section = expect_large_xref_table_section(256)

  assert_eq(section.entries.length(), 257)
  assert_eq(section.entries[0].object_number, 0)
  assert_eq(section.entries[128].object_number, 128)
  assert_eq(section.entries[256].object_number, 256)

  match section.entries[0].entry {
    Free(next_free, generation) => {
      assert_eq(next_free, 0)
      assert_eq(generation, 65535)
    }
    _ => fail("expected free object 0 entry")
  }

  match section.entries[128].entry {
    InUse(pdf_offset, generation) => {
      assert_eq(pdf_offset, 1536L)
      assert_eq(generation, 0)
    }
    _ => fail("expected in-use entry in the middle of the table")
  }

  match section.entries[256].entry {
    InUse(pdf_offset, generation) => {
      assert_eq(pdf_offset, 3072L)
      assert_eq(generation, 0)
    }
    _ => fail("expected in-use entry at the end of the table")
  }
}
