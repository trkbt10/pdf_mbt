///|
test "parse decoded content preserves resources and decoded byte offsets" {
  let resources_dict : @objects.PdfDictionary = Map::new()
  let font_dict : @objects.PdfDictionary = Map::new()
  font_dict[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Integer(1L)
  resources_dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    font_dict,
  )
  let resources = ContentResources::from_dictionary(resources_dict)
  let stream = parse_decoded_content(b"10 20 Td", resources)

  assert_eq(
    stream.resources.lookup_resource(Font, @objects.PdfName::new(b"F1")) ==
    Some(@objects.PdfObject::Integer(1L)),
    true,
  )
  match stream.instructions[0] {
    Operation(operation) => {
      assert_eq(operation.operator == MoveTextPosition, true)
      assert_eq(operation.offset, 6L)
    }
    _ => fail("expected operation")
  }
}

///|
test "parse content stream decodes stream bytes before parsing" {
  let dict : @objects.PdfDictionary = Map::new()
  let pdf_stream = @objects.PdfStream::{ dict, data: b"q Q" }
  let content = parse_content_stream(pdf_stream, ContentResources::empty())
  assert_eq(content.instructions.length(), 2)
  match content.instructions[1] {
    Operation(operation) =>
      assert_eq(operation.operator == RestoreGraphicsState, true)
    _ => fail("expected restore graphics state")
  }
}

///|
test "parse content stream wraps filter failures as content errors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Crypt"),
  )
  let pdf_stream = @objects.PdfStream::{ dict, data: b"ignored" }
  let result : Result[ContentStream, PdfContentError] = try? parse_content_stream(
    pdf_stream,
    ContentResources::empty(),
  )
  match result {
    Err(FilterError(offset, UnsupportedFilter(name))) => {
      assert_eq(offset, 0L)
      assert_eq(name, "Crypt")
    }
    _ => fail("expected wrapped filter failure")
  }
}
