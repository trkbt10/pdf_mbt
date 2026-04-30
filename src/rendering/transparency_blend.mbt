///|
pub fn blend_component(
  mode : @graphics.BlendMode,
  backdrop : Double,
  source : Double,
) -> Double {
  let cb = transparency_component(backdrop)
  let cs = transparency_component(source)
  match mode {
    @graphics.BlendMode::Normal => cs
    @graphics.BlendMode::Multiply => cb * cs
    @graphics.BlendMode::Screen => cb + cs - cb * cs
    @graphics.BlendMode::Overlay => overlay_component(cb, cs)
    @graphics.BlendMode::Darken => min_component(cb, cs)
    @graphics.BlendMode::Lighten => max_component(cb, cs)
    @graphics.BlendMode::ColorDodge =>
      if cb == 0.0 {
        0.0
      } else if cb >= 1.0 - cs {
        1.0
      } else {
        transparency_component(safe_ratio(cb, 1.0 - cs))
      }
    @graphics.BlendMode::ColorBurn =>
      if cb == 1.0 {
        1.0
      } else if 1.0 - cb >= cs {
        0.0
      } else {
        transparency_component(1.0 - safe_ratio(1.0 - cb, cs))
      }
    @graphics.BlendMode::HardLight => overlay_component(cs, cb)
    @graphics.BlendMode::SoftLight => soft_light_component(cb, cs)
    @graphics.BlendMode::Difference => blend_abs_double(cb - cs)
    @graphics.BlendMode::Exclusion => cb + cs - 2.0 * cb * cs
    _ => cs
  }
}

///|
pub fn blend_vector(
  mode : @graphics.BlendMode,
  backdrop : Array[Double],
  source : Array[Double],
  subtractive? : Bool = false,
) -> Array[Double] {
  if mode.is_non_separable() {
    let blended = blend_nonseparable_rgb(mode, backdrop, source)
    if subtractive {
      complement_vector(blended)
    } else {
      blended
    }
  } else {
    let count = if backdrop.length() > source.length() {
      backdrop.length()
    } else {
      source.length()
    }
    let cb = vector_with_component_count(backdrop, count, 0.0)
    let cs = vector_with_component_count(source, count, 0.0)
    let result : Array[Double] = []
    for i in 0..<count {
      if subtractive {
        result.push(1.0 - blend_component(mode, 1.0 - cb[i], 1.0 - cs[i]))
      } else {
        result.push(blend_component(mode, cb[i], cs[i]))
      }
    }
    result
  }
}

///|
pub fn blend_nonseparable_rgb(
  mode : @graphics.BlendMode,
  backdrop : Array[Double],
  source : Array[Double],
) -> Array[Double] {
  let cb = vector_with_component_count(backdrop, 3, 0.0)
  let cs = vector_with_component_count(source, 3, 0.0)
  match mode {
    @graphics.BlendMode::Hue =>
      set_lum(set_sat(cs, saturation(cb)), luminosity(cb))
    @graphics.BlendMode::SaturationBlend =>
      set_lum(set_sat(cb, saturation(cs)), luminosity(cb))
    @graphics.BlendMode::Color => set_lum(cs, luminosity(cb))
    @graphics.BlendMode::Luminosity => set_lum(cb, luminosity(cs))
    _ => blend_vector(mode, cb, cs)
  }
}

///|
fn overlay_component(backdrop : Double, source : Double) -> Double {
  if backdrop <= 0.5 {
    2.0 * backdrop * source
  } else {
    1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
  }
}

///|
fn soft_light_component(backdrop : Double, source : Double) -> Double {
  if source <= 0.5 {
    backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop)
  } else {
    backdrop + (2.0 * source - 1.0) * (soft_light_d(backdrop) - backdrop)
  }
}

///|
fn soft_light_d(value : Double) -> Double {
  if value <= 0.25 {
    ((16.0 * value - 12.0) * value + 4.0) * value
  } else {
    @math.pow(value, 0.5)
  }
}

///|
fn luminosity(colour : Array[Double]) -> Double {
  0.3 * colour[0] + 0.59 * colour[1] + 0.11 * colour[2]
}

///|
fn saturation(colour : Array[Double]) -> Double {
  max_component(max_component(colour[0], colour[1]), colour[2]) -
  min_component(min_component(colour[0], colour[1]), colour[2])
}

///|
fn set_lum(colour : Array[Double], lum : Double) -> Array[Double] {
  clip_colour([
    colour[0] + lum - luminosity(colour),
    colour[1] + lum - luminosity(colour),
    colour[2] + lum - luminosity(colour),
  ])
}

///|
fn set_sat(colour : Array[Double], sat : Double) -> Array[Double] {
  let result = colour.copy()
  let min_index = min_component_index(result)
  let max_index = max_component_index(result)
  let mid_index = 3 - min_index - max_index
  if result[max_index] > result[min_index] {
    result[mid_index] = safe_ratio(
      (result[mid_index] - result[min_index]) * sat,
      result[max_index] - result[min_index],
    )
    result[max_index] = sat
  } else {
    result[mid_index] = 0.0
    result[max_index] = 0.0
  }
  result[min_index] = 0.0
  result
}

///|
fn clip_colour(colour : Array[Double]) -> Array[Double] {
  let lum = luminosity(colour)
  let min_value = min_component(min_component(colour[0], colour[1]), colour[2])
  let max_value = max_component(max_component(colour[0], colour[1]), colour[2])
  let result = colour.copy()
  if min_value < 0.0 {
    for i in 0..<3 {
      result[i] = lum + safe_ratio((result[i] - lum) * lum, lum - min_value)
    }
  }
  if max_value > 1.0 {
    for i in 0..<3 {
      result[i] = lum +
        safe_ratio((result[i] - lum) * (1.0 - lum), max_value - lum)
    }
  }
  normalize_transparency_vector(result)
}

///|
fn complement_vector(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for value in values {
    result.push(1.0 - transparency_component(value))
  }
  result
}

///|
fn min_component(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_component(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn blend_abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn min_component_index(values : Array[Double]) -> Int {
  if values[0] <= values[1] && values[0] <= values[2] {
    0
  } else if values[1] <= values[0] && values[1] <= values[2] {
    1
  } else {
    2
  }
}

///|
fn max_component_index(values : Array[Double]) -> Int {
  if values[0] >= values[1] && values[0] >= values[2] {
    0
  } else if values[1] >= values[0] && values[1] >= values[2] {
    1
  } else {
    2
  }
}
