///|
test "rectangle parser preserves source coordinates and zero sizes" {
  let rect = parse_pdf_rectangle(
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Real(2.5),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Real(2.5),
    ]),
  )
  assert_eq(rect.left, 1.0)
  assert_eq(rect.bottom, 2.5)
  assert_eq(rect.right, 1.0)
  assert_eq(rect.top, 2.5)
}

///|
test "rectangle parser rejects malformed arrays" {
  let wrong_arity : Result[PdfRectangle, PdfCommonDataError] = try? parse_pdf_rectangle(
    @objects.PdfObject::Array([@objects.PdfObject::Integer(1L)]),
  )
  match wrong_arity {
    Err(PdfCommonDataError::InvalidRectangle(_)) => ()
    _ => fail("expected arity rejection")
  }
  let non_number : Result[PdfRectangle, PdfCommonDataError] = try? parse_pdf_rectangle(
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::String(b"x"),
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::Integer(3L),
    ]),
  )
  match non_number {
    Err(PdfCommonDataError::InvalidRectangle(_)) => ()
    _ => fail("expected number rejection")
  }
}
