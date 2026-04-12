///|
fn expect_merged_xref_table_section(input : Bytes) -> XrefSection raise {
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
fn expect_merged_xref_stream_section(
  input : Bytes,
  version : PdfVersion,
) -> XrefSection raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_stream_section(
    source, 0L, version,
  )
  match result {
    Ok(section) => section
    Err(_) => fail("expected valid xref stream section")
  }
}

///|
fn expect_valid_merged_xref_index(
  sections : Array[XrefSection],
) -> XrefIndex raise {
  let result : Result[XrefIndex, PdfReaderError] = try? merge_sections(sections)
  match result {
    Ok(index) => index
    Err(_) => fail("expected valid merged xref index")
  }
}

///|
test "merge_sections keeps higher-priority parsed entries and drops free winners" {
  let current_table = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"0 4\r\n" +
    b"0000000000 65535 f\r\n" +
    b"0000000010 00000 n \n" +
    b"0000000000 00000 f\r\n" +
    b"0000000030 00002 n \n" +
    b"trailer\r\n" +
    b"<< /Size 5 /Root 1 0 R >>",
  )
  let previous_stream = expect_merged_xref_stream_section(
    b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 5 /W [1 2 2] /Root 1 0 R /Length 25 >>\r\n" +
    b"stream\r\n" +
    b"\x00\x00\x00\xff\xff" +
    b"\x01\x00\x2a\x00\x00" +
    b"\x02\x00\x07\x00\x01" +
    b"\x01\x00\x4d\x00\x02" +
    b"\x02\x00\x09\x00\x03" +
    b"\r\nendstream endobj",
    PdfVersion::{ major: 1, minor: 7 },
  )

  let merged = expect_valid_merged_xref_index([current_table, previous_stream])

  assert_eq(merged.length(), 3)
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 1, generation_number: 0 }) ==
    Some(ObjectLocation::Uncompressed(10L, 0)),
    true,
  )
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 2, generation_number: 0 })
    is None,
    true,
  )
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 3, generation_number: 2 }) ==
    Some(ObjectLocation::Uncompressed(30L, 2)),
    true,
  )
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 4, generation_number: 0 }) ==
    Some(ObjectLocation::Compressed(9, 3)),
    true,
  )
}

///|
test "merge_sections ignores entries above the section size" {
  let section = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"0 3\r\n" +
    b"0000000000 65535 f\r\n" +
    b"0000000010 00000 n \n" +
    b"0000000050 00000 n \n" +
    b"trailer\r\n" +
    b"<< /Size 2 /Root 1 0 R >>",
  )

  let merged = expect_valid_merged_xref_index([section])

  assert_eq(merged.length(), 1)
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 1, generation_number: 0 }) ==
    Some(ObjectLocation::Uncompressed(10L, 0)),
    true,
  )
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 2, generation_number: 0 })
    is None,
    true,
  )
}

///|
test "merge_sections lets a newer free entry block older generations of the same object number" {
  let newer_free_section = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"3 1\r\n" +
    b"0000000000 00001 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Root 1 0 R >>",
  )
  let older_in_use_section = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"3 1\r\n" +
    b"0000000010 00000 n \n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Root 1 0 R >>",
  )

  let merged = expect_valid_merged_xref_index([
    newer_free_section, older_in_use_section,
  ])

  assert_eq(merged.length(), 0)
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 3, generation_number: 1 })
    is None,
    true,
  )
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 3, generation_number: 0 })
    is None,
    true,
  )
}

///|
test "merge_sections keeps the newest in-use generation and ignores older generations" {
  let newer_in_use_section = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"3 1\r\n" +
    b"0000000020 00001 n \n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Root 1 0 R >>",
  )
  let older_in_use_section = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"3 1\r\n" +
    b"0000000010 00000 n \n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Root 1 0 R >>",
  )

  let merged = expect_valid_merged_xref_index([
    newer_in_use_section, older_in_use_section,
  ])

  assert_eq(merged.length(), 1)
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 3, generation_number: 1 }) ==
    Some(ObjectLocation::Uncompressed(20L, 1)),
    true,
  )
  assert_eq(
    merged.resolve(@objects.ObjectId::{ object_number: 3, generation_number: 0 })
    is None,
    true,
  )
}
