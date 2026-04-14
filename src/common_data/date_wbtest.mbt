///|
test "pdf date parser applies defaults and parses offsets" {
  let minimal = parse_pdf_date(b"D:2026")
  assert_eq(minimal.year, 2026)
  assert_eq(minimal.month, 1)
  assert_eq(minimal.day, 1)
  assert_eq(minimal.hour, 0)
  assert_eq(minimal.utc_offset == PdfUtcOffset::UnspecifiedGMT, true)
  let full = parse_pdf_date(b"D:199812231952-08'00")
  assert_eq(full.year, 1998)
  assert_eq(full.month, 12)
  assert_eq(full.day, 23)
  assert_eq(full.hour, 19)
  assert_eq(full.minute, 52)
  assert_eq(full.utc_offset == PdfUtcOffset::EarlierThanUT(8, 0), true)
  let legacy = parse_pdf_date(b"D:199812231952+09'30'")
  assert_eq(legacy.utc_offset == PdfUtcOffset::LaterThanUT(9, 30), true)
  let zulu = parse_pdf_date(b"D:202604140000Z00'00'")
  assert_eq(zulu.utc_offset == PdfUtcOffset::EqualUT, true)
}

///|
test "pdf date parser rejects malformed dates" {
  let missing_prefix : Result[PdfDate, PdfCommonDataError] = try? parse_pdf_date(
    b"2026",
  )
  match missing_prefix {
    Err(PdfCommonDataError::InvalidDate(_, _)) => ()
    _ => fail("expected missing prefix rejection")
  }
  let whitespace : Result[PdfDate, PdfCommonDataError] = try? parse_pdf_date(
    b"D:2026 01",
  )
  match whitespace {
    Err(PdfCommonDataError::InvalidDate(_, _)) => ()
    _ => fail("expected whitespace rejection")
  }
  let range : Result[PdfDate, PdfCommonDataError] = try? parse_pdf_date(
    b"D:202613",
  )
  match range {
    Err(PdfCommonDataError::InvalidDate(_, _)) => ()
    _ => fail("expected month range rejection")
  }
}
