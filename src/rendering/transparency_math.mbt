///|
pub(all) struct TransparencySample {
  colour : Array[Double]?
  shape : Double
  opacity : Double
} derive(Eq, Debug)

///|
pub fn transparency_component(value : Double) -> Double {
  if value.is_nan() || value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
pub fn transparency_alpha(shape : Double, opacity : Double) -> Double {
  transparency_component(shape) * transparency_component(opacity)
}

///|
pub fn union_alpha(backdrop_alpha : Double, source_alpha : Double) -> Double {
  let ab = transparency_component(backdrop_alpha)
  let as_ = transparency_component(source_alpha)
  ab + as_ - ab * as_
}

///|
pub fn safe_ratio(numerator : Double, denominator : Double) -> Double {
  if denominator == 0.0 || denominator.is_nan() || numerator.is_nan() {
    0.0
  } else {
    numerator / denominator
  }
}

///|
pub fn normalize_shape(value : Double) -> Double {
  transparency_component(value)
}

///|
pub fn normalize_opacity(value : Double) -> Double {
  transparency_component(value)
}

///|
pub fn normalize_transparency_vector(values : Array[Double]) -> Array[Double] {
  let normalized : Array[Double] = []
  for value in values {
    normalized.push(transparency_component(value))
  }
  normalized
}

///|
pub fn vector_with_component_count(
  values : Array[Double],
  count : Int,
  fallback : Double,
) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<count {
    if i < values.length() {
      result.push(transparency_component(values[i]))
    } else {
      result.push(transparency_component(fallback))
    }
  }
  result
}

///|
pub fn TransparencySample::new(
  colour : Array[Double]?,
  shape : Double,
  opacity : Double,
) -> TransparencySample {
  let normalized_colour = match colour {
    Some(values) => Some(normalize_transparency_vector(values))
    None => None
  }
  let normalized_shape = normalize_shape(shape)
  let normalized_opacity = if normalized_shape == 0.0 {
    0.0
  } else {
    normalize_opacity(opacity)
  }
  TransparencySample::{
    colour: if transparency_alpha(normalized_shape, normalized_opacity) == 0.0 {
      None
    } else {
      normalized_colour
    },
    shape: normalized_shape,
    opacity: normalized_opacity,
  }
}

///|
pub fn TransparencySample::alpha(self : TransparencySample) -> Double {
  transparency_alpha(self.shape, self.opacity)
}
