///|
test "transparency math uses PDF safe ratio and alpha union conventions" {
  assert_eq(safe_ratio(0.0, 0.0), 0.0)
  assert_eq(safe_ratio(0.25, 0.5), 0.5)
  assert_eq(transparency_alpha(0.5, 0.25), 0.125)
  assert_eq(union_alpha(0.25, 0.5), 0.625)
}

///|
test "transparency sample keeps shape opacity and undefined colour separate" {
  let transparent = TransparencySample::new(Some([0.7, 1.2, -1.0]), 1.0, 0.0)
  assert_eq(transparent.shape, 1.0)
  assert_eq(transparent.opacity, 0.0)
  assert_eq(transparent.alpha(), 0.0)
  assert_eq(transparent.colour is None, true)

  let shaped = TransparencySample::new(Some([0.7, 1.2, -1.0]), 0.5, 0.5)
  assert_eq(shaped.shape, 0.5)
  assert_eq(shaped.opacity, 0.5)
  assert_eq(shaped.alpha(), 0.25)
  assert_eq(shaped.colour, Some([0.7, 1.0, 0.0]))
}

///|
test "transparency vector helpers normalize missing and out of range values" {
  assert_eq(normalize_transparency_vector([-0.2, 0.4, 2.0]), [0.0, 0.4, 1.0])
  assert_eq(vector_with_component_count([0.25], 3, 1.5), [0.25, 1.0, 1.0])
}
