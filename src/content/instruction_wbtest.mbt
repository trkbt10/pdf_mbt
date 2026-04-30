///|
test "parser emits ordered operation instructions and clears operands" {
  let parser = ContentStreamParser::new(b"1 0 0 1 10 20 cm q")
  let stream = parser.parse_all()
  assert_eq(stream.instructions.length(), 2)

  match stream.instructions[0] {
    Operation(operation) => {
      assert_eq(operation.operator == ConcatMatrix, true)
      assert_eq(operation.offset, 14L)
      assert_eq(operation.operands.length(), 6)
      assert_eq(operation.operands[0] == @objects.PdfObject::Integer(1L), true)
      assert_eq(operation.operands[5] == @objects.PdfObject::Integer(20L), true)
    }
    _ => fail("expected normal operation")
  }

  match stream.instructions[1] {
    Operation(operation) => {
      assert_eq(operation.operator == SaveGraphicsState, true)
      assert_eq(operation.operands.length(), 0)
    }
    _ => fail("expected second normal operation")
  }
}

///|
test "parser emits inline image instructions from BI ID EI sequence" {
  let parser = ContentStreamParser::new(b"q BI /W 1 /H 1 /BPC 8 ID Z EI Q")
  let stream = parser.parse_all()
  assert_eq(stream.instructions.length(), 3)

  match stream.instructions[1] {
    InlineImage(image) => {
      assert_eq(image.data, b"Z")
      assert_eq(
        image.dictionary.get(@objects.PdfName::new(b"Width")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
      assert_eq(image.start_offset, 2L)
    }
    _ => fail("expected inline image instruction")
  }
}

///|
test "parser rejects ID and EI markers outside inline image sequence" {
  let id_result : Result[ContentInstruction?, PdfContentError] = try? ContentStreamParser::new(
    b"ID",
  ).parse_next()
  match id_result {
    Err(InlineImageFailure(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("BI"), true)
    }
    _ => fail("expected ID outside BI to fail")
  }

  let ei_result : Result[ContentInstruction?, PdfContentError] = try? ContentStreamParser::new(
    b"EI",
  ).parse_next()
  match ei_result {
    Err(InlineImageFailure(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("BI"), true)
    }
    _ => fail("expected EI outside BI to fail")
  }
}

///|
test "parser returns empty stream at end of decoded input" {
  let stream = ContentStreamParser::new(b"").parse_all()
  assert_eq(stream.instructions.length(), 0)
}

///|
test "parser handles large simple operator streams with linear progress" {
  let bytes : Array[Byte] = []
  for _ in 0..<2000 {
    bytes.append(b"q ".to_array())
  }
  let stream = ContentStreamParser::new(Bytes::from_array(bytes)).parse_all()
  assert_eq(stream.instructions.length(), 2000)
  match stream.instructions[1999] {
    Operation(operation) =>
      assert_eq(operation.operator == SaveGraphicsState, true)
    _ => fail("expected final save graphics state operation")
  }
}
