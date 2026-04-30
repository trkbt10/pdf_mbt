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
test "knockout group uses topmost object over group backdrop" {
  let result = composite_knockout_group(KnockoutGroupCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    objects: [
      elementary_test_object([1.0, 0.0, 0.0], 0.5),
      elementary_test_object([0.0, 1.0, 0.0], 0.5),
    ],
    fractional_shape_averaging: false,
    nested_knockout: true,
  })
  assert_eq(result.colour, Some([0.0, 0.5, 0.5]))
}

///|
test "fractional knockout averages object shape with previous result" {
  let result = composite_knockout_group(KnockoutGroupCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    objects: [elementary_test_object_with_shape([1.0, 0.0, 0.0], 0.25, 1.0)],
    fractional_shape_averaging: true,
    nested_knockout: true,
  })
  assert_eq(result.shape, 1.0)
  assert_eq(result.colour, Some([0.0625, 0.0, 0.9375]))
}

///|
test "combined fill stroke paint is composited as an implicit knockout group" {
  let result = composite_combined_paint(CombinedPaintCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([1.0, 1.0, 1.0]),
    fill: Some(elementary_test_object([1.0, 0.0, 0.0], 1.0)),
    stroke: Some(elementary_test_object([0.0, 0.0, 1.0], 1.0)),
    text_mode: "knockout",
  })
  assert_eq(result.colour, Some([0.0, 0.0, 1.0]))
}

///|
test "soft mask alpha and image samples route through opacity by default" {
  let alpha = evaluate_transparency_mask(TransparencyMaskEvaluationInput::{
    source: TransparencyMaskSampleSource::AlphaMaskSamples([0.25]),
    sample_index: 0,
    backdrop: [1.0, 1.0, 1.0],
    matte: None,
    transfer_scale: 1.0,
    alpha_is_shape: false,
  })
  let image = evaluate_transparency_mask(TransparencyMaskEvaluationInput::{
    source: TransparencyMaskSampleSource::ImageMaskSamples([0.75]),
    sample_index: 0,
    backdrop: [1.0, 1.0, 1.0],
    matte: None,
    transfer_scale: 1.0,
    alpha_is_shape: false,
  })
  assert_eq(alpha.opacity_multiplier, 0.25)
  assert_eq(image.opacity_multiplier, 0.75)
}

///|
test "soft mask luminosity uses backdrop outside bounds and transfer scale" {
  let mask = evaluate_transparency_mask(TransparencyMaskEvaluationInput::{
    source: TransparencyMaskSampleSource::LuminosityMaskSamples([
      [1.0, 0.0, 0.0],
    ]),
    sample_index: 5,
    backdrop: [0.0, 1.0, 0.0],
    matte: None,
    transfer_scale: 0.5,
    alpha_is_shape: true,
  })
  assert_eq(mask.mask_value, 0.295)
  assert_eq(mask.shape_multiplier, 0.295)
  assert_eq(mask.opacity_multiplier, 1.0)
}

///|
test "embedded soft mask matte keeps zero alpha division defined" {
  let mask = evaluate_transparency_mask(TransparencyMaskEvaluationInput::{
    source: TransparencyMaskSampleSource::EmbeddedImageMaskSamples([0.0]),
    sample_index: 0,
    backdrop: [0.0, 0.0, 0.0],
    matte: Some([1.0, 1.0, 1.0]),
    transfer_scale: 1.0,
    alpha_is_shape: false,
  })
  let object = apply_transparency_mask_to_object(
    elementary_test_object([1.0, 0.0, 0.0], 1.0),
    mask,
  )
  assert_eq(object.mask_opacity, 0.0)
  assert_eq(object.mask_shape, 1.0)
}

///|
test "pattern transparency composites over shading background" {
  let result = composite_pattern_transparency(PatternTransparencyCompositeInput::{
    backdrop: TransparencyCompositeSample::opaque([0.0, 0.0, 1.0]),
    pattern_objects: [elementary_test_object([1.0, 0.0, 0.0], 0.5)],
    shading_background: Some(
      TransparencyCompositeSample::opaque([0.0, 1.0, 0.0]),
    ),
  })
  assert_eq(result.colour, Some([0.5, 0.0, 0.5]))
}

///|
fn elementary_test_object(
  colour : Array[Double],
  opacity : Double,
) -> ElementaryObjectCompositeInput {
  elementary_test_object_with_shape(colour, 1.0, opacity)
}

///|
fn elementary_test_object_with_shape(
  colour : Array[Double],
  shape : Double,
  opacity : Double,
) -> ElementaryObjectCompositeInput {
  ElementaryObjectCompositeInput::{
    backdrop: TransparencyCompositeSample::transparent(),
    source_colour: Some(colour),
    backdrop_colour: None,
    source_shape: shape,
    mask_shape: 1.0,
    constant_shape: 1.0,
    source_opacity: 1.0,
    mask_opacity: 1.0,
    constant_opacity: opacity,
    blend_mode: @graphics.BlendMode::Normal,
    subtractive_space: false,
  }
}
