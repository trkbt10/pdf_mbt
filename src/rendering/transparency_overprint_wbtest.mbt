///|
test "spot overprint preserves white preserving separable blend modes" {
  let resolution = resolve_spot_overprint(SpotOverprintContext::{
    blend_mode: @graphics.BlendMode::Multiply,
    overprint: true,
    overprint_mode: 1,
    is_spot_colour: true,
    spot_available: true,
    painting_group_object: false,
    subtractive_space: true,
  })
  assert_eq(resolution.decision == SpotBlendDecision::PreserveSpotBlend, true)
  assert_eq(
    resolution.effective_blend_mode == @graphics.BlendMode::Multiply,
    true,
  )
  assert_eq(resolution.overprints_compatible_components, true)
}

///|
test "spot overprint substitutes Normal for non white preserving modes" {
  let resolution = resolve_spot_overprint(SpotOverprintContext::{
    blend_mode: @graphics.BlendMode::Screen,
    overprint: true,
    overprint_mode: 1,
    is_spot_colour: true,
    spot_available: true,
    painting_group_object: false,
    subtractive_space: true,
  })
  assert_eq(
    resolution.decision == SpotBlendDecision::SubstituteNormalForSpot,
    true,
  )
  assert_eq(
    resolution.effective_blend_mode == @graphics.BlendMode::Normal,
    true,
  )
}

///|
test "spot overprint falls back to alternate colour for unavailable group spots" {
  let resolution = resolve_spot_overprint(SpotOverprintContext::{
    blend_mode: @graphics.BlendMode::Multiply,
    overprint: true,
    overprint_mode: 1,
    is_spot_colour: true,
    spot_available: false,
    painting_group_object: true,
    subtractive_space: true,
  })
  assert_eq(
    resolution.decision == SpotBlendDecision::UseAlternateColourSpace,
    true,
  )
  assert_eq(resolution.erases_unpainted_components, true)
}

///|
test "pattern spot overprint treats group objects as alternate colour" {
  let resolution = resolve_pattern_spot_overprint(
    SpotOverprintContext::{
      blend_mode: @graphics.BlendMode::Multiply,
      overprint: true,
      overprint_mode: 1,
      is_spot_colour: true,
      spot_available: true,
      painting_group_object: false,
      subtractive_space: true,
    },
    true,
  )
  assert_eq(
    resolution.decision == SpotBlendDecision::UseAlternateColourSpace,
    true,
  )
  assert_eq(resolution.overprints_compatible_components, false)
}

///|
test "overprint mode zero erases unpainted spot components" {
  let resolution = resolve_pattern_spot_overprint(
    SpotOverprintContext::{
      blend_mode: @graphics.BlendMode::Screen,
      overprint: true,
      overprint_mode: 0,
      is_spot_colour: true,
      spot_available: true,
      painting_group_object: false,
      subtractive_space: true,
    },
    false,
  )
  assert_eq(
    resolution.effective_blend_mode == @graphics.BlendMode::Normal,
    true,
  )
  assert_eq(resolution.erases_unpainted_components, true)
}
