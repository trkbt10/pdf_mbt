///|
test "page piece dictionary preserves ordered producer data and private object" {
  let piece : @objects.PdfDictionary = Map::new()
  let adobe : @objects.PdfDictionary = Map::new()
  adobe[pdf_name(b"LastModified")] = @objects.PdfObject::String(
    b"D:20260414010101",
  )
  adobe[pdf_name(b"Private")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(1L),
  ])
  piece[pdf_name(b"ADBE")] = @objects.PdfObject::Dictionary(adobe)

  let parsed = validate_page_piece_dictionary(
    @objects.PdfObject::Dictionary(piece),
  )
  assert_eq(parsed.entries.length(), 1)
  assert_eq(parsed.entries[0].owner_name == pdf_name(b"ADBE"), true)
  assert_eq(parsed.entries[0].last_modified, b"D:20260414010101")
  assert_eq(parsed.entries[0].private is Some(_), true)
}

///|
test "page piece rejects malformed entries and compares date bytes exactly" {
  let missing_date : @objects.PdfDictionary = Map::new()
  missing_date[pdf_name(b"Producer")] = @objects.PdfObject::Dictionary(
    Map::new(),
  )
  let result : Result[PdfPagePieceDictionary, PdfInterchangeError] = try? validate_page_piece_dictionary(
    @objects.PdfObject::Dictionary(missing_date),
  )
  match result {
    Err(InvalidPagePiece(_, reason)) =>
      assert_eq(reason.contains("LastModified"), true)
    _ => fail("expected missing LastModified failure")
  }

  assert_eq(page_piece_dates_equal(b"D:1", b"D:1"), true)
  assert_eq(page_piece_dates_equal(b"D:1", b"D:01"), false)
}
