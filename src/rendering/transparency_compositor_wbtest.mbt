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

///|
test "transparency group composites nested objects from isolated backdrop" {
  let result = composite_transparency_group(TransparencyGroupCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    initial_backdrop: TransparencyCompositeSample::transparent(),
    objects: [
      elementary_test_object([1.0, 0.0, 0.0], 0.5),
      elementary_test_object([0.0, 1.0, 0.0], 0.5),
    ],
    backdrop_mode: TransparencyGroupBackdropMode::IsolatedGroupBackdrop,
    blending_colour_space_components: 3,
  })
  assert_eq(result.group_shape, 1.0)
  assert_eq(result.group_opacity, 0.75)
  assert_eq(result.group_alpha, 0.75)
  assert_eq(
    result.group_colour,
    Some([0.3333333333333333, 0.6666666666666666, 0.0]),
  )
}

///|
test "non isolated and page groups choose the required backdrop" {
  let object = elementary_test_object([1.0, 0.0, 0.0], 0.5)
  let non_isolated = composite_transparency_group(TransparencyGroupCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    initial_backdrop: TransparencyCompositeSample::opaque([0.0, 1.0, 0.0]),
    objects: [object],
    backdrop_mode: TransparencyGroupBackdropMode::NonIsolatedGroupBackdrop,
    blending_colour_space_components: 3,
  })
  let page = composite_transparency_group(TransparencyGroupCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    initial_backdrop: TransparencyCompositeSample::opaque([0.0, 1.0, 0.0]),
    objects: [object],
    backdrop_mode: TransparencyGroupBackdropMode::PageGroupBackdrop,
    blending_colour_space_components: 3,
  })
  assert_eq(non_isolated.group_colour, Some([0.5, 0.0, 0.5]))
  assert_eq(page.group_colour, Some([0.5, 0.5, 0.0]))
}

///|
fn elementary_test_object(
  colour : Array[Double],
  opacity : Double,
) -> ElementaryObjectCompositeInput {
  ElementaryObjectCompositeInput::{
    backdrop: TransparencyCompositeSample::transparent(),
    source_colour: Some(colour),
    backdrop_colour: None,
    source_shape: 1.0,
    mask_shape: 1.0,
    constant_shape: 1.0,
    source_opacity: 1.0,
    mask_opacity: 1.0,
    constant_opacity: opacity,
    blend_mode: @graphics.BlendMode::Normal,
    subtractive_space: false,
  }
}
