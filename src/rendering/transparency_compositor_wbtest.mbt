///|
test "elementary compositor blends semi transparent fills over backdrop" {
  let result = composite_elementary_object(ElementaryObjectCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    source_colour: Some([1.0, 0.0, 0.0]),
    backdrop_colour: None,
    source_shape: 1.0,
    mask_shape: 1.0,
    constant_shape: 1.0,
    source_opacity: 1.0,
    mask_opacity: 1.0,
    constant_opacity: 0.5,
    blend_mode: @graphics.BlendMode::Normal,
    subtractive_space: false,
  })
  assert_eq(result.shape, 1.0)
  assert_eq(result.opacity, 1.0)
  assert_eq(result.alpha, 1.0)
  assert_eq(result.colour, Some([0.5, 0.0, 0.5]))
}

///|
test "elementary compositor preserves undefined colour when alpha is zero" {
  let result = composite_elementary_object(ElementaryObjectCompositeInput::{
    backdrop: TransparencyCompositeSample::transparent(),
    source_colour: Some([1.0]),
    backdrop_colour: None,
    source_shape: 0.0,
    mask_shape: 1.0,
    constant_shape: 1.0,
    source_opacity: 1.0,
    mask_opacity: 1.0,
    constant_opacity: 1.0,
    blend_mode: @graphics.BlendMode::Multiply,
    subtractive_space: false,
  })
  assert_eq(result.alpha, 0.0)
  assert_eq(result.colour is None, true)
}
