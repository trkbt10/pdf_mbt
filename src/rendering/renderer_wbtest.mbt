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
