///|
test "text matrix translation and replacement follow pdf order" {
  let current = TextMatrix::translation(10.0, 20.0)
  let moved = current.translated(3.0, 4.0)
  let point = moved.transform_point(TextPoint::new(0.0, 0.0))
  assert_eq(point.x, 13.0)
  assert_eq(point.y, 24.0)

  let replacement = TextMatrix::from_six(2.0, 0.0, 0.0, 3.0, 5.0, 7.0)
  assert_eq(moved.replace_with(replacement) == replacement, true)
}

///|
test "text rendering matrix applies font size scaling rise text matrix and ctm" {
  let text_matrix = TextMatrix::translation(10.0, 20.0)
  let ctm = TextMatrix::translation(100.0, 200.0)
  let rendering = TextRenderingMatrix::from_text_state(
    text_matrix, 12.0, 0.5, 3.0, ctm,
  )
  let origin = rendering.matrix.transform_point(TextPoint::new(0.0, 0.0))
  assert_eq(origin.x, 110.0)
  assert_eq(origin.y, 223.0)
  let unit = rendering.matrix.transform_point(TextPoint::new(1.0, 1.0))
  assert_eq(unit.x, 116.0)
  assert_eq(unit.y, 235.0)
}
