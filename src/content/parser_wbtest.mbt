///|
test "compatibility tracker maintains balanced BX EX depth" {
  let tracker = CompatibilityTracker::new()
  assert_eq(tracker.depth(), 0)
  assert_eq(tracker.is_active(), false)

  tracker.begin()
  tracker.begin()
  assert_eq(tracker.depth(), 2)
  assert_eq(tracker.is_active(), true)

  tracker.end(4L)
  tracker.end(6L)
  assert_eq(tracker.depth(), 0)

  let result : Result[Unit, PdfContentError] = try? tracker.end(8L)
  match result {
    Err(MalformedSyntax(offset, reason)) => {
      assert_eq(offset, 8L)
      assert_eq(reason.contains("EX"), true)
    }
    _ => fail("expected unbalanced EX to fail")
  }
}

///|
test "parser raises unknown operator outside compatibility sections" {
  let parser = ContentStreamParser::new(b"1 2 ZZ")
  let result : Result[ContentOperation?, PdfContentError] = try? parser.parse_next_operation()
  match result {
    Err(UnknownOperator(offset, keyword)) => {
      assert_eq(offset, 4L)
      assert_eq(keyword, "ZZ")
    }
    _ => fail("expected unknown operator error")
  }
}

///|
test "parser skips unknown operators and operands inside compatibility sections" {
  let parser = ContentStreamParser::new(b"BX 1 2 ZZ 3 4 cm EX q")

  match parser.parse_next_operation() {
    Some(operation) => {
      assert_eq(operation.operator == BeginCompatibility, true)
      assert_eq(operation.operands.length(), 0)
      assert_eq(parser.compatibility_depth(), 1)
    }
    None => fail("expected BX operation")
  }

  match parser.parse_next_operation() {
    Some(operation) => {
      assert_eq(operation.operator == ConcatMatrix, true)
      assert_eq(operation.operands.length(), 2)
      assert_eq(operation.operands[0] == @objects.PdfObject::Integer(3L), true)
      assert_eq(operation.operands[1] == @objects.PdfObject::Integer(4L), true)
    }
    None => fail("expected cm operation")
  }

  match parser.parse_next_operation() {
    Some(operation) => {
      assert_eq(operation.operator == EndCompatibility, true)
      assert_eq(parser.compatibility_depth(), 0)
    }
    None => fail("expected EX operation")
  }

  match parser.parse_next_operation() {
    Some(operation) => {
      assert_eq(operation.operator == SaveGraphicsState, true)
      assert_eq(operation.operands.length(), 0)
    }
    None => fail("expected q operation")
  }
}

///|
test "parser rejects unterminated compatibility sections at end of input" {
  let parser = ContentStreamParser::new(b"BX 1 2 ZZ")
  match parser.parse_next_operation() {
    Some(operation) => assert_eq(operation.operator == BeginCompatibility, true)
    None => fail("expected BX operation")
  }

  let result : Result[ContentOperation?, PdfContentError] = try? parser.parse_next_operation()
  match result {
    Err(MalformedSyntax(offset, reason)) => {
      assert_eq(offset, 9L)
      assert_eq(reason.contains("BX"), true)
    }
    _ => fail("expected unterminated compatibility section")
  }
}
