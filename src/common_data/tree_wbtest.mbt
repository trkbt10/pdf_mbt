///|
test "tree key comparison follows byte and integer ordering" {
  assert_eq(compare_name_tree_keys(b"a", b"aa"), -1)
  assert_eq(compare_name_tree_keys(b"b", b"aa"), 1)
  assert_eq(compare_name_tree_keys(b"same", b"same"), 0)
  assert_eq(compare_number_tree_keys(1, 2), -1)
  assert_eq(compare_number_tree_keys(3, 2), 1)
}

///|
test "name tree pairs and limits validate shape and ordering" {
  let entries = validate_name_tree_pairs(
    @objects.PdfObject::Array([
      @objects.PdfObject::String(b"a"),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::String(b"aa"),
      @objects.PdfObject::Name(@objects.PdfName::new(b"V")),
    ]),
  )
  assert_eq(entries.length(), 2)
  assert_eq(entries[1].key, b"aa")
  let (lower, upper) = validate_name_tree_limits(
    @objects.PdfObject::Array([
      @objects.PdfObject::String(b"a"),
      @objects.PdfObject::String(b"z"),
    ]),
  )
  assert_eq(lower, b"a")
  assert_eq(upper, b"z")
  let duplicate : Result[Array[PdfNameTreeEntry], PdfCommonDataError] = try? validate_name_tree_pairs(
    @objects.PdfObject::Array([
      @objects.PdfObject::String(b"a"),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::String(b"a"),
      @objects.PdfObject::Integer(2L),
    ]),
  )
  match duplicate {
    Err(PdfCommonDataError::InvalidTreeNode(_)) => ()
    _ => fail("expected duplicate key rejection")
  }
}

///|
test "number tree pairs validate arity key types and ordering" {
  let entries = validate_number_tree_pairs(
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::String(b"one"),
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::String(b"two"),
    ]),
  )
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].key, 1)
  let descending : Result[Array[PdfNumberTreeEntry], PdfCommonDataError] = try? validate_number_tree_pairs(
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(2L),
      @objects.PdfObject::String(b"two"),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::String(b"one"),
    ]),
  )
  match descending {
    Err(PdfCommonDataError::InvalidTreeNode(_)) => ()
    _ => fail("expected descending key rejection")
  }
  let odd : Result[Array[PdfNumberTreeEntry], PdfCommonDataError] = try? validate_number_tree_pairs(
    @objects.PdfObject::Array([@objects.PdfObject::Integer(1L)]),
  )
  match odd {
    Err(PdfCommonDataError::InvalidTreeNode(_)) => ()
    _ => fail("expected arity rejection")
  }
}
