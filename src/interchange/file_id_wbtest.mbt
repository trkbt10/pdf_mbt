///|
test "file identifier comparison covers exact version original mismatch and missing" {
  assert_eq(
    compare_file_identifier_bytes(b"a", b"b", b"a", b"b") ==
    PdfFileIdMatch::ExactFileAndVersion,
    true,
  )
  assert_eq(
    compare_file_identifier_bytes(b"a", b"b", b"a", b"c") ==
    PdfFileIdMatch::SameOriginalDifferentVersion,
    true,
  )
  assert_eq(
    compare_file_identifier_bytes(b"a", b"b", b"x", b"b") ==
    PdfFileIdMatch::DifferentFile,
    true,
  )
  assert_eq(
    compare_optional_file_identifier_bytes(None, None, b"a", b"b") ==
    PdfFileIdMatch::MissingCurrentIdentifier,
    true,
  )
}
