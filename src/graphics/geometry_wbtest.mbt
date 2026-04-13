///|
test "graphics matrix transforms points and computes inverse" {
  let matrix = GraphicsMatrix::from_six(2.0, 0.0, 0.0, 3.0, 5.0, 7.0)
  let point = matrix.transform_point(GraphicsPoint::new(4.0, 6.0))
  assert_eq(point.x, 13.0)
  assert_eq(point.y, 25.0)
  assert_eq(matrix.determinant(), 6.0)
  match matrix.inverse() {
    Some(inverse) => {
      let restored = inverse.transform_point(point)
      assert_eq(restored.x.is_close(4.0), true)
      assert_eq(restored.y.is_close(6.0), true)
    }
    None => fail("expected invertible matrix")
  }
}

///|
test "graphics matrix concatenation follows pdf premultiplication" {
  let current = GraphicsMatrix::translation(10.0, 20.0)
  let scale = GraphicsMatrix::scale(2.0, 3.0)
  let combined = GraphicsMatrix::concat(scale, current)
  let point = combined.transform_point(GraphicsPoint::new(1.0, 1.0))
  assert_eq(point.x, 12.0)
  assert_eq(point.y, 23.0)
}

///|
test "common transformations expose rotation and skew" {
  let rotated_matrix = GraphicsMatrix::rotation(3.141592653589793 / 2.0)
  let rotated = rotated_matrix.transform_point(GraphicsPoint::new(1.0, 0.0))
  assert_eq(rotated.x.is_close(0.0, absolute_tolerance=0.0000001), true)
  assert_eq(rotated.y.is_close(1.0, absolute_tolerance=0.0000001), true)
  let skewed = GraphicsMatrix::skew(0.0, 0.0).transform_point(
    GraphicsPoint::new(2.0, 3.0),
  )
  assert_eq(skewed == GraphicsPoint::new(2.0, 3.0), true)
}
