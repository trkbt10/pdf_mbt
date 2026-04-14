///|
test "public function foundation exposes limits and unresolved sources" {
  let limits = @functions.FunctionLimits::default()
  assert_eq(limits.max_input_dimensions > 0, true)
  let object_id = @objects.ObjectId::{ object_number: 11, generation_number: 0 }
  let source = @functions.parse_function_object(
    @objects.PdfObject::Ref(object_id),
    limits,
    0L,
  )
  match source {
    IndirectFunction(found) => assert_eq(found == object_id, true)
    _ => fail("expected indirect source")
  }
}
