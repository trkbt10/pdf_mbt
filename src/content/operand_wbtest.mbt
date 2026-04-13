///|
fn collect_operand_reads(
  input : Bytes,
) -> Array[OperandReadResult] raise PdfContentError {
  let reader = ContentOperandReader::new(input)
  let reads : Array[OperandReadResult] = []
  while true {
    let next = reader.read_next()
    reads.push(next)
    match next {
      EndOfInput(_) => break
      _ => ()
    }
  }
  reads
}

///|
test "content operand reader parses direct operands before operator candidates" {
  let reads = collect_operand_reads(
    b"17 3.5 (Hi) <4869> /Name [1 false null] << /Key 1 /Flag true >> true null q",
  )
  assert_eq(reads.length(), 11)

  match reads[0] {
    Operand(Integer(value)) => assert_eq(value, 17L)
    _ => fail("expected integer operand")
  }
  match reads[1] {
    Operand(Real(value)) => assert_eq(value, 3.5)
    _ => fail("expected real operand")
  }
  match reads[2] {
    Operand(String(bytes)) => assert_eq(bytes, b"Hi")
    _ => fail("expected literal string operand")
  }
  match reads[3] {
    Operand(String(bytes)) => assert_eq(bytes, b"Hi")
    _ => fail("expected hexadecimal string operand")
  }
  match reads[4] {
    Operand(Name(name)) =>
      assert_eq(name == @objects.PdfName::new(b"Name"), true)
    _ => fail("expected name operand")
  }
  match reads[5] {
    Operand(Array(values)) => {
      assert_eq(values.length(), 3)
      assert_eq(values[0] == @objects.PdfObject::Integer(1L), true)
      assert_eq(values[1] == @objects.PdfObject::Boolean(false), true)
      assert_eq(values[2] == @objects.PdfObject::Null, true)
    }
    _ => fail("expected array operand")
  }
  match reads[6] {
    Operand(Dictionary(dict)) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Key")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Flag")) ==
        Some(@objects.PdfObject::Boolean(true)),
        true,
      )
    }
    _ => fail("expected dictionary operand")
  }
  match reads[7] {
    Operand(Boolean(value)) => assert_eq(value, true)
    _ => fail("expected boolean operand")
  }
  match reads[8] {
    Operand(Null) => ()
    _ => fail("expected null operand")
  }
  match reads[9] {
    OperatorCandidate(keyword, offset) => {
      assert_eq(keyword, b"q")
      assert_eq(offset > 0L, true)
    }
    _ => fail("expected operator candidate")
  }
  match reads[10] {
    EndOfInput(_) => ()
    _ => fail("expected end of input")
  }
}

///|
test "content operand reader does not create indirect references" {
  let reads = collect_operand_reads(b"1 0 R q")
  assert_eq(reads.length(), 5)
  match reads[0] {
    Operand(Integer(value)) => assert_eq(value, 1L)
    _ => fail("expected first integer operand")
  }
  match reads[1] {
    Operand(Integer(value)) => assert_eq(value, 0L)
    _ => fail("expected second integer operand")
  }
  match reads[2] {
    OperatorCandidate(keyword, _) => assert_eq(keyword, b"R")
    _ => fail("expected indirect-reference keyword to stay a candidate")
  }
  match reads[3] {
    OperatorCandidate(keyword, _) => assert_eq(keyword, b"q")
    _ => fail("expected trailing operator candidate")
  }
  match reads[4] {
    EndOfInput(_) => ()
    _ => fail("expected end of input")
  }
}

///|
test "content operand reader rejects unexpected delimiters" {
  let result : Result[OperandReadResult, PdfContentError] = try? ContentOperandReader::new(
    b"]",
  ).read_next()
  match result {
    Err(MalformedSyntax(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("delimiter"), true)
    }
    _ => fail("expected unexpected delimiter error")
  }
}

///|
test "content operand reader rejects invalid numbers" {
  let result : Result[OperandReadResult, PdfContentError] = try? ContentOperandReader::new(
    b"1.2.3",
  ).read_next()
  match result {
    Err(MalformedSyntax(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("number"), true)
    }
    _ => fail("expected invalid number error")
  }
}

///|
test "content operand reader rejects stream-like keywords" {
  let result : Result[OperandReadResult, PdfContentError] = try? ContentOperandReader::new(
    b"stream",
  ).read_next()
  match result {
    Err(IllegalOperand(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("stream"), true)
    }
    _ => fail("expected stream-like keyword error")
  }
}

///|
test "content operand reader rejects unterminated arrays" {
  let result : Result[OperandReadResult, PdfContentError] = try? ContentOperandReader::new(
    b"[1 2",
  ).read_next()
  match result {
    Err(MalformedSyntax(offset, reason)) => {
      assert_eq(offset, 4L)
      assert_eq(reason.contains("array"), true)
    }
    _ => fail("expected array eof error")
  }
}

///|
test "content operand reader rejects unterminated dictionaries" {
  let result : Result[OperandReadResult, PdfContentError] = try? ContentOperandReader::new(
    b"<< /Key 1",
  ).read_next()
  match result {
    Err(MalformedSyntax(offset, reason)) => {
      assert_eq(offset, 9L)
      assert_eq(reason.contains("dictionary"), true)
    }
    _ => fail("expected dictionary eof error")
  }
}
