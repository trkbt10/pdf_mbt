///|
test "syntax error preserves offset and reason" {
  let error = PdfContentError::MalformedSyntax(17L, "unexpected token")
  match error {
    MalformedSyntax(offset, reason) => {
      assert_eq(offset, 17L)
      assert_eq(reason, "unexpected token")
    }
    _ => fail("expected a malformed syntax error")
  }
}

///|
test "inline image error preserves offset and reason" {
  let error = PdfContentError::InlineImageFailure(42L, "missing EI")
  match error {
    InlineImageFailure(offset, reason) => {
      assert_eq(offset, 42L)
      assert_eq(reason, "missing EI")
    }
    _ => fail("expected an inline image failure")
  }
}

///|
test "parse failures are wrapped without changing the owning error type" {
  let parse_error = @objects.PdfParseError::InvalidNumber(9L, b"1.2.3")
  let error = PdfContentError::ParseError(88L, parse_error)
  match error {
    ParseError(offset, inner) => {
      assert_eq(offset, 88L)
      assert_eq(inner == parse_error, true)
    }
    _ => fail("expected a wrapped parse error")
  }
}

///|
test "filter failures are wrapped without changing the owning error type" {
  let filter_error = @filters.PdfFilterError::UnsupportedFilter("Crypt")
  let error = PdfContentError::FilterError(91L, filter_error)
  match error {
    FilterError(offset, inner) => {
      assert_eq(offset, 91L)
      assert_eq(inner == filter_error, true)
    }
    _ => fail("expected a wrapped filter error")
  }
}

///|
test "operator and resource diagnostics preserve offsets and reasons" {
  let operator_error = PdfContentError::UnknownOperator(7L, "XX")
  match operator_error {
    UnknownOperator(offset, name) => {
      assert_eq(offset, 7L)
      assert_eq(name, "XX")
    }
    _ => fail("expected an unknown operator error")
  }

  let resource_error = PdfContentError::ResourceFailure(11L, "missing /Resources")
  match resource_error {
    ResourceFailure(offset, reason) => {
      assert_eq(offset, 11L)
      assert_eq(reason, "missing /Resources")
    }
    _ => fail("expected a resource failure error")
  }
}
