///|
fn build_hybrid_current_table_section() -> Bytes {
  b"xref\r\n" +
  b"0 2\r\n" +
  b"0000000000 65535 f\r\n" +
  b"0000000017 00000 n \n" +
  b"trailer\r\n" +
  b"<< /Size 3 /Root 1 0 R /XRefStm 1000 /Prev 1200 >>"
}

///|
fn build_prev_cycle_table_section() -> Bytes {
  b"xref\r\n" +
  b"0 2\r\n" +
  b"0000000000 65535 f\r\n" +
  b"0000000017 00000 n \n" +
  b"trailer\r\n" +
  b"<< /Size 3 /Root 1 0 R /Prev 0 >>"
}

///|
fn build_out_of_bounds_table_section() -> Bytes {
  b"xref\r\n" +
  b"0 2\r\n" +
  b"0000000000 65535 f\r\n" +
  b"0000000017 00000 n \n" +
  b"trailer\r\n" +
  b"<< /Size 3 /Root 1 0 R /XRefStm 9999 >>"
}

///|
fn build_xref_stream_section() -> Bytes {
  b"1 0 obj\n" +
  b"<< /Type /XRef /Size 3 /W [1 2 2] /Root 1 0 R /Length 15 >>\r\n" +
  b"stream\n" +
  b"\x00\x00\x00\xff\xff\x01\x00\x2a\x00\x00\x02\x00\x09\x00\x03" +
  b"\r\nendstream endobj\r\n"
}

///|
fn build_xref_stream_section_with_prev() -> Bytes {
  b"1 0 obj\n" +
  b"<< /Type /XRef /Size 3 /W [1 2 2] /Root 1 0 R /Prev 1200 /Length 15 >>\r\n" +
  b"stream\n" +
  b"\x00\x00\x00\xff\xff\x01\x00\x2a\x00\x00\x02\x00\x09\x00\x03" +
  b"\r\nendstream endobj\r\n"
}

///|
fn build_previous_table_section() -> Bytes {
  b"xref\r\n" +
  b"0 2\r\n" +
  b"0000000000 65535 f\r\n" +
  b"0000000017 00000 n \n" +
  b"trailer\r\n" +
  b"<< /Size 3 /Root 1 0 R >>"
}

///|
fn pad_bytes_to_length(bytes : Bytes, target_length : Int64) -> Bytes {
  let mut padded = bytes
  while padded.length().to_int64() < target_length {
    padded = padded + b" "
  }
  padded
}

///|
fn build_hybrid_chain_fixture() -> (Bytes, Int64, Int64) {
  let xref_stm_offset = 1000L
  let prev_offset = 1200L
  let current_table = pad_bytes_to_length(
    build_hybrid_current_table_section(),
    xref_stm_offset,
  )
  let xref_stream = pad_bytes_to_length(
    build_xref_stream_section_with_prev(),
    prev_offset - xref_stm_offset,
  )
  let previous_table = build_previous_table_section()
  (current_table + xref_stream + previous_table, xref_stm_offset, prev_offset)
}

///|
fn build_direct_stream_chain_fixture() -> (Bytes, Int64) {
  let prev_offset = 1200L
  let xref_stream = pad_bytes_to_length(
    build_xref_stream_section_with_prev(),
    prev_offset,
  )
  let previous_table = build_previous_table_section()
  (xref_stream + previous_table, prev_offset)
}

///|
fn expect_valid_section_chain(
  input : Bytes,
  startxref : Int64,
  version : PdfVersion,
) -> Array[XrefSection] raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[Array[XrefSection], PdfReaderError] = try? read_section_chain(
    source, startxref, version,
  )
  match result {
    Ok(sections) => sections
    Err(InvalidXref(offset, reason)) =>
      fail(
        "expected valid xref section chain, got InvalidXref \{offset} \{reason}",
      )
    Err(InvalidTrailer(offset, reason)) =>
      fail(
        "expected valid xref section chain, got InvalidTrailer \{offset} \{reason}",
      )
    Err(PrevChainCycle(offset)) =>
      fail("expected valid xref section chain, got PrevChainCycle \{offset}")
    Err(ParseObjectError(offset, _)) =>
      fail("expected valid xref section chain, got ParseObjectError \{offset}")
    Err(InvalidHeader(offset, reason)) =>
      fail(
        "expected valid xref section chain, got InvalidHeader \{offset} \{reason}",
      )
    Err(MissingTailMarker(reason)) =>
      fail("expected valid xref section chain, got MissingTailMarker \{reason}")
    Err(InvalidObjectStream(offset, reason)) =>
      fail(
        "expected valid xref section chain, got InvalidObjectStream \{offset} \{reason}",
      )
    Err(InvalidObjectLocation(_, reason)) =>
      fail(
        "expected valid xref section chain, got InvalidObjectLocation \{reason}",
      )
    Err(UnsupportedFilter(offset, reason)) =>
      fail(
        "expected valid xref section chain, got UnsupportedFilter \{offset} \{reason}",
      )
    Err(DecodeStreamError(offset, error)) =>
      match error {
        @filters.PdfFilterError::DecodeError(_, _) =>
          fail(
            "expected valid xref section chain, got DecodeStreamError \{offset}",
          )
        @filters.PdfFilterError::UnsupportedFilter(_) =>
          fail(
            "expected valid xref section chain, got DecodeStreamError \{offset}",
          )
        @filters.PdfFilterError::InvalidFilterSpec(_) =>
          fail(
            "expected valid xref section chain, got DecodeStreamError \{offset}",
          )
        @filters.PdfFilterError::InvalidDecodeParms(_, _) =>
          fail(
            "expected valid xref section chain, got DecodeStreamError \{offset}",
          )
      }
    Err(EncryptionError(_)) =>
      fail("expected valid xref section chain, got EncryptionError")
  }
}

///|
test "read_section_chain returns hybrid sections in merge-priority order" {
  let (input, xref_stm_offset, prev_offset) = build_hybrid_chain_fixture()
  let sections = expect_valid_section_chain(input, 0L, PdfVersion::{
    major: 1,
    minor: 7,
  })

  assert_eq(sections.length(), 3)
  assert_eq(sections[0].provenance.source == XrefSectionSource::Table, true)
  assert_eq(sections[0].provenance.pdf_offset, 0L)
  assert_eq(sections[0].trailer.xref_stm == Some(xref_stm_offset), true)
  assert_eq(sections[0].trailer.prev == Some(prev_offset), true)

  assert_eq(sections[1].provenance.source == XrefSectionSource::Stream, true)
  assert_eq(sections[1].provenance.pdf_offset, xref_stm_offset)
  assert_eq(sections[1].trailer.prev == Some(prev_offset), true)

  assert_eq(sections[2].provenance.source == XrefSectionSource::Table, true)
  assert_eq(sections[2].provenance.pdf_offset, prev_offset)
  assert_eq(sections[2].trailer.prev is None, true)
}

///|
test "read_section_chain follows prev from direct xref streams" {
  let (input, prev_offset) = build_direct_stream_chain_fixture()
  let sections = expect_valid_section_chain(input, 0L, PdfVersion::{
    major: 1,
    minor: 7,
  })

  assert_eq(sections.length(), 2)
  assert_eq(sections[0].provenance.source == XrefSectionSource::Stream, true)
  assert_eq(sections[0].provenance.pdf_offset, 0L)
  assert_eq(sections[0].trailer.prev == Some(prev_offset), true)

  assert_eq(sections[1].provenance.source == XrefSectionSource::Table, true)
  assert_eq(sections[1].provenance.pdf_offset, prev_offset)
  assert_eq(sections[1].trailer.prev is None, true)
}

///|
test "read_section_chain rejects prev cycles" {
  let input = build_prev_cycle_table_section()
  let source = ByteSource::new(input, 0L)

  let result : Result[Array[XrefSection], PdfReaderError] = try? read_section_chain(
    source,
    0L,
    PdfVersion::{ major: 1, minor: 7 },
  )

  match result {
    Err(PrevChainCycle(offset)) => assert_eq(offset, 0L)
    _ => fail("expected prev chain cycle error")
  }
}

///|
test "read_section_chain rejects out-of-bounds xref offsets" {
  let input = build_out_of_bounds_table_section()
  let source = ByteSource::new(input, 0L)

  let result : Result[Array[XrefSection], PdfReaderError] = try? read_section_chain(
    source,
    0L,
    PdfVersion::{ major: 1, minor: 7 },
  )

  match result {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 9999L)
      assert_eq(reason.contains("buffer"), true)
    }
    _ => fail("expected out-of-bounds xref offset error")
  }
}

///|
test "xref stream helper parses on its own" {
  let source = ByteSource::new(build_xref_stream_section(), 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_stream_section(
    source,
    0L,
    PdfVersion::{ major: 1, minor: 7 },
  )
  match result {
    Ok(section) => assert_eq(section.trailer.prev is None, true)
    _ => fail("expected xref stream helper to parse")
  }
}
