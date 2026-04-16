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
fn expect_valid_merged_trailer(
  sections : Array[XrefSection],
) -> TrailerInfo raise {
  let result : Result[TrailerInfo, PdfReaderError] = try? resolve_merged_trailer(
    sections,
  )
  match result {
    Ok(trailer) => trailer
    Err(_) => fail("expected valid merged trailer")
  }
}

///|
test "resolve_merged_trailer takes root and info from first trailer that provides them" {
  let current = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"0 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Prev 128 >>",
  )
  let previous = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"0 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Root 2 0 R /Info 3 0 R >>",
  )

  let merged = expect_valid_merged_trailer([current, previous])
  let root_ref = @objects.ObjectId::{ object_number: 2, generation_number: 0 }
  let info_ref = @objects.ObjectId::{ object_number: 3, generation_number: 0 }

  assert_eq(merged.size, 4)
  assert_eq(merged.root == Some(root_ref), true)
  assert_eq(merged.info == Some(info_ref), true)
  assert_eq(merged.prev == Some(128L), true)
  assert_eq(
    merged.raw_dict.get(@objects.PdfName::new(b"Root")) ==
    Some(@objects.PdfObject::Ref(root_ref)),
    true,
  )
  assert_eq(
    merged.raw_dict.get(@objects.PdfName::new(b"Info")) ==
    Some(@objects.PdfObject::Ref(info_ref)),
    true,
  )
}

///|
test "resolve_merged_trailer rejects a chain without root" {
  let current = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"0 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 4 /Prev 128 >>",
  )
  let previous = expect_merged_xref_table_section(
    b"xref\r\n" +
    b"0 1\r\n" +
    b"0000000000 65535 f\r\n" +
    b"trailer\r\n" +
    b"<< /Size 4 >>",
  )

  let result : Result[TrailerInfo, PdfReaderError] = try? resolve_merged_trailer([
      current, previous,
    ],
  )
  match result {
    Err(InvalidTrailer(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason, "missing Root entry in trailer chain")
    }
    _ => fail("expected missing Root trailer-chain error")
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
