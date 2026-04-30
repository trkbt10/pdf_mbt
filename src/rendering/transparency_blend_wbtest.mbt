///|
test "separable blend modes produce deterministic component values" {
  assert_eq(blend_component(@graphics.BlendMode::Normal, 0.2, 0.8), 0.8)
  assert_near(
    blend_component(@graphics.BlendMode::Multiply, 0.2, 0.8),
    0.16000000000000003,
  )
  assert_near(blend_component(@graphics.BlendMode::Screen, 0.2, 0.8), 0.84)
  assert_eq(blend_component(@graphics.BlendMode::Darken, 0.2, 0.8), 0.2)
  assert_eq(blend_component(@graphics.BlendMode::Lighten, 0.2, 0.8), 0.8)
  assert_near(
    blend_component(@graphics.BlendMode::Difference, 0.2, 0.8),
    0.6000000000000001,
  )
  assert_near(blend_component(@graphics.BlendMode::Exclusion, 0.2, 0.8), 0.68)
}

///|
test "PDF 2 ColorDodge and ColorBurn edge cases are stable" {
  assert_eq(blend_component(@graphics.BlendMode::ColorDodge, 0.0, 0.75), 0.0)
  assert_eq(blend_component(@graphics.BlendMode::ColorDodge, 0.8, 0.25), 1.0)
  assert_eq(blend_component(@graphics.BlendMode::ColorBurn, 1.0, 0.25), 1.0)
  assert_eq(blend_component(@graphics.BlendMode::ColorBurn, 0.2, 0.75), 0.0)
}

///|
test "blend vector complements subtractive colour spaces" {
  assert_eq(
    blend_vector(
      @graphics.BlendMode::Multiply,
      [0.2, 0.4, 0.6, 0.1],
      [0.5, 0.5, 0.5, 0.5],
      subtractive=true,
    ),
    [0.6, 0.7, 0.8, 0.55],
  )
}

///|
test "non separable RGB blend modes preserve luminosity or saturation" {
  let backdrop = [0.2, 0.4, 0.6]
  let source = [0.8, 0.2, 0.1]
  let color = blend_nonseparable_rgb(
    @graphics.BlendMode::Color,
    backdrop,
    source,
  )
  assert_near(luminosity(color), luminosity(backdrop))
  let saturation_blend = blend_nonseparable_rgb(
    @graphics.BlendMode::SaturationBlend,
    backdrop,
    source,
  )
  assert_near(saturation(saturation_blend), saturation(source))
}

///|
fn assert_near(actual : Double, expected : Double) -> Unit raise Error {
  if blend_abs_double(actual - expected) > 0.0000001 {
    fail("expected nearby component")
  }
}
