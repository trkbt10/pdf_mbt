///|
fn robustness_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
test "parser reports representative eof and numeric robustness errors" {
  let literal_eof : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"(unterminated",
  )
  match literal_eof {
    Err(UnexpectedEof(_, context)) => assert_eq(context, "literal string")
    _ => fail("expected literal string eof")
  }

  let hex_eof : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"<4E6F762073686D6F7A206B6120706F702E",
  )
  match hex_eof {
    Err(UnexpectedEof(_, context)) => assert_eq(context, "hex string")
    _ => fail("expected hex string eof")
  }

  let overflow : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"9223372036854775808",
  )
  match overflow {
    Err(NumericOverflow(offset, lexeme)) => {
      assert_eq(offset, 0L)
      assert_eq(lexeme, b"9223372036854775808")
    }
    _ => fail("expected numeric overflow")
  }
}

///|
test "parser reports invalid names dictionaries and stream lengths" {
  let invalid_name : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"/A#00B",
  )
  match invalid_name {
    Err(InvalidName(offset, reason)) => {
      assert_eq(offset, 2L)
      assert_eq(reason.contains("NUL"), true)
    }
    _ => fail("expected invalid name")
  }

  let duplicate_key : Result[@objects.PdfObject, @objects.PdfParseError] = try? @parser.parse_object(
    b"<< /A 1 /A 2 >>",
  )
  match duplicate_key {
    Err(InvalidDictionary(offset, reason)) => {
      assert_eq(offset, 8L)
      assert_eq(reason.contains("duplicate"), true)
    }
    _ => fail("expected duplicate key rejection")
  }

  let negative_length : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    b"1 0 obj << /Length -1 >> stream\nX\nendstream endobj",
  )
  match negative_length {
    Err(InvalidStream(_, reason)) => assert_eq(reason.contains("Length"), true)
    _ => fail("expected negative stream length rejection")
  }

  let short_stream : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    b"1 0 obj << /Length 2 >> stream\nX",
  )
  match short_stream {
    Err(UnexpectedEof(_, context)) => assert_eq(context, "raw bytes")
    _ => fail("expected short stream read rejection")
  }
}

///|
test "parser reports invalid indirect headers and preserves large payload offsets" {
  let invalid_header : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    b"1 0 foo null endobj",
  )
  match invalid_header {
    Err(InvalidIndirectObject(offset, reason)) => {
      assert_eq(offset, 4L)
      assert_eq(reason.contains("obj"), true)
    }
    _ => fail("expected invalid indirect header")
  }

  let payload = Bytes::make(2048, b'a')
  let large_string = @parser.parse_object(b"(" + payload + b")")
  match large_string {
    String(bytes) => assert_eq(bytes.length(), 2048)
    _ => fail("expected large literal string")
  }
  let large_string_sequence = @parser.parse_all_objects(b"(" + payload + b") 7")
  assert_eq(large_string_sequence.length(), 2)
  match large_string_sequence[0] {
    String(bytes) => assert_eq(bytes, payload)
    _ => fail("expected large literal string in sequence")
  }
  assert_eq(large_string_sequence[1] == @objects.PdfObject::Integer(7L), true)

  let stream_input = b"1 0 obj << /Length 2048 >> stream\n" +
    payload +
    b"\nendstream endobj"
  let stream_object = @parser.parse_indirect_object(stream_input)
  match stream_object.value {
    Stream(stream) => {
      assert_eq(stream.data.length(), 2048)
      assert_eq(stream.data, payload)
      assert_eq(stream_object.end_offset, stream_input.length().to_int64())
      assert_eq(
        stream.dict.get(robustness_name(b"Length")) ==
        Some(@objects.PdfObject::Integer(2048L)),
        true,
      )
    }
    _ => fail("expected large stream object")
  }
}
