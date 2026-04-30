///|
pub(all) enum SpotBlendDecision {
  PreserveSpotBlend
  SubstituteNormalForSpot
  UseAlternateColourSpace
} derive(Eq, Debug)

///|
pub(all) struct SpotOverprintContext {
  blend_mode : @graphics.BlendMode
  overprint : Bool
  overprint_mode : Int
  is_spot_colour : Bool
  spot_available : Bool
  painting_group_object : Bool
  subtractive_space : Bool
} derive(Eq, Debug)

///|
pub(all) struct SpotOverprintResolution {
  effective_blend_mode : @graphics.BlendMode
  decision : SpotBlendDecision
  overprints_compatible_components : Bool
  erases_unpainted_components : Bool
} derive(Eq, Debug)

///|
pub fn resolve_spot_overprint(
  context : SpotOverprintContext,
) -> SpotOverprintResolution {
  let compatible_spot_blend = context.blend_mode.is_separable() &&
    context.blend_mode.is_white_preserving()
  let decision = if !context.is_spot_colour {
    SpotBlendDecision::PreserveSpotBlend
  } else if !context.spot_available || context.painting_group_object {
    SpotBlendDecision::UseAlternateColourSpace
  } else if compatible_spot_blend {
    SpotBlendDecision::PreserveSpotBlend
  } else {
    SpotBlendDecision::SubstituteNormalForSpot
  }
  let effective = match decision {
    SubstituteNormalForSpot => @graphics.BlendMode::Normal
    _ => context.blend_mode
  }
  SpotOverprintResolution::{
    effective_blend_mode: effective,
    decision,
    overprints_compatible_components: context.overprint &&
    context.spot_available &&
    !context.painting_group_object,
    erases_unpainted_components: !context.overprint ||
    context.overprint_mode == 0 ||
    context.painting_group_object,
  }
}

///|
pub fn blend_mode_for_spot_colour(
  mode : @graphics.BlendMode,
  spot_available : Bool,
) -> @graphics.BlendMode {
  resolve_spot_overprint(SpotOverprintContext::{
    blend_mode: mode,
    overprint: false,
    overprint_mode: 0,
    is_spot_colour: true,
    spot_available,
    painting_group_object: false,
    subtractive_space: true,
  }).effective_blend_mode
}
