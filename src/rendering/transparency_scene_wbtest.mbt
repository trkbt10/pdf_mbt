///|
test "transparency scene preserves PDF paint order and state snapshots" {
  let state = @graphics.GraphicsState::initial(
    @graphics.GraphicsInitialState::default(),
  )
  state.blend_mode = @graphics.BlendMode::Multiply
  state.alpha_nonstroking = 0.5
  state.alpha_stroking = 0.75
  let path = @graphics.GraphicsPath::from_rect(@graphics.GraphicsRect::{
    left: 0.0,
    bottom: 0.0,
    right: 10.0,
    top: 10.0,
  })
  let program = @graphics.GraphicsProgram::{
    events: [
      @graphics.GraphicsEvent::PathPainted(
        10L,
        @graphics.PathPaintOperation::FillPath(@graphics.FillRule::NonZero),
        path,
        state,
      ),
      @graphics.GraphicsEvent::PathPainted(
        20L,
        @graphics.PathPaintOperation::StrokePath,
        path,
        state,
      ),
    ],
    final_state: state,
  }
  let scene = build_transparency_scene(program)
  assert_eq(scene.paints.length(), 2)
  assert_eq(scene.paints[0].kind == TransparencyPaintKind::PathFillPaint, true)
  assert_eq(
    scene.paints[1].kind == TransparencyPaintKind::PathStrokePaint,
    true,
  )
  assert_eq(scene.paints[0].blend_mode == @graphics.BlendMode::Multiply, true)
  assert_eq(scene.paints[0].alpha_constant, 0.5)
  assert_eq(scene.paints[1].alpha_constant, 0.75)
}
