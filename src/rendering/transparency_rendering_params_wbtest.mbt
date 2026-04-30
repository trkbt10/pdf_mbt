///|
test "rendering parameter policy selects topmost fully opaque object" {
  let page = rendering_parameter_snapshot(
    @graphics.RenderingIntent::RelativeColorimetric,
  )
  let object = rendering_parameter_snapshot(
    @graphics.RenderingIntent::Saturation,
  )
  let selected = select_transparency_rendering_parameters(
    page,
    [
      OpaqueObjectCandidate::{
        component_index: 0,
        alpha: 0.5,
        shape: 1.0,
        opacity: 1.0,
        parameters: object,
      },
      OpaqueObjectCandidate::{
        component_index: 0,
        alpha: 1.0,
        shape: 1.0,
        opacity: 1.0,
        parameters: object,
      },
    ],
    0,
  )
  assert_eq(selected.selected_from_opaque_object, true)
  assert_eq(
    selected.selected.rendering_intent == @graphics.RenderingIntent::Saturation,
    true,
  )
}

///|
test "rendering parameter policy falls back to page defaults for transparent samples" {
  let page = rendering_parameter_snapshot(
    @graphics.RenderingIntent::RelativeColorimetric,
  )
  let object = rendering_parameter_snapshot(
    @graphics.RenderingIntent::Saturation,
  )
  let selected = select_transparency_rendering_parameters(
    page,
    [
      OpaqueObjectCandidate::{
        component_index: 1,
        alpha: 1.0,
        shape: 0.5,
        opacity: 1.0,
        parameters: object,
      },
    ],
    1,
    overprint_active=true,
  )
  assert_eq(selected.selected_from_opaque_object, false)
  assert_eq(selected.ignored_group_halftone_transfer, true)
  assert_eq(
    selected.selected.rendering_intent ==
    @graphics.RenderingIntent::RelativeColorimetric,
    true,
  )
}

///|
test "group invocation preserves conversion context but ignores transfer and halftone" {
  let page = RenderingParameterSnapshot::{
    rendering_intent: @graphics.RenderingIntent::RelativeColorimetric,
    black_point_compensation: @graphics.BlackPointCompensation::BlackPointDefault,
    transfer: TransferFunctionSet::identity(),
    halftone: Some(HalftoneRef::DefaultHalftone),
  }
  let object = RenderingParameterSnapshot::{
    rendering_intent: @graphics.RenderingIntent::Perceptual,
    black_point_compensation: @graphics.BlackPointCompensation::BlackPointOn,
    transfer: TransferFunctionSet::SingleTransferFunction(
      TransferFunctionRef::IndirectTransfer(@objects.ObjectId::{
        object_number: 7,
        generation_number: 0,
      }),
    ),
    halftone: None,
  }
  let selected = select_transparency_rendering_parameters(
    page,
    [
      OpaqueObjectCandidate::{
        component_index: 0,
        alpha: 1.0,
        shape: 1.0,
        opacity: 1.0,
        parameters: object,
      },
    ],
    0,
    group_invocation=true,
  )
  assert_eq(
    selected.selected.rendering_intent == @graphics.RenderingIntent::Perceptual,
    true,
  )
  assert_eq(selected.selected.transfer == page.transfer, true)
  assert_eq(selected.selected.halftone == page.halftone, true)
}

///|
fn rendering_parameter_snapshot(
  intent : @graphics.RenderingIntent,
) -> RenderingParameterSnapshot {
  RenderingParameterSnapshot::{
    rendering_intent: intent,
    black_point_compensation: @graphics.BlackPointCompensation::BlackPointDefault,
    transfer: TransferFunctionSet::identity(),
    halftone: None,
  }
}
