///|
fn expect_valid_object_stream_table(input : Bytes) -> ObjectStreamTable raise {
  let indirect_result : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    input,
  )
  let indirect = match indirect_result {
    Ok(value) => value
    Err(_) => fail("expected valid object stream indirect object")
  }

  match indirect.value {
    @objects.PdfObject::Stream(stream) => {
      let table_result : Result[ObjectStreamTable, PdfReaderError] = try? parse_object_stream(
        stream,
        offset=indirect.start_offset,
      )
      match table_result {
        Ok(table) => table
        Err(_) => fail("expected valid object stream table")
      }
    }
    _ => fail("expected stream indirect object")
  }
}

///|
fn expect_invalid_object_stream(
  input : Bytes,
  reason_fragment : String,
) -> Unit raise {
  let indirect_result : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    input,
  )
  let indirect = match indirect_result {
    Ok(value) => value
    Err(_) => fail("expected valid object stream indirect object")
  }

  match indirect.value {
    @objects.PdfObject::Stream(stream) => {
      let result : Result[ObjectStreamTable, PdfReaderError] = try? parse_object_stream(
        stream,
        offset=indirect.start_offset,
      )
      match result {
        Err(InvalidObjectStream(_, reason)) =>
          assert_eq(reason.contains(reason_fragment), true)
        _ => fail("expected invalid object stream error")
      }
    }
    _ => fail("expected stream indirect object")
  }
}

///|
test "parse_object_stream returns indexed members from a valid object stream" {
  let table = expect_valid_object_stream_table(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 10 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
  )

  let first_entry = table.entry_at(0)
  assert_eq(first_entry.object_number, 10)
  assert_eq(first_entry.object == @objects.PdfObject::Integer(1L), true)

  let second_entry = table.entry_at(1)
  assert_eq(second_entry.object_number, 20)
  match second_entry.object {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"A")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    _ => fail("expected dictionary member")
  }

  let invalid_index : Result[ObjectStreamMember, PdfReaderError] = try? table.entry_at(
    2,
  )
  match invalid_index {
    Err(InvalidObjectStream(_, reason)) =>
      assert_eq(reason.contains("index"), true)
    _ => fail("expected invalid object stream index")
  }
}

///|
test "parse_object_stream rejects invalid N and First entries" {
  expect_invalid_object_stream(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N -1 /First 10 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    "N",
  )

  expect_invalid_object_stream(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 99 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    "First",
  )
}

///|
test "parse_object_stream rejects malformed header pairs" {
  expect_invalid_object_stream(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 7 /Length 8 >>\r\n" +
    b"stream\r\n" +
    b"10 0 201" +
    b"\r\nendstream endobj",
    "header",
  )
}

///|
test "parse_object_stream rejects non-zero first member relative offsets" {
  expect_invalid_object_stream(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 9 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 1 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    "relative offset",
  )
}

///|
test "parse_object_stream rejects stream members" {
  expect_invalid_object_stream(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 10 /Length 44 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /Length 0 >> stream\nendstream" +
    b"\r\nendstream endobj",
    "stream",
  )
}

///|
test "parse_object_stream rejects missing ObjStm type" {
  expect_invalid_object_stream(
    b"1 0 obj\r\n" +
    b"<< /Type /XRef /N 2 /First 10 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    "ObjStm",
  )
}
