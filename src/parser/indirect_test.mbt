///|
test "parser reads indirect object definitions" {
  let indirect = @parser.parse_indirect_object(b"12 0 obj (Brillig) endobj")
  assert_eq(
    indirect ==
    @objects.IndirectObject::{
      id: @objects.ObjectId::{ object_number: 12, generation_number: 0 },
      value: @objects.PdfObject::String(b"Brillig"),
      start_offset: 0L,
      end_offset: 25L,
    },
    true,
  )
}

///|
test "parser rejects invalid indirect object identifiers" {
  let invalid_object_number : Result[
    @objects.IndirectObject,
    @objects.PdfParseError,
  ] = try? @parser.parse_indirect_object(b"0 0 obj null endobj")
  match invalid_object_number {
    Err(InvalidIndirectObject(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("object number"), true)
    }
    _ => fail("expected invalid object number")
  }

  let invalid_generation : Result[
    @objects.IndirectObject,
    @objects.PdfParseError,
  ] = try? @parser.parse_indirect_object(b"1 -1 obj null endobj")
  match invalid_generation {
    Err(InvalidIndirectObject(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("generation number"), true)
    }
    _ => fail("expected invalid generation number")
  }
}

///|
test "parser preserves indirect object identity by object id pair" {
  let first = @parser.parse_indirect_object(b"7 0 obj null endobj")
  let second = @parser.parse_indirect_object(b"7 0 obj null endobj")
  assert_eq(first.id == second.id, true)
  assert_eq(
    first.id == @objects.ObjectId::{ object_number: 7, generation_number: 0 },
    true,
  )
}
