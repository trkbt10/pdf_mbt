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
