///|
test "graphics object context permits path lifecycle and tolerates state mid-path" {
  let context = GraphicsObjectContext::new()
  context.accept(@content.StandardContentOperator::MoveTo, 1L)
  assert_eq(context.level == GraphicsObjectLevel::PathObject, true)
  context.accept(@content.StandardContentOperator::LineTo, 2L)
  context.accept(@content.StandardContentOperator::ClipNonzero, 3L)
  // ISO 32000-2 §8.2 nominally restricts the path-object scope to
  // path-construction / clipping / painting operators, but real producers
  // (notably Canva-style slide exporters) interleave graphics-state and
  // colour selectors mid-path before painting — a typical sequence is
  // `re /gs3 gs f` to mark an alpha-0 structural rectangle. We tolerate
  // those intermediate operators rather than aborting the whole graphics
  // walk on a single permissive marker.
  context.accept(@content.StandardContentOperator::SetLineWidth, 4L)
  assert_eq(context.level == GraphicsObjectLevel::PathObject, true)
  context.accept(@content.StandardContentOperator::SetExtGState, 5L)
  assert_eq(context.level == GraphicsObjectLevel::PathObject, true)
  // A path-painting operator still closes the path and returns to content
  // level.
  context.accept(@content.StandardContentOperator::FillNonzero, 6L)
  assert_eq(context.level == GraphicsObjectLevel::ContentStreamLevel, true)
}

///|
test "graphics object context rejects text-begin and inline-image inside a pending path" {
  let context = GraphicsObjectContext::new()
  context.accept(@content.StandardContentOperator::Rectangle, 1L)
  let bt : Result[Unit, PdfGraphicsError] = try? context.accept(
    @content.StandardContentOperator::BeginText,
    2L,
  )
  match bt {
    Err(InvalidObjectContext(offset, reason)) => {
      assert_eq(offset, 2L)
      assert_eq(reason.contains("BT"), true)
    }
    _ => fail("expected BT inside path to be rejected")
  }
  let do_op : Result[Unit, PdfGraphicsError] = try? context.accept(
    @content.StandardContentOperator::InvokeXObject,
    3L,
  )
  match do_op {
    Err(InvalidObjectContext(offset, reason)) => {
      assert_eq(offset, 3L)
      assert_eq(reason.contains("XObject"), true)
    }
    _ => fail("expected XObject Do inside path to be rejected")
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
