///|
test "graphics object context permits path lifecycle and rejects state inside path" {
  let context = GraphicsObjectContext::new()
  context.accept(@content.StandardContentOperator::MoveTo, 1L)
  assert_eq(context.level == GraphicsObjectLevel::PathObject, true)
  context.accept(@content.StandardContentOperator::LineTo, 2L)
  context.accept(@content.StandardContentOperator::ClipNonzero, 3L)
  let bad : Result[Unit, PdfGraphicsError] = try? context.accept(
    @content.StandardContentOperator::SetLineWidth,
    4L,
  )
  match bad {
    Err(InvalidObjectContext(offset, reason)) => {
      assert_eq(offset, 4L)
      assert_eq(reason.contains("path object"), true)
    }
    _ => fail("expected invalid path context")
  }
}

///|
test "graphics object context tracks text boundaries" {
  let context = GraphicsObjectContext::new()
  context.accept(@content.StandardContentOperator::BeginText, 1L)
  assert_eq(context.level == GraphicsObjectLevel::TextObject, true)
  let nested : Result[Unit, PdfGraphicsError] = try? context.accept(
    @content.StandardContentOperator::BeginText,
    2L,
  )
  match nested {
    Err(InvalidObjectContext(offset, reason)) => {
      assert_eq(offset, 2L)
      assert_eq(reason.contains("BT"), true)
    }
    _ => fail("expected nested text error")
  }
  context.accept(@content.StandardContentOperator::EndText, 3L)
  assert_eq(context.level == GraphicsObjectLevel::ContentStreamLevel, true)
}
