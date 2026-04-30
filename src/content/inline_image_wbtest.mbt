///|
test "inline image reader expands dictionary keys and captures raw data" {
  let image = InlineImageReader::new(b"/W 2 /H 1 /BPC 8 /CS /RGB ID abc EI").parse(
    0L,
  )

  assert_eq(
    image.dictionary.get(@objects.PdfName::new(b"Width")) ==
    Some(@objects.PdfObject::Integer(2L)),
    true,
  )
  assert_eq(
    image.dictionary.get(@objects.PdfName::new(b"Height")) ==
    Some(@objects.PdfObject::Integer(1L)),
    true,
  )
  assert_eq(
    image.dictionary.get(@objects.PdfName::new(b"BitsPerComponent")) ==
    Some(@objects.PdfObject::Integer(8L)),
    true,
  )
  assert_eq(
    image.dictionary.get(@objects.PdfName::new(b"ColorSpace")) ==
    Some(@objects.PdfObject::Name(@objects.PdfName::new(b"DeviceRGB"))),
    true,
  )
  assert_eq(image.data, b"abc")
  assert_eq(image.start_offset, 0L)
  assert_eq(image.data_offset > image.start_offset, true)
  assert_eq(image.end_offset > image.data_offset, true)
}

///|
test "inline image reader expands Length and Indexed abbreviations" {
  let image = InlineImageReader::new(
    b"/W 1 /H 1 /CS [/I /RGB 1 <000000ffffff>] /BPC 8 /L 3 ID abc EI",
  ).parse(0L)

  assert_eq(
    image.dictionary.get(@objects.PdfName::new(b"Length")) ==
    Some(@objects.PdfObject::Integer(3L)),
    true,
  )
  match image.dictionary.get(@objects.PdfName::new(b"ColorSpace")) {
    Some(@objects.PdfObject::Array(values)) => {
      assert_eq(
        values[0] == @objects.PdfObject::Name(@objects.PdfName::new(b"Indexed")),
        true,
      )
      assert_eq(
        values[1] ==
        @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceRGB")),
        true,
      )
    }
    _ => fail("expected expanded Indexed colour space array")
  }
}

///|
test "inline image reader accepts CRLF before EI and excludes separator bytes" {
  let image = InlineImageReader::new(b"/W 1 ID xyz\r\nEI ").parse(5L)
  assert_eq(image.data, b"xyz")
  assert_eq(image.start_offset, 5L)
}

///|
test "inline image reader requires whitespace after ID" {
  let result : Result[PdfInlineImage, PdfContentError] = try? InlineImageReader::new(
    b"/W 1 ID/abc EI",
  ).parse(0L)
  match result {
    Err(InlineImageFailure(offset, reason)) => {
      assert_eq(offset, 7L)
      assert_eq(reason.contains("white-space"), true)
    }
    _ => fail("expected missing whitespace after ID")
  }
}

///|
test "inline image reader reports missing ID marker" {
  let result : Result[PdfInlineImage, PdfContentError] = try? InlineImageReader::new(
    b"/W 1 /H 1",
  ).parse(0L)
  match result {
    Err(InlineImageFailure(_, reason)) => assert_eq(reason.contains("ID"), true)
    _ => fail("expected missing ID marker")
  }
}

///|
test "inline image reader reports missing EI marker" {
  let result : Result[PdfInlineImage, PdfContentError] = try? InlineImageReader::new(
    b"/W 1 ID raw bytes",
  ).parse(0L)
  match result {
    Err(InlineImageFailure(_, reason)) => assert_eq(reason.contains("EI"), true)
    _ => fail("expected missing EI marker")
  }
}

///|
test "inline image reader rejects non-name dictionary keys" {
  let result : Result[PdfInlineImage, PdfContentError] = try? InlineImageReader::new(
    b"1 /W ID abc EI",
  ).parse(0L)
  match result {
    Err(InlineImageFailure(_, reason)) =>
      assert_eq(reason.contains("key"), true)
    _ => fail("expected invalid dictionary key")
  }
}

///|
test "inline image reader reports clear errors for large data without EI" {
  let bytes : Array[Byte] = []
  bytes.append(b"/W 1 /H 1 ID ".to_array())
  for _ in 0..<4096 {
    bytes.push(b'X')
  }
  let result : Result[PdfInlineImage, PdfContentError] = try? InlineImageReader::new(
    Bytes::from_array(bytes),
  ).parse(0L)
  match result {
    Err(InlineImageFailure(offset, reason)) => {
      assert_eq(offset > 4096L, true)
      assert_eq(reason.contains("EI"), true)
    }
    _ => fail("expected missing EI marker for large inline image data")
  }
}
