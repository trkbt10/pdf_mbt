///|
pub(all) struct RenderingParameterSnapshot {
  rendering_intent : @graphics.RenderingIntent
  black_point_compensation : @graphics.BlackPointCompensation
  transfer : TransferFunctionSet
  halftone : HalftoneRef?
} derive(Eq, Debug)

///|
pub(all) struct OpaqueObjectCandidate {
  component_index : Int
  alpha : Double
  shape : Double
  opacity : Double
  parameters : RenderingParameterSnapshot
} derive(Eq, Debug)

///|
pub(all) struct RenderingParameterSelection {
  selected : RenderingParameterSnapshot
  selected_from_opaque_object : Bool
  ignored_group_halftone_transfer : Bool
} derive(Eq, Debug)

///|
pub fn snapshot_rendering_parameters(
  state : @graphics.GraphicsState,
  device : RasterDevice,
) -> RenderingParameterSnapshot raise PdfRenderingError {
  RenderingParameterSnapshot::{
    rendering_intent: state.rendering_intent,
    black_point_compensation: state.black_point_compensation,
    transfer: resolve_graphics_state_transfer(state, device).functions,
    halftone: device.default_halftone,
  }
}

///|
pub fn select_transparency_rendering_parameters(
  page_defaults : RenderingParameterSnapshot,
  candidates : Array[OpaqueObjectCandidate],
  component_index : Int,
  overprint_active? : Bool = false,
  group_invocation? : Bool = false,
) -> RenderingParameterSelection {
  for candidate in candidates {
    if candidate.component_index == component_index &&
      transparency_alpha(candidate.shape, candidate.opacity) == 1.0 &&
      candidate.alpha == 1.0 {
      return RenderingParameterSelection::{
        selected: if group_invocation {
          keep_conversion_context(candidate.parameters, page_defaults)
        } else {
          candidate.parameters
        },
        selected_from_opaque_object: true,
        ignored_group_halftone_transfer: group_invocation || overprint_active,
      }
    }
  }
  RenderingParameterSelection::{
    selected: page_defaults,
    selected_from_opaque_object: false,
    ignored_group_halftone_transfer: group_invocation || overprint_active,
  }
}

///|
fn keep_conversion_context(
  object_parameters : RenderingParameterSnapshot,
  page_defaults : RenderingParameterSnapshot,
) -> RenderingParameterSnapshot {
  RenderingParameterSnapshot::{
    rendering_intent: object_parameters.rendering_intent,
    black_point_compensation: object_parameters.black_point_compensation,
    transfer: page_defaults.transfer,
    halftone: page_defaults.halftone,
  }
}
