///|
test "current path tracks move override lines curves rectangles and close" {
  let path = CurrentPath::new()
  path.move_to(GraphicsPoint::new(1.0, 1.0))
  path.move_to(GraphicsPoint::new(2.0, 2.0))
  path.line_to(GraphicsPoint::new(3.0, 2.0), 1L)
  path.curve_to(
    GraphicsPoint::new(4.0, 2.0),
    GraphicsPoint::new(5.0, 3.0),
    GraphicsPoint::new(6.0, 4.0),
    1L,
  )
  path.close_path(1L)
  path.rectangle(GraphicsRect::new(10.0, 20.0, 30.0, 40.0))
  let snapshot = path.snapshot()
  assert_eq(snapshot.subpaths.length(), 2)
  assert_eq(snapshot.subpaths[0].start == GraphicsPoint::new(2.0, 2.0), true)
  assert_eq(snapshot.subpaths[0].segments.length(), 3)
  assert_eq(snapshot.subpaths[0].closed, true)
  assert_eq(snapshot.subpaths[1].segments.length(), 4)
}

///|
test "current path reports undefined current point errors" {
  let path = CurrentPath::new()
  let result : Result[Unit, PdfGraphicsError] = try? path.line_to(
    GraphicsPoint::new(1.0, 1.0),
    11L,
  )
  match result {
    Err(InvalidPathState(offset, reason)) => {
      assert_eq(offset, 11L)
      assert_eq(reason.contains("current point"), true)
    }
    _ => fail("expected invalid path state")
  }
}
