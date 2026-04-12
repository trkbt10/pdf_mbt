///|
fn expect_valid_header(
  input : Bytes,
  expected_major : Int,
  expected_minor : Int,
  expected_base_offset : Int64,
  expected_binary_indicator : Bool,
) -> Unit raise {
  let header = try? parse_header(input)
  match header {
    Ok(header) => {
      assert_eq(
        header.version ==
        PdfVersion::{ major: expected_major, minor: expected_minor },
        true,
      )
      assert_eq(header.base_offset, expected_base_offset)
      assert_eq(header.has_binary_indicator, expected_binary_indicator)
    }
    Err(_) => fail("expected valid header")
  }
}

///|
test "parse_header accepts every supported pdf version and all header eol forms" {
  expect_valid_header(b"%PDF-1.0\r", 1, 0, 0L, false)
  expect_valid_header(b"abc%PDF-1.1\n", 1, 1, 3L, false)
  expect_valid_header(b"%PDF-1.2\r\n", 1, 2, 0L, false)
  expect_valid_header(b"%PDF-1.3\r", 1, 3, 0L, false)
  expect_valid_header(b"%PDF-1.4\n", 1, 4, 0L, false)
  expect_valid_header(b"xx%PDF-1.5\r\n", 1, 5, 2L, false)
  expect_valid_header(b"%PDF-1.6\r", 1, 6, 0L, false)
  expect_valid_header(b"%PDF-1.7\n", 1, 7, 0L, false)
  expect_valid_header(b"%PDF-2.0\r\n", 2, 0, 0L, false)
}

///|
test "parse_header detects the binary indicator comment threshold" {
  expect_valid_header(b"%PDF-1.7\r\n%\x80\x81\x82\x83\r\n", 1, 7, 0L, true)
  expect_valid_header(b"%PDF-1.7\r\n%\x80\x81\x82A\r\n", 1, 7, 0L, false)
}

///|
test "parse_header rejects unsupported or unterminated headers" {
  let unsupported_version : Result[PdfHeader, PdfReaderError] = try? parse_header(
    b"%PDF-1.8\n",
  )
  match unsupported_version {
    Err(InvalidHeader(_, reason)) => assert_eq(reason.contains("version"), true)
    _ => fail("expected unsupported version to fail")
  }

  let unterminated_header : Result[PdfHeader, PdfReaderError] = try? parse_header(
    b"%PDF-2.0",
  )
  match unterminated_header {
    Err(InvalidHeader(_, reason)) => assert_eq(reason.contains("EOL"), true)
    _ => fail("expected unterminated header to fail")
  }

  let missing_marker : Result[PdfHeader, PdfReaderError] = try? parse_header(
    b"not a pdf header",
  )
  match missing_marker {
    Err(InvalidHeader(_, reason)) => assert_eq(reason.contains("%PDF-"), true)
    _ => fail("expected missing marker to fail")
  }
}
