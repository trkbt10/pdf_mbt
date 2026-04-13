///|
test "initial graphics state preserves page clip user unit and rotate" {
  let clip = GraphicsPath::from_rect(GraphicsRect::new(0.0, 0.0, 612.0, 792.0))
  let initial = GraphicsInitialState::from_clip(clip, 2.0, 90)
  let state = GraphicsState::initial(initial)
  assert_eq(state.user_unit, 2.0)
  assert_eq(state.page_rotate, 90)
  assert_eq(state.clipping_path.initial_clip is Some(_), true)
  assert_eq(state.line_width, 1.0)
  assert_eq(state.line_cap == LineCapStyle::ButtCap, true)
  assert_eq(state.line_join == LineJoinStyle::MiterJoin, true)
  assert_eq(state.miter_limit, 10.0)
  assert_eq(state.dash_pattern == DashPattern::solid(), true)
  assert_eq(
    state.rendering_intent == RenderingIntent::RelativeColorimetric,
    true,
  )
  assert_eq(
    state.stroking_colour.colour_space ==
    ColourSpace::Device(DeviceColourSpace::DeviceGray),
    true,
  )
  assert_eq(state.stroking_colour.colour_value.components, [0.0])
}

///|
test "stroke parameter validation accepts edges and rejects malformed values" {
  let state = GraphicsState::initial(GraphicsInitialState::default())
  state.set_line_width(0.0, 1L)
  state.set_miter_limit(1.0, 1L)
  state.set_flatness(100.0, 1L)
  let dash = DashPattern::from_values([1.0, 2.0], 8.0, 1L)
  assert_eq(dash.phase, 2.0)
  let bad_width : Result[Unit, PdfGraphicsError] = try? state.set_line_width(
    -1.0, 7L,
  )
  match bad_width {
    Err(InvalidGraphicsState(offset, _)) => assert_eq(offset, 7L)
    _ => fail("expected invalid line width")
  }
  let bad_dash : Result[DashPattern, PdfGraphicsError] = try? DashPattern::from_values(
    [0.0, 0.0],
    0.0,
    8L,
  )
  match bad_dash {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 8L)
      assert_eq(reason.contains("dash"), true)
    }
    _ => fail("expected invalid dash")
  }
}

///|
test "graphics state stack restores state without path ownership" {
  let state = GraphicsState::initial(GraphicsInitialState::default())
  let stack = GraphicsStateStack::new()
  stack.save(state)
  state.set_line_width(4.0, 1L)
  state.set_colour_space(
    ColourUse::Nonstroking,
    ColourSpace::Device(DeviceColourSpace::DeviceRGB),
  )
  state.set_colour_value(
    ColourUse::Nonstroking,
    ColourValue::{ components: [0.1, 0.2, 0.3], pattern: None },
    1L,
  )
  let restored = stack.restore(2L)
  assert_eq(restored.line_width, 1.0)
  assert_eq(restored.nonstroking_colour.colour_value.components, [0.0])
  assert_eq(state.line_width, 4.0)
  assert_eq(state.nonstroking_colour.colour_value.components, [0.1, 0.2, 0.3])
  let underflow : Result[GraphicsState, PdfGraphicsError] = try? stack.restore(
    3L,
  )
  match underflow {
    Err(GraphicsStackUnderflow(offset)) => assert_eq(offset, 3L)
    _ => fail("expected stack underflow")
  }
}
