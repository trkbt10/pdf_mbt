///|
fn expect_valid_xref_table_section(input : Bytes) -> XrefSection raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_table_section(
    source, 0L,
  )
  match result {
    Ok(section) => section
    Err(_) => fail("expected valid xref table section")
  }
}

///|
fn expect_invalid_xref_table_section(
  input : Bytes,
  offset : Int64,
  reason_fragment : String,
) -> Unit raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_table_section(
    source, 0L,
  )
  match result {
    Err(InvalidXref(actual_offset, actual_reason)) => {
      assert_eq(actual_offset, offset)
      assert_eq(actual_reason.contains(reason_fragment), true)
    }
    _ => fail("expected invalid xref table error")
  }
}

///|
test "parse_xref_table_section parses multiple subsections and the trailing dictionary" {
  let input = b"xref\r\n" +
    b"0 2\r\n" +
    b"0000000000 65535 f\r\n" +
    b"0000000017 00000 n \n" +
    b"5 2\r\n" +
    b"0000000042 00007 n \r" +
    b"0000000099 00001 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 7 /Root 1 0 R >>"

  let section = expect_valid_xref_table_section(input)

  assert_eq(section.provenance.source == XrefSectionSource::Table, true)
  assert_eq(section.provenance.pdf_offset, 0L)
  assert_eq(section.entries.length(), 4)

  let entry0 = section.entries[0]
  assert_eq(entry0.object_number, 0)
  match entry0.entry {
    Free(next_free, generation) => {
      assert_eq(next_free, 0)
      assert_eq(generation, 65535)
    }
    _ => fail("expected free object 0 entry")
  }

  let entry1 = section.entries[1]
  assert_eq(entry1.object_number, 1)
  match entry1.entry {
    InUse(pdf_offset, generation) => {
      assert_eq(pdf_offset, 17L)
      assert_eq(generation, 0)
    }
    _ => fail("expected in-use entry for object 1")
  }

  let entry2 = section.entries[2]
  assert_eq(entry2.object_number, 5)
  match entry2.entry {
    InUse(pdf_offset, generation) => {
      assert_eq(pdf_offset, 42L)
      assert_eq(generation, 7)
    }
    _ => fail("expected in-use entry for object 5")
  }

  let entry3 = section.entries[3]
  assert_eq(entry3.object_number, 6)
  match entry3.entry {
    Free(next_free, generation) => {
      assert_eq(next_free, 99)
      assert_eq(generation, 1)
    }
    _ => fail("expected free entry for object 6")
  }

  assert_eq(section.trailer.size, 7)
  assert_eq(
    section.trailer.root ==
    @objects.ObjectId::{ object_number: 1, generation_number: 0 },
    true,
  )
  assert_eq(section.trailer.prev is None, true)
  assert_eq(section.trailer.encrypt is None, true)
  assert_eq(section.trailer.info is None, true)
  assert_eq(section.trailer.id is None, true)
  assert_eq(section.trailer.xref_stm is None, true)
}

///|
test "parse_xref_table_section rejects malformed rows and invalid object 0 entries" {
  let malformed_row = b"xref\n" +
    b"0 1\n" +
    b"0000000000 65535 f\n" +
    b"trailer\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(malformed_row, 9L, "row endings")

  let invalid_object_zero = b"xref\r\n" +
    b"0 1\r\n" +
    b"0000000001 65535 n\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(invalid_object_zero, 11L, "object 0")
}

///|
test "parse_xref_table_section rejects oversized subsection first object numbers" {
  let input = b"xref\r\n" +
    b"2147483648 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(
    input, 6L, "subsection header first object number",
  )
}

///|
test "parse_xref_table_section rejects oversized subsection entry counts" {
  let input = b"xref\r\n" +
    b"0 2147483648\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(input, 8L, "subsection header entry count")
}

///|
test "parse_xref_table_section rejects subsection object number ranges that overflow Int" {
  let input = b"xref\r\n" +
    b"2147483647 2\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(
    input, 6L, "xref subsection object numbers overflow Int",
  )
}

///|
test "parse_xref_table_section rejects oversized free next-object values" {
  let input = b"xref\r\n" +
    b"0 1\r\n" +
    b"2147483648 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(
    input, 11L, "xref free entry next object number",
  )
}

///|
test "parse_xref_table_section rejects comments between xref and trailer" {
  let input = b"xref\r\n" +
    b"0 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"% comment\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(input, 31L, "comment")
}

///|
test "parse_xref_table_section requires the xref keyword at the section offset" {
  let input = b"% comment\r\n" +
    b"0 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 1 /Root 1 0 R >>"
  expect_invalid_xref_table_section(input, 0L, "xref")
}
