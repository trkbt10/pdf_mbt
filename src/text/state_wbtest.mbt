///|
test "text state defaults and font selection are inspectable" {
  let state = TextState::initial()
  assert_eq(state.character_spacing, 0.0)
  assert_eq(state.word_spacing, 0.0)
  assert_eq(state.horizontal_scaling, 1.0)
  assert_eq(state.leading, 0.0)
  assert_eq(state.font_name is None, true)
  assert_eq(state.font_size is None, true)
  assert_eq(state.rendering_mode == TextRenderingMode::Fill, true)
  assert_eq(state.text_rise, 0.0)
  assert_eq(state.text_knockout, true)

  let selected = state.with_font(@objects.PdfName::new(b"F1"), -12.0)
  assert_eq(selected.font_name == Some(@objects.PdfName::new(b"F1")), true)
  assert_eq(selected.font_size, Some(-12.0))
}

///|
test "rendering mode predicates cover modes zero through seven" {
  let modes = [
    TextRenderingMode::Fill,
    TextRenderingMode::Stroke,
    TextRenderingMode::FillStroke,
    TextRenderingMode::Invisible,
    TextRenderingMode::FillClip,
    TextRenderingMode::StrokeClip,
    TextRenderingMode::FillStrokeClip,
    TextRenderingMode::Clip,
  ]
  for i in 0..<modes.length() {
    assert_eq(
      TextRenderingMode::from_int(i.to_int64(), TextErrorContext::at(0L)) ==
      modes[i],
      true,
    )
  }
  assert_eq(TextRenderingMode::Fill.fills(), true)
  assert_eq(TextRenderingMode::Stroke.strokes(), true)
  assert_eq(TextRenderingMode::Invisible.is_invisible(), true)
  assert_eq(TextRenderingMode::Clip.clips(), true)

  let normal = TextPaintIntent::from_rendering_mode(
    TextRenderingMode::FillStrokeClip,
    false,
  )
  assert_eq(normal.fill, true)
  assert_eq(normal.stroke, true)
  assert_eq(normal.clip, true)
  let type3 = TextPaintIntent::from_rendering_mode(
    TextRenderingMode::Clip,
    true,
  )
  assert_eq(type3.clip, false)
  assert_eq(type3.type3_clip_suppressed, true)
}

///|
test "text object state moves line matrix and stack restores snapshots" {
  let object_state = TextObjectState::initial().move_line(10.0, 20.0)
  assert_eq(object_state.text_matrix.e, 10.0)
  assert_eq(object_state.text_line_matrix.f, 20.0)

  let stack = TextStateStack::new()
  let state = TextState::initial().with_font(@objects.PdfName::new(b"F1"), 12.0)
  stack.save(state, Some(object_state))
  let restored = stack.restore(TextErrorContext::at(0L))
  assert_eq(restored.state == state, true)
  assert_eq(restored.object_state == Some(object_state), true)

  let underflow : Result[TextStateSnapshot, PdfTextError] = try? stack.restore(
    TextErrorContext::at(9L),
  )
  match underflow {
    Err(InvalidTextState(context, reason)) => {
      assert_eq(context.offset, 9L)
      assert_eq(reason.contains("underflow"), true)
    }
    _ => fail("expected stack underflow")
  }
}


///|
test "text state computes effective matrix factors" {
  let state = TextState::initial()
    .with_font(@objects.PdfName::new(b"F1"), 12.0)
    .with_horizontal_scaling_percent(80.0)
    .with_text_rise(3.0)
  assert_eq(state.effective_font_size(TextErrorContext::at(1L)), 12.0)
  assert_eq(state.horizontal_scale_factor(), 0.8)
  assert_eq(state.vertical_scale_factor(), 1.0)
  let matrix = state.text_state_matrix(TextErrorContext::at(1L))
  assert_eq(matrix.a, 9.600000000000001)
  assert_eq(matrix.d, 12.0)
  assert_eq(matrix.f, 3.0)
}

///|
test "rendering modes construct paint and clipping paths" {
  let fill_clip = TextRenderingMode::FillClip.path_construction(false)
  assert_eq(fill_clip.build_glyph_path, true)
  assert_eq(fill_clip.fill_path, true)
  assert_eq(fill_clip.add_to_clip, true)
  let invisible = TextRenderingMode::Invisible.path_construction(false)
  assert_eq(invisible.build_glyph_path, false)
  let type3_clip = TextRenderingMode::Clip.path_construction(true)
  assert_eq(type3_clip.add_to_clip, false)
  assert_eq(type3_clip.suppress_type3_clip, true)
}

///|
test "text positioning operator helpers update text and line matrices" {
  let moved = TextObjectState::initial().apply_td(10.0, 20.0)
  assert_eq(moved.text_matrix.e, 10.0)
  assert_eq(moved.text_line_matrix.f, 20.0)
  let matrix = moved.apply_tm(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
  assert_eq(matrix.text_matrix.b, 2.0)
  assert_eq(matrix.text_line_matrix.e, 5.0)
  let next = matrix.apply_tstar(7.0)
  assert_eq(next.text_matrix.e, 5.0)
  assert_eq(next.text_matrix.f, -1.0)
}
