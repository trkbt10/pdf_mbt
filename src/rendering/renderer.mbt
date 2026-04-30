///|
pub(all) struct RenderContext {
  device : RasterDevice
  options : RenderOptions
  providers : RenderingProviders
  scene : RenderScene
  surface : RasterSurface
  report : RenderReport
} derive(Eq, Debug)

///|
pub(all) struct RenderResult {
  surface : RasterSurface
  report : RenderReport
} derive(Eq, Debug)

///|
/// Clause 10.1 general rendering sequence for raster output devices: convert
/// graphics object colour into native device colour, apply transfer functions,
/// perform scan conversion to mark device pixels, and apply PDF-defined
/// halftoning when the raster output device is not continuous tone.
pub(all) struct ClauseTenRenderingSequence {
  separates_graphics_specification_from_raster_rendering : Bool
  converts_colour_to_native_colour_space : Bool
  applies_transfer_functions_before_halftoning : Bool
  scan_converts_shapes_to_device_pixels : Bool
  applies_pdf_defined_halftoning : Bool
} derive(Eq, Debug)

///|
pub fn ClauseTenRenderingSequence::general() -> ClauseTenRenderingSequence {
  ClauseTenRenderingSequence::{
    separates_graphics_specification_from_raster_rendering: true,
    converts_colour_to_native_colour_space: true,
    applies_transfer_functions_before_halftoning: true,
    scan_converts_shapes_to_device_pixels: true,
    applies_pdf_defined_halftoning: true,
  }
}

///|
pub fn RenderContext::new(
  device : RasterDevice,
  scene : RenderScene,
  options? : RenderOptions = RenderOptions::default(),
  providers? : RenderingProviders = RenderingProviders::none(),
) -> RenderContext raise PdfRenderingError {
  device.validate()
  RenderContext::{
    device,
    options,
    providers,
    scene,
    surface: RasterSurface::allocate(device),
    report: RenderReport::empty(),
  }
}

///|
pub fn render_scene(
  scene : RenderScene,
  device : RasterDevice,
  options? : RenderOptions = RenderOptions::default(),
  providers? : RenderingProviders = RenderingProviders::none(),
) -> RenderResult raise PdfRenderingError {
  let context = RenderContext::new(device, scene, options~, providers~)
  context.execute()
}

///|
pub fn render_program(
  graphics : @graphics.GraphicsProgram,
  text? : @text.TextProgram = @text.TextProgram::empty(),
  device : RasterDevice,
  options? : RenderOptions = RenderOptions::default(),
  providers? : RenderingProviders = RenderingProviders::none(),
) -> RenderResult raise PdfRenderingError {
  render_transparency_program(graphics, text~, device, options~, providers~)
}

///|
pub fn render_transparency_program(
  graphics : @graphics.GraphicsProgram,
  text? : @text.TextProgram = @text.TextProgram::empty(),
  device : RasterDevice,
  options? : RenderOptions = RenderOptions::default(),
  providers? : RenderingProviders = RenderingProviders::none(),
) -> RenderResult raise PdfRenderingError {
  let context = RenderContext::new(
    device,
    build_render_scene(graphics, text~, providers~),
    options~,
    providers~,
  )
  let transparency = build_transparency_scene(graphics, text~)
  context.execute_transparency(transparency)
}

///|
pub fn RenderContext::execute(
  self : RenderContext,
) -> RenderResult raise PdfRenderingError {
  for operation in self.scene.operations {
    execute_paint_operation(self, operation)
  }
  RenderResult::{ surface: self.surface, report: self.report }
}

///|
pub fn RenderContext::execute_transparency(
  self : RenderContext,
  transparency : TransparencyScene,
) -> RenderResult raise PdfRenderingError {
  let mut sample = page_medium_backdrop(self.device)
  for paint in transparency.paints {
    sample = composite_elementary_object(
      transparency_paint_input(paint, sample, self.device),
    )
    self.report.record_paint()
  }
  paint_composite_sample_to_surface(self.surface, sample, self.device)
  RenderResult::{ surface: self.surface, report: self.report }
}

///|
fn execute_paint_operation(
  context : RenderContext,
  operation : RenderPaintOp,
) -> Unit raise PdfRenderingError {
  match operation {
    FillPathOp(_, _, state) => {
      let colour = state.current_colour_value(@graphics.ColourUse::Nonstroking)
      let space = state.current_colour_space(@graphics.ColourUse::Nonstroking)
      let native = context.device.convert_colour(colour, space)
      let transfer = resolve_graphics_state_transfer(state, context.device)
      let additive = apply_transfer_functions(native, space, transfer.functions)
      let mark = apply_halftone(
        additive,
        DevicePixelPoint::{ x: 0, y: 0 },
        None,
        context.device,
      )
      let _ = fill_device_rect(
        context.surface,
        0,
        0,
        context.surface.width,
        context.surface.height,
        mark,
      )
      context.report.record_paint()
    }
    StrokePathOp(_, _, state) => {
      let colour = state.current_colour_value(@graphics.ColourUse::Stroking)
      let space = state.current_colour_space(@graphics.ColourUse::Stroking)
      let native = context.device.convert_colour(colour, space)
      let transfer = resolve_graphics_state_transfer(state, context.device)
      let additive = apply_transfer_functions(native, space, transfer.functions)
      let mark = apply_halftone(
        additive,
        DevicePixelPoint::{ x: 0, y: 0 },
        None,
        context.device,
      )
      let _ = stroke_device_line(
        context.surface,
        DevicePixelPoint::{ x: 0, y: 0 },
        DevicePixelPoint::{ x: context.surface.width - 1, y: 0 },
        state.line_width,
        state.stroke_adjustment,
        mark,
      )
      context.report.record_paint()
    }
    ImagePaintOp(_, descriptor, _) => {
      context.report.observe_limit(
        "image source samples",
        descriptor.width * descriptor.height,
        context.device.limits.max_surface_bytes,
      )
      context.report.record_paint()
    }
    ShadingPaintOp(offset, _, _) =>
      handle_unsupported(
        context,
        offset,
        "shading evaluation",
        UnsupportedResource("shading provider unavailable"),
      )
    GlyphMaskOp(offset, _) =>
      if context.providers.glyph_rasterizer {
        context.report.record_paint()
      } else {
        handle_unsupported(
          context,
          offset,
          "glyph mask",
          ProviderUnavailable("glyph rasterizer"),
        )
      }
    UnsupportedPaintOp(offset, label) =>
      handle_unsupported(context, offset, label, UnsupportedResource(label))
  }
}

///|
fn page_medium_backdrop(device : RasterDevice) -> TransparencyCompositeSample {
  TransparencyCompositeSample::opaque(
    vector_with_component_count([], device.component_count(), 1.0),
  )
}

///|
fn transparency_paint_input(
  paint : TransparencyPaint,
  backdrop : TransparencyCompositeSample,
  device : RasterDevice,
) -> ElementaryObjectCompositeInput {
  ElementaryObjectCompositeInput::{
    backdrop,
    source_colour: Some(
      vector_with_component_count(
        paint.source_colour.map(fn(value) { value.components }).unwrap_or([]),
        device.component_count(),
        0.0,
      ),
    ),
    backdrop_colour: backdrop.colour,
    source_shape: 1.0,
    mask_shape: 1.0,
    constant_shape: if paint.state.alpha_is_shape {
      paint.alpha_constant
    } else {
      1.0
    },
    source_opacity: 1.0,
    mask_opacity: 1.0,
    constant_opacity: if paint.state.alpha_is_shape {
      1.0
    } else {
      paint.alpha_constant
    },
    blend_mode: paint.blend_mode,
    subtractive_space: device.native_colour_space ==
    NativeColourSpace::NativeCMYK,
  }
}

///|
fn paint_composite_sample_to_surface(
  surface : RasterSurface,
  sample : TransparencyCompositeSample,
  device : RasterDevice,
) -> Unit raise PdfRenderingError {
  let components = vector_with_component_count(
    sample.colour.unwrap_or([]),
    device.component_count(),
    0.0,
  )
  let mark = apply_halftone(
    AdditiveNativeColour::{
      colour_space: device.native_colour_space,
      components,
    },
    DevicePixelPoint::{ x: 0, y: 0 },
    None,
    device,
  )
  let _ = fill_device_rect(surface, 0, 0, surface.width, surface.height, mark)
}

///|
fn handle_unsupported(
  context : RenderContext,
  offset : Int64,
  operation : String,
  reason : SkippedRenderReason,
) -> Unit raise PdfRenderingError {
  if context.options.is_strict() {
    raise PdfRenderingError::UnsupportedCapability(operation)
  } else {
    context.report.record_skip(offset, operation, reason)
  }
}
