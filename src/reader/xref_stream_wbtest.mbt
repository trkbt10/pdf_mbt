///|
fn expect_valid_xref_stream_section(
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
fn expect_invalid_xref_stream_section(
  input : Bytes,
  version : PdfVersion,
  reason_fragment : String,
) -> Unit raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_stream_section(
    source, 0L, version,
  )
  match result {
    Err(InvalidXref(_, reason)) =>
      assert_eq(reason.contains(reason_fragment), true)
    _ => fail("expected invalid xref stream error")
  }
}

///|
fn expect_unsupported_xref_stream_section(
  input : Bytes,
  version : PdfVersion,
  reason_fragment : String,
) -> Unit raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_stream_section(
    source, 0L, version,
  )
  match result {
    Err(UnsupportedFilter(_, reason)) =>
      assert_eq(reason.contains(reason_fragment), true)
    _ => fail("expected unsupported xref stream rejection")
  }
}

///|
fn find_xref_stream_entry(
  entries : Array[XrefSectionEntry],
  object_number : Int,
) -> XrefSectionEntry? {
  for entry in entries {
    if entry.object_number == object_number {
      return Some(entry)
    }
  }
  None
}

///|
test "parse_xref_stream_section decodes W widths, explicit Index, and supported entry types" {
  let input = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 3 /W [1 2 1] /Index [0 3] /Root 1 0 R /Length 12 >>\r\n" +
    b"stream\r\n" +
    b"\x00\x00\x05\x07\x01\x01\x2c\x02\x02\x00\x09\x03" +
    b"\r\nendstream endobj"

  let section = expect_valid_xref_stream_section(input, PdfVersion::{
    major: 1,
    minor: 7,
  })

  assert_eq(section.provenance.source == XrefSectionSource::Stream, true)
  assert_eq(section.provenance.pdf_offset, 0L)
  assert_eq(section.entries.length(), 3)
  assert_eq(section.trailer.size, 3)
  assert_eq(
    section.trailer.root ==
    Some(@objects.ObjectId::{ object_number: 1, generation_number: 0 }),
    true,
  )

  match find_xref_stream_entry(section.entries, 0) {
    Some(entry) =>
      match entry.entry {
        Free(next_free, generation) => {
          assert_eq(next_free, 5)
          assert_eq(generation, 7)
        }
        _ => fail("expected free xref entry")
      }
    None => fail("expected object 0 xref entry")
  }

  match find_xref_stream_entry(section.entries, 1) {
    Some(entry) =>
      match entry.entry {
        InUse(pdf_offset, generation) => {
          assert_eq(pdf_offset, 300L)
          assert_eq(generation, 2)
        }
        _ => fail("expected in-use xref entry")
      }
    None => fail("expected object 1 xref entry")
  }

  match find_xref_stream_entry(section.entries, 2) {
    Some(entry) =>
      match entry.entry {
        Compressed(object_stream_number, index) => {
          assert_eq(object_stream_number, 9)
          assert_eq(index, 3)
        }
        _ => fail("expected compressed xref entry")
      }
    None => fail("expected object 2 xref entry")
  }
}

///|
test "parse_xref_stream_section decodes Flate compressed xref entries" {
  let input = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 3 /W [1 2 1] /Index [0 3] /Root 1 0 R /Filter /FlateDecode /Length 20 >>\r\n" +
    b"stream\r\n" +
    b"\x78\x9c\x63\x60\x60\x65\x67\x64\xd4\x61\x62\x62\xe0\x64\x06\x00\x01\xbb\x00\x4b" +
    b"\r\nendstream endobj"

  let section = expect_valid_xref_stream_section(input, PdfVersion::{
    major: 1,
    minor: 7,
  })

  assert_eq(section.entries.length(), 3)

  match find_xref_stream_entry(section.entries, 0) {
    Some(entry) =>
      match entry.entry {
        Free(next_free, generation) => {
          assert_eq(next_free, 5)
          assert_eq(generation, 7)
        }
        _ => fail("expected free xref entry")
      }
    None => fail("expected object 0 xref entry")
  }

  match find_xref_stream_entry(section.entries, 1) {
    Some(entry) =>
      match entry.entry {
        InUse(pdf_offset, generation) => {
          assert_eq(pdf_offset, 300L)
          assert_eq(generation, 2)
        }
        _ => fail("expected in-use xref entry")
      }
    None => fail("expected object 1 xref entry")
  }

  match find_xref_stream_entry(section.entries, 2) {
    Some(entry) =>
      match entry.entry {
        Compressed(object_stream_number, index) => {
          assert_eq(object_stream_number, 9)
          assert_eq(index, 3)
        }
        _ => fail("expected compressed xref entry")
      }
    None => fail("expected object 2 xref entry")
  }
}

///|
test "parse_xref_stream_section defaults the index range and entry type when W[0] is zero" {
  let input = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 2 /W [0 2 1] /Root 1 0 R /Length 6 >>\r\n" +
    b"stream\r\n" +
    b"\x01\x02\x03\x00\x04\x05" +
    b"\r\nendstream endobj"

  let section = expect_valid_xref_stream_section(input, PdfVersion::{
    major: 1,
    minor: 7,
  })

  assert_eq(section.entries.length(), 2)

  match find_xref_stream_entry(section.entries, 0) {
    Some(entry) =>
      match entry.entry {
        InUse(pdf_offset, generation) => {
          assert_eq(pdf_offset, 258L)
          assert_eq(generation, 3)
        }
        _ => fail("expected default in-use xref entry")
      }
    None => fail("expected object 0 xref entry")
  }

  match find_xref_stream_entry(section.entries, 1) {
    Some(entry) =>
      match entry.entry {
        InUse(pdf_offset, generation) => {
          assert_eq(pdf_offset, 4L)
          assert_eq(generation, 5)
        }
        _ => fail("expected default in-use xref entry")
      }
    None => fail("expected object 1 xref entry")
  }
}

///|
test "parse_xref_stream_section rejects W[1] when it is zero" {
  let input = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 1 /W [0 0 1] /Root 1 0 R /Length 1 >>\r\n" +
    b"stream\r\n" +
    b"\x01" +
    b"\r\nendstream endobj"

  expect_invalid_xref_stream_section(
    input,
    PdfVersion::{ major: 1, minor: 7 },
    "W[1]",
  )
}

///|
test "parse_xref_stream_section rejects missing W and non-XRef stream types" {
  let missing_w = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 1 /Root 1 0 R /Length 0 >>\r\n" +
    b"stream\r\n" +
    b"" +
    b"\r\nendstream endobj"
  expect_invalid_xref_stream_section(
    missing_w,
    PdfVersion::{ major: 1, minor: 7 },
    "W",
  )

  let wrong_type = b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /Size 1 /W [1 1 1] /Root 1 0 R /Length 0 >>\r\n" +
    b"stream\r\n" +
    b"" +
    b"\r\nendstream endobj"
  expect_invalid_xref_stream_section(
    wrong_type,
    PdfVersion::{ major: 1, minor: 7 },
    "XRef",
  )
}

///|
test "parse_xref_stream_section skips unsupported entry types and rejects encrypted streams" {
  let unsupported = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 3 /W [1 1 1] /Index [0 3] /Root 1 0 R /Length 9 >>\r\n" +
    b"stream\r\n" +
    b"\x01\x05\x01\x03\x07\x02\x02\x09\x04" +
    b"\r\nendstream endobj"

  let section = expect_valid_xref_stream_section(unsupported, PdfVersion::{
    major: 1,
    minor: 7,
  })

  assert_eq(section.entries.length(), 2)
  assert_eq(find_xref_stream_entry(section.entries, 1) is None, true)

  match find_xref_stream_entry(section.entries, 0) {
    Some(entry) =>
      match entry.entry {
        InUse(pdf_offset, generation) => {
          assert_eq(pdf_offset, 5L)
          assert_eq(generation, 1)
        }
        _ => fail("expected in-use xref entry")
      }
    None => fail("expected object 0 xref entry")
  }

  match find_xref_stream_entry(section.entries, 2) {
    Some(entry) =>
      match entry.entry {
        Compressed(object_stream_number, index) => {
          assert_eq(object_stream_number, 9)
          assert_eq(index, 4)
        }
        _ => fail("expected compressed xref entry")
      }
    None => fail("expected object 2 xref entry")
  }

  let encrypted = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 1 /W [1 1 1] /Root 1 0 R /Encrypt 9 0 R /Length 3 >>\r\n" +
    b"stream\r\n" +
    b"\x01\x00\x05" +
    b"\r\nendstream endobj"
  expect_unsupported_xref_stream_section(
    encrypted,
    PdfVersion::{ major: 1, minor: 7 },
    "Encrypt",
  )
}

///|
test "parse_xref_stream_section rejects unsorted, overlapping, and out-of-bounds Index ranges" {
  let unsorted = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 3 /W [1 1 1] /Index [2 1 0 1] /Root 1 0 R /Length 6 >>\r\n" +
    b"stream\r\n" +
    b"\x01\x05\x01\x01\x07\x02" +
    b"\r\nendstream endobj"
  expect_invalid_xref_stream_section(
    unsorted,
    PdfVersion::{ major: 1, minor: 7 },
    "sorted",
  )

  let overlapping = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 3 /W [1 1 1] /Index [0 2 1 1] /Root 1 0 R /Length 6 >>\r\n" +
    b"stream\r\n" +
    b"\x01\x05\x01\x01\x07\x02" +
    b"\r\nendstream endobj"
  expect_invalid_xref_stream_section(
    overlapping,
    PdfVersion::{ major: 1, minor: 7 },
    "overlap",
  )

  let beyond_size = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 3 /W [1 1 1] /Index [0 4] /Root 1 0 R /Length 12 >>\r\n" +
    b"stream\r\n" +
    b"\x01\x05\x01\x01\x07\x02\x02\x09\x03\x01\x0A\x04" +
    b"\r\nendstream endobj"
  expect_invalid_xref_stream_section(
    beyond_size,
    PdfVersion::{ major: 1, minor: 7 },
    "Size",
  )
}

///|
test "parse_xref_stream_section rejects oversized entry widths before parsing entries" {
  let input = b"1 0 obj\r\n" +
    b"<< /Type /XRef /Size 1 /W [1 2147483647 2147483647] /Root 1 0 R /Length 1 >>\r\n" +
    b"stream\r\n" +
    b"\x01" +
    b"\r\nendstream endobj"

  expect_invalid_xref_stream_section(
    input,
    PdfVersion::{ major: 1, minor: 7 },
    "entry widths",
  )
}
