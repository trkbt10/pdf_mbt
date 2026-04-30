///|
pub(all) struct TransparencyCompositeSample {
  colour : Array[Double]?
  shape : Double
  opacity : Double
  alpha : Double
} derive(Eq, Debug)

///|
pub(all) struct ElementaryObjectCompositeInput {
  backdrop : TransparencyCompositeSample
  source_colour : Array[Double]?
  backdrop_colour : Array[Double]?
  source_shape : Double
  mask_shape : Double
  constant_shape : Double
  source_opacity : Double
  mask_opacity : Double
  constant_opacity : Double
  blend_mode : @graphics.BlendMode
  subtractive_space : Bool
} derive(Eq, Debug)

///|
pub(all) enum TransparencyGroupBackdropMode {
  IsolatedGroupBackdrop
  NonIsolatedGroupBackdrop
  PageGroupBackdrop
} derive(Eq, Debug)

///|
pub(all) struct TransparencyGroupCompositeInput {
  backdrop : TransparencyCompositeSample
  initial_backdrop : TransparencyCompositeSample
  objects : Array[ElementaryObjectCompositeInput]
  backdrop_mode : TransparencyGroupBackdropMode
  blending_colour_space_components : Int
} derive(Eq, Debug)

///|
pub(all) struct TransparencyGroupCompositeResult {
  group_colour : Array[Double]?
  group_shape : Double
  group_opacity : Double
  group_alpha : Double
  composited : TransparencyCompositeSample
} derive(Eq, Debug)

///|
pub(all) struct KnockoutGroupCompositeInput {
  backdrop : TransparencyCompositeSample
  objects : Array[ElementaryObjectCompositeInput]
  fractional_shape_averaging : Bool
  nested_knockout : Bool
} derive(Eq, Debug)

///|
pub(all) struct CombinedPaintCompositeInput {
  backdrop : TransparencyCompositeSample
  fill : ElementaryObjectCompositeInput?
  stroke : ElementaryObjectCompositeInput?
  text_mode : String
} derive(Eq, Debug)

///|
pub(all) struct PatternTransparencyCompositeInput {
  backdrop : TransparencyCompositeSample
  pattern_objects : Array[ElementaryObjectCompositeInput]
  shading_background : TransparencyCompositeSample?
} derive(Eq, Debug)

///|
pub(all) enum TransparencyMaskSampleSource {
  AlphaMaskSamples(Array[Double])
  LuminosityMaskSamples(Array[Array[Double]])
  ImageMaskSamples(Array[Double])
  EmbeddedImageMaskSamples(Array[Double])
} derive(Eq, Debug)

///|
pub(all) struct TransparencyMaskEvaluationInput {
  source : TransparencyMaskSampleSource
  sample_index : Int
  backdrop : Array[Double]
  matte : Array[Double]?
  transfer_scale : Double
  alpha_is_shape : Bool
} derive(Eq, Debug)

///|
pub(all) struct TransparencyMaskApplication {
  mask_value : Double
  shape_multiplier : Double
  opacity_multiplier : Double
} derive(Eq, Debug)

///|
pub fn composite_elementary_object(
  input : ElementaryObjectCompositeInput,
) -> TransparencyCompositeSample {
  let source_shape = transparency_component(input.source_shape) *
    transparency_component(input.mask_shape) *
    transparency_component(input.constant_shape)
  let source_opacity = transparency_component(input.source_opacity) *
    transparency_component(input.mask_opacity) *
    transparency_component(input.constant_opacity)
  let source_alpha = transparency_alpha(source_shape, source_opacity)
  let backdrop_alpha = input.backdrop.alpha
  let result_alpha = union_alpha(backdrop_alpha, source_alpha)
  let result_shape = union_alpha(input.backdrop.shape, source_shape)
  let result_opacity = safe_ratio(result_alpha, result_shape)
  let result_colour = if result_alpha == 0.0 {
    None
  } else {
    let count = component_count_for_composite(input)
    let cb = vector_with_component_count(
      input.backdrop_colour.unwrap_or(input.backdrop.colour.unwrap_or([])),
      count,
      0.0,
    )
    let cs = vector_with_component_count(
      input.source_colour.unwrap_or([]),
      count,
      0.0,
    )
    let blended = blend_vector(
      input.blend_mode,
      cb,
      cs,
      subtractive=input.subtractive_space,
    )
    let result : Array[Double] = []
    for i in 0..<count {
      let value = safe_ratio(
        (1.0 - source_alpha) * backdrop_alpha * cb[i] +
        source_alpha *
        ((1.0 - backdrop_alpha) * cs[i] + backdrop_alpha * blended[i]),
        result_alpha,
      )
      result.push(transparency_component(value))
    }
    Some(result)
  }
  TransparencyCompositeSample::{
    colour: result_colour,
    shape: result_shape,
    opacity: result_opacity,
    alpha: result_alpha,
  }
}

///|
pub fn composite_pattern_transparency(
  input : PatternTransparencyCompositeInput,
) -> TransparencyCompositeSample {
  let initial = input.shading_background.unwrap_or(input.backdrop)
  let group = composite_transparency_group(TransparencyGroupCompositeInput::{
    backdrop: input.backdrop,
    initial_backdrop: initial,
    objects: input.pattern_objects,
    backdrop_mode: TransparencyGroupBackdropMode::NonIsolatedGroupBackdrop,
    blending_colour_space_components: knockout_component_count(
      input.backdrop,
      initial,
    ),
  })
  group.composited
}

///|
pub fn composite_transparency_group(
  input : TransparencyGroupCompositeInput,
) -> TransparencyGroupCompositeResult {
  let group_backdrop = select_group_backdrop(input)
  let mut current = group_backdrop
  for object in input.objects {
    current = composite_elementary_object(
      elementary_object_with_backdrop(object, current),
    )
  }
  let group_shape = transparency_component(current.shape)
  let group_alpha = transparency_component(current.alpha)
  let group_opacity = if group_shape == 0.0 {
    0.0
  } else {
    safe_ratio(group_alpha, group_shape)
  }
  let group_colour = normalize_group_colour(current.colour, input)
  TransparencyGroupCompositeResult::{
    group_colour,
    group_shape,
    group_opacity,
    group_alpha,
    composited: current,
  }
}

///|
pub fn composite_knockout_group(
  input : KnockoutGroupCompositeInput,
) -> TransparencyCompositeSample {
  let mut result = input.backdrop
  let mut accumulated_shape = 0.0
  for object in input.objects {
    let object_shape = transparency_component(object.source_shape) *
      transparency_component(object.mask_shape) *
      transparency_component(object.constant_shape)
    let knockout_backdrop = knockout_backdrop_for_object(
      input.backdrop,
      result,
      accumulated_shape,
      input.nested_knockout,
    )
    let object_result = composite_elementary_object(
      elementary_object_with_backdrop(object, knockout_backdrop),
    )
    result = merge_knockout_result(
      result,
      object_result,
      object_shape,
      input.fractional_shape_averaging,
    )
    accumulated_shape = union_alpha(accumulated_shape, object_shape)
  }
  result
}

///|
pub fn composite_combined_paint(
  input : CombinedPaintCompositeInput,
) -> TransparencyCompositeSample {
  let parts : Array[ElementaryObjectCompositeInput] = []
  match input.fill {
    Some(fill) => parts.push(fill)
    None => ()
  }
  match input.stroke {
    Some(stroke) => parts.push(stroke)
    None => ()
  }
  composite_knockout_group(KnockoutGroupCompositeInput::{
    backdrop: input.backdrop,
    objects: parts,
    fractional_shape_averaging: true,
    nested_knockout: input.text_mode != "non-knockout",
  })
}

///|
pub fn evaluate_transparency_mask(
  input : TransparencyMaskEvaluationInput,
) -> TransparencyMaskApplication {
  let raw = match input.source {
    AlphaMaskSamples(values) => mask_sample_at(values, input.sample_index)
    ImageMaskSamples(values) => mask_sample_at(values, input.sample_index)
    EmbeddedImageMaskSamples(values) =>
      embedded_mask_sample_at(values, input.sample_index, input.matte)
    LuminosityMaskSamples(values) =>
      luminosity_mask_sample_at(values, input.sample_index, input.backdrop)
  }
  let value = transparency_component(raw * input.transfer_scale)
  if input.alpha_is_shape {
    TransparencyMaskApplication::{
      mask_value: value,
      shape_multiplier: value,
      opacity_multiplier: 1.0,
    }
  } else {
    TransparencyMaskApplication::{
      mask_value: value,
      shape_multiplier: 1.0,
      opacity_multiplier: value,
    }
  }
}

///|
pub fn apply_transparency_mask_to_object(
  object : ElementaryObjectCompositeInput,
  mask : TransparencyMaskApplication,
) -> ElementaryObjectCompositeInput {
  ElementaryObjectCompositeInput::{
    backdrop: object.backdrop,
    source_colour: object.source_colour,
    backdrop_colour: object.backdrop_colour,
    source_shape: object.source_shape,
    mask_shape: object.mask_shape * mask.shape_multiplier,
    constant_shape: object.constant_shape,
    source_opacity: object.source_opacity,
    mask_opacity: object.mask_opacity * mask.opacity_multiplier,
    constant_opacity: object.constant_opacity,
    blend_mode: object.blend_mode,
    subtractive_space: object.subtractive_space,
  }
}

///|
pub fn TransparencyCompositeSample::transparent() -> TransparencyCompositeSample {
  TransparencyCompositeSample::{
    colour: None,
    shape: 0.0,
    opacity: 0.0,
    alpha: 0.0,
  }
}

///|
pub fn TransparencyCompositeSample::opaque(
  colour : Array[Double],
) -> TransparencyCompositeSample {
  TransparencyCompositeSample::{
    colour: Some(normalize_transparency_vector(colour)),
    shape: 1.0,
    opacity: 1.0,
    alpha: 1.0,
  }
}

///|
fn mask_sample_at(values : Array[Double], index : Int) -> Double {
  if index < 0 || index >= values.length() {
    0.0
  } else {
    transparency_component(values[index])
  }
}

///|
fn embedded_mask_sample_at(
  values : Array[Double],
  index : Int,
  matte : Array[Double]?,
) -> Double {
  let sample = mask_sample_at(values, index)
  match matte {
    Some(matte_values) =>
      if sample == 0.0 && matte_values.length() > 0 {
        0.0
      } else {
        sample
      }
    None => sample
  }
}

///|
fn luminosity_mask_sample_at(
  values : Array[Array[Double]],
  index : Int,
  backdrop : Array[Double],
) -> Double {
  let colour = if index < 0 || index >= values.length() {
    backdrop
  } else {
    values[index]
  }
  let components = vector_with_component_count(colour, 3, 0.0)
  transparency_component(
    0.3 * components[0] + 0.59 * components[1] + 0.11 * components[2],
  )
}

///|
fn knockout_backdrop_for_object(
  group_backdrop : TransparencyCompositeSample,
  current : TransparencyCompositeSample,
  accumulated_shape : Double,
  nested_knockout : Bool,
) -> TransparencyCompositeSample {
  if nested_knockout {
    group_backdrop
  } else if accumulated_shape == 0.0 {
    group_backdrop
  } else {
    current
  }
}

///|
fn merge_knockout_result(
  previous : TransparencyCompositeSample,
  object_result : TransparencyCompositeSample,
  object_shape : Double,
  fractional_shape_averaging : Bool,
) -> TransparencyCompositeSample {
  if !fractional_shape_averaging || object_shape >= 1.0 {
    object_result
  } else {
    average_fractional_knockout(previous, object_result, object_shape)
  }
}

///|
fn average_fractional_knockout(
  previous : TransparencyCompositeSample,
  object_result : TransparencyCompositeSample,
  object_shape : Double,
) -> TransparencyCompositeSample {
  let shape = union_alpha(previous.shape, object_result.shape)
  let alpha = union_alpha(previous.alpha, object_result.alpha)
  let opacity = safe_ratio(alpha, shape)
  let count = knockout_component_count(previous, object_result)
  let previous_colour = vector_with_component_count(
    previous.colour.unwrap_or([]),
    count,
    0.0,
  )
  let object_colour = vector_with_component_count(
    object_result.colour.unwrap_or([]),
    count,
    0.0,
  )
  let colour : Array[Double] = []
  for i in 0..<count {
    colour.push(
      transparency_component(
        previous_colour[i] * (1.0 - object_shape) +
        object_colour[i] * object_shape,
      ),
    )
  }
  TransparencyCompositeSample::{ colour: Some(colour), shape, opacity, alpha }
}

///|
fn knockout_component_count(
  previous : TransparencyCompositeSample,
  object_result : TransparencyCompositeSample,
) -> Int {
  match object_result.colour {
    Some(values) => values.length()
    None =>
      match previous.colour {
        Some(values) => values.length()
        None => 1
      }
  }
}

///|
fn select_group_backdrop(
  input : TransparencyGroupCompositeInput,
) -> TransparencyCompositeSample {
  match input.backdrop_mode {
    IsolatedGroupBackdrop => TransparencyCompositeSample::transparent()
    NonIsolatedGroupBackdrop => input.backdrop
    PageGroupBackdrop => input.initial_backdrop
  }
}

///|
fn elementary_object_with_backdrop(
  input : ElementaryObjectCompositeInput,
  backdrop : TransparencyCompositeSample,
) -> ElementaryObjectCompositeInput {
  ElementaryObjectCompositeInput::{
    backdrop,
    source_colour: input.source_colour,
    backdrop_colour: input.backdrop_colour,
    source_shape: input.source_shape,
    mask_shape: input.mask_shape,
    constant_shape: input.constant_shape,
    source_opacity: input.source_opacity,
    mask_opacity: input.mask_opacity,
    constant_opacity: input.constant_opacity,
    blend_mode: input.blend_mode,
    subtractive_space: input.subtractive_space,
  }
}

///|
fn normalize_group_colour(
  colour : Array[Double]?,
  input : TransparencyGroupCompositeInput,
) -> Array[Double]? {
  match colour {
    Some(values) =>
      Some(
        vector_with_component_count(
          values,
          input.blending_colour_space_components,
          0.0,
        ),
      )
    None => None
  }
}

///|
fn component_count_for_composite(input : ElementaryObjectCompositeInput) -> Int {
  match input.source_colour {
    Some(values) => values.length()
    None =>
      match input.backdrop_colour {
        Some(values) => values.length()
        None =>
          match input.backdrop.colour {
            Some(values) => values.length()
            None => 1
          }
      }
  }
}
