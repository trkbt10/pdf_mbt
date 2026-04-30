///|
pub(all) enum RenderPaintOp {
  FillPathOp(Int64, @graphics.GraphicsPath, @graphics.GraphicsState)
  StrokePathOp(Int64, @graphics.GraphicsPath, @graphics.GraphicsState)
  ImagePaintOp(Int64, @graphics.ImageDescriptor, @graphics.GraphicsState)
  ShadingPaintOp(Int64, @graphics.ShadingResource, @graphics.GraphicsState)
  GlyphMaskOp(Int64, @text.TextGlyphEvent)
  UnsupportedPaintOp(Int64, String)
} derive(Eq, Debug)

///|
pub(all) struct RenderScene {
  operations : Array[RenderPaintOp]
} derive(Eq, Debug)

///|
pub fn build_render_scene(
  graphics : @graphics.GraphicsProgram,
  text? : @text.TextProgram = @text.TextProgram::empty(),
  providers? : RenderingProviders = RenderingProviders::none(),
) -> RenderScene {
  let operations : Array[RenderPaintOp] = []
  for event in graphics.events {
    match event {
      @graphics.GraphicsEvent::PathPainted(offset, operation, path, state) =>
        append_path_paint_operation(operations, offset, operation, path, state)
      @graphics.GraphicsEvent::ImagePainted(offset, descriptor, state) =>
        operations.push(ImagePaintOp(offset, descriptor, state))
      @graphics.GraphicsEvent::InlineImagePainted(offset, descriptor, state) =>
        operations.push(ImagePaintOp(offset, descriptor, state))
      @graphics.GraphicsEvent::ShadingPainted(offset, shading, state) =>
        operations.push(ShadingPaintOp(offset, shading, state))
      @graphics.GraphicsEvent::ExternalObjectInvoked(offset, name) =>
        operations.push(
          UnsupportedPaintOp(offset, "external object " + name.to_text()),
        )
      @graphics.GraphicsEvent::UnresolvedXObjectInvoked(offset, name, _) =>
        operations.push(
          UnsupportedPaintOp(offset, "unresolved XObject " + name.to_text()),
        )
      _ => ()
    }
  }
  if providers.glyph_rasterizer {
    for event in text.events {
      match event {
        @text.TextEvent::GlyphShown(glyph) =>
          if !glyph.paint.invisible {
            operations.push(GlyphMaskOp(glyph.offset, glyph))
          }
        _ => ()
      }
    }
  }
  sort_scene_operations(operations)
  RenderScene::{ operations, }
}

///|
pub fn RenderScene::paint_operation_count(self : RenderScene) -> Int {
  self.operations.length()
}

///|
fn append_path_paint_operation(
  operations : Array[RenderPaintOp],
  offset : Int64,
  operation : @graphics.PathPaintOperation,
  path : @graphics.GraphicsPath,
  state : @graphics.GraphicsState,
) -> Unit {
  match operation {
    StrokePath | CloseStrokePath =>
      operations.push(StrokePathOp(offset, path, state))
    FillPath(_) => operations.push(FillPathOp(offset, path, state))
    FillStrokePath(_) | CloseFillStrokePath(_) => {
      operations.push(FillPathOp(offset, path, state))
      operations.push(StrokePathOp(offset, path, state))
    }
    EndPath => ()
  }
}

///|
fn sort_scene_operations(operations : Array[RenderPaintOp]) -> Unit {
  for i in 0..<operations.length() {
    for j in (i + 1)..<operations.length() {
      if paint_op_offset(operations[j]) < paint_op_offset(operations[i]) {
        let temp = operations[i]
        operations[i] = operations[j]
        operations[j] = temp
      }
    }
  }
}

///|
fn paint_op_offset(operation : RenderPaintOp) -> Int64 {
  match operation {
    FillPathOp(offset, _, _) => offset
    StrokePathOp(offset, _, _) => offset
    ImagePaintOp(offset, _, _) => offset
    ShadingPaintOp(offset, _, _) => offset
    GlyphMaskOp(offset, _) => offset
    UnsupportedPaintOp(offset, _) => offset
  }
}
