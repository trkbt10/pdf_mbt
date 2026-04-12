///|
test "find_latest_startxref uses the final eof marker and parses the following offset" {
  let source = ByteSource::new(
    b"abc%PDF-2.0\r\nxref-data\nstartxref\n123\n%%EOF\nignored\nstartxref\n456\n%%EOF",
    3L,
  )

  let latest_startxref : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    source,
  )
  match latest_startxref {
    Ok(offset) => assert_eq(offset, 456L)
    _ => fail("expected latest startxref offset")
  }
}

///|
test "find_latest_startxref reports missing tail markers and invalid integers" {
  let missing_eof : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    ByteSource::new(b"abc%PDF-2.0\r\nstartxref\n123\n", 3L),
  )
  match missing_eof {
    Err(MissingTailMarker(reason)) => assert_eq(reason.contains("%%EOF"), true)
    _ => fail("expected missing eof marker to fail")
  }

  let missing_startxref : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    ByteSource::new(b"abc%PDF-2.0\r\n123\n%%EOF", 3L),
  )
  match missing_startxref {
    Err(MissingTailMarker(reason)) =>
      assert_eq(reason.contains("startxref"), true)
    _ => fail("expected missing startxref marker to fail")
  }

  let invalid_startxref : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    ByteSource::new(b"abc%PDF-2.0\r\nstartxref\n12x\n%%EOF", 3L),
  )
  match invalid_startxref {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 22L)
      assert_eq(reason.contains("unexpected"), true)
    }
    _ => fail("expected invalid startxref integer to fail")
  }
}

///|
test "find_latest_startxref rejects embedded startxref keywords" {
  let embedded_keyword : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    ByteSource::new(b"%PDF-2.0\nnotstartxref\n123\n%%EOF", 0L),
  )
  match embedded_keyword {
    Err(MissingTailMarker(reason)) =>
      assert_eq(reason.contains("startxref"), true)
    _ => fail("expected embedded startxref keyword to fail")
  }
}

///|
test "find_latest_startxref rejects missing delimiters and oversized integers" {
  let missing_delimiter : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    ByteSource::new(b"%PDF-2.0\nstartxref123\n%%EOF", 0L),
  )
  match missing_delimiter {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 18L)
      assert_eq(reason.contains("whitespace"), true)
    }
    _ => fail("expected missing delimiter to fail")
  }

  let oversized_integer : Result[Int64, PdfReaderError] = try? find_latest_startxref(
    ByteSource::new(b"%PDF-2.0\nstartxref\n9223372036854775808\n%%EOF", 0L),
  )
  match oversized_integer {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 19L)
      assert_eq(reason.contains("too large"), true)
    }
    _ => fail("expected oversized startxref integer to fail")
  }
}
