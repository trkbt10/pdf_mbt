///|
test "renderer records best effort skip for unsupported operations" {
  let scene = RenderScene::{
    operations: [RenderPaintOp::UnsupportedPaintOp(12L, "pattern paint")],
  }
  let result = render_scene(
    scene,
    RasterDevice::gray(1, 1),
    options=RenderOptions::best_effort(),
  )

  assert_eq(result.report.paint_count, 0)
  assert_eq(result.report.skipped_operations.length(), 1)
  assert_eq(result.report.skipped_operations[0].offset, 12L)
}

///|
test "renderer fails strict unsupported operation before painting" {
  let scene = RenderScene::{
    operations: [RenderPaintOp::UnsupportedPaintOp(12L, "pattern paint")],
  }
  try render_scene(scene, RasterDevice::gray(1, 1)) catch {
    PdfRenderingError::UnsupportedCapability(reason) =>
      assert_eq(reason, "pattern paint")
    _ => fail("expected strict unsupported capability")
  } noraise {
    _ => fail("expected strict unsupported capability")
  }
}

///|
test "render program routes path paints through transparency compositor" {
  let state = @graphics.GraphicsState::initial(
    @graphics.GraphicsInitialState::default(),
  )
  state.set_colour_space(
    @graphics.ColourUse::Nonstroking,
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceRGB),
  )
  state.set_colour_value(
    @graphics.ColourUse::Nonstroking,
    @graphics.ColourValue::{ components: [1.0, 0.0, 0.0], pattern: None },
    0L,
  )
  state.alpha_nonstroking = 0.5
  let result = render_program(
    single_fill_for_render_test(state),
    RasterDevice::rgb(1, 1),
  )
  assert_eq(result.report.paint_count, 1)
  assert_eq(result.surface.read_component_byte(0, 0, 0, 0).to_int(), 255)
  assert_eq(result.surface.read_component_byte(0, 0, 1, 0).to_int(), 128)
  assert_eq(result.surface.read_component_byte(0, 0, 2, 0).to_int(), 128)
}

///|
test "render program validates allocation limits before transparency painting" {
  let limits = RenderLimits::{
    max_width: 1,
    max_height: 10000,
    max_surface_bytes: 268435456,
    max_process_colourants: 4,
    max_spot_colourants: 32,
    max_bits_per_component: 16,
    max_threshold_bytes: 16777216,
    max_path_segments: 1000000,
    max_halftone_cell_pixels: 1048576,
    max_provider_cache_entries: 4096,
  }
  let device = RasterDevice::{
    width: 2,
    height: 1,
    resolution_x: 72.0,
    resolution_y: 72.0,
    native_colour_space: NativeColourSpace::NativeRGB,
    process_colourants: NativeColourSpace::NativeRGB.default_process_colourants(),
    spot_colourants: [],
    continuous_tone: true,
    bits_per_component: 8,
    output_profile: None,
    default_transfer: Some(TransferFunctionRef::IdentityTransfer),
    default_halftone: None,
    limits,
  }
  try
    render_program(
      single_fill_for_render_test(
        @graphics.GraphicsState::initial(
          @graphics.GraphicsInitialState::default(),
        ),
      ),
      device,
    )
  catch {
    PdfRenderingError::LimitExceeded(name, _, _) => assert_eq(name, "width")
    _ => fail("expected surface width limit")
  } noraise {
    _ => fail("expected surface width limit")
  }
}

///|
fn single_fill_for_render_test(
  state : @graphics.GraphicsState,
) -> @graphics.GraphicsProgram {
  let path = @graphics.GraphicsPath::from_rect(@graphics.GraphicsRect::{
    left: 0.0,
    bottom: 0.0,
    right: 1.0,
    top: 1.0,
  })
  @graphics.GraphicsProgram::{
    events: [
      @graphics.GraphicsEvent::PathPainted(
        0L,
        @graphics.PathPaintOperation::FillPath(@graphics.FillRule::NonZero),
        path,
        state,
      ),
    ],
    final_state: state,
  }
}
