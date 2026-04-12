///|
fn stream_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> @objects.PdfObject raise {
  match dict.get(@objects.PdfName::new(key)) {
    Some(value) => value
    None => fail("expected stream dictionary entry")
  }
}

///|
test "parser leaves direct dictionary values as plain dictionaries before stream" {
  let object = @parser.parse_object(b"<< /Length 1 >> stream\nX\nendstream")
  match object {
    Dictionary(dict) =>
      assert_eq(
        stream_entry(dict, b"Length") == @objects.PdfObject::Integer(1L),
        true,
      )
    _ => fail("expected plain dictionary")
  }
}

///|
test "parser rejects direct aggregate stream boundaries without consuming stream data" {
  let parser = @parser.ObjectParser::new(
    b"[<< /Length 1 >> stream\nX\nendstream]",
  )
  let result : Result[Array[@objects.PdfObject], @objects.PdfParseError] = try? parser.parse_all_objects()
  match result {
    Err(UnexpectedToken(_, expected, actual)) => {
      assert_eq(expected, "object")
      assert_eq(actual, "stream")
    }
    _ => fail("expected stream token rejection")
  }
}

///|
test "parser reads indirect stream objects with exact length and metadata" {
  let indirect = @parser.parse_indirect_object(
    b"12 0 obj << /Length 3 /Filter /FlateDecode /DecodeParms << /Predictor 12 >> /DL 3 >> stream\nabc\r\nendstream endobj",
  )
  assert_eq(
    indirect.id ==
    @objects.ObjectId::{ object_number: 12, generation_number: 0 },
    true,
  )
  match indirect.value {
    Stream(stream) => {
      assert_eq(stream.data, b"abc")
      assert_eq(
        stream_entry(stream.dict, b"Length") == @objects.PdfObject::Integer(3L),
        true,
      )
      assert_eq(
        stream_entry(stream.dict, b"Filter") ==
        @objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode")),
        true,
      )
      match stream_entry(stream.dict, b"DecodeParms") {
        Dictionary(dict) =>
          assert_eq(
            stream_entry(dict, b"Predictor") == @objects.PdfObject::Integer(12L),
            true,
          )
        _ => fail("expected decode parms dictionary")
      }
      assert_eq(
        stream_entry(stream.dict, b"DL") == @objects.PdfObject::Integer(3L),
        true,
      )
    }
    _ => fail("expected stream object")
  }
}

///|
test "parser rejects extra non-white-space before endobj in indirect streams" {
  let result : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    b"1 0 obj << /Length 1 >> stream\nX\nendstream Y endobj",
  )
  match result {
    Err(InvalidIndirectObject(_, reason)) =>
      assert_eq(reason.contains("endobj"), true)
    _ => fail("expected indirect object termination rejection")
  }
}

///|
test "parser reads zero-length indirect streams" {
  let indirect = @parser.parse_indirect_object(
    b"1 0 obj << /Length 0 >> stream\r\nendstream endobj",
  )
  match indirect.value {
    Stream(stream) => {
      assert_eq(stream.data, b"")
      assert_eq(
        stream_entry(stream.dict, b"Length") == @objects.PdfObject::Integer(0L),
        true,
      )
    }
    _ => fail("expected stream object")
  }
}

///|
test "parser rejects malformed indirect stream envelopes" {
  let missing_length : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    b"1 0 obj <<>> stream\nabc endstream endobj",
  )
  match missing_length {
    Err(InvalidStream(_, reason)) => assert_eq(reason.contains("Length"), true)
    _ => fail("expected missing length rejection")
  }

  let non_integer_length : Result[
    @objects.IndirectObject,
    @objects.PdfParseError,
  ] = try? @parser.parse_indirect_object(
    b"1 0 obj << /Length true >> stream\nabc endstream endobj",
  )
  match non_integer_length {
    Err(InvalidStream(_, reason)) => assert_eq(reason.contains("Length"), true)
    _ => fail("expected non-integer length rejection")
  }

  let cr_only : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    b"1 0 obj << /Length 1 >> stream\rX endstream endobj",
  )
  match cr_only {
    Err(InvalidStream(_, reason)) =>
      assert_eq(reason.contains("stream EOL"), true)
    _ => fail("expected CR-only stream EOL rejection")
  }

  let missing_endstream : Result[
    @objects.IndirectObject,
    @objects.PdfParseError,
  ] = try? @parser.parse_indirect_object(
    b"1 0 obj << /Length 1 >> stream\nX endobj",
  )
  match missing_endstream {
    Err(InvalidStream(_, reason)) =>
      assert_eq(reason.contains("endstream"), true)
    _ => fail("expected missing endstream rejection")
  }
}
