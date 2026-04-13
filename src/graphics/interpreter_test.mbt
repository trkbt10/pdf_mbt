///|
test "interpret content applies graphics state and emits path clipping events" {
  let content = @content.parse_decoded_content(
    b"q 2 0 0 2 10 20 cm 5 w 0 0 10 10 re W* B Q",
    @content.ContentResources::empty(),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.final_state.line_width, 1.0)
  assert_eq(program.events.length(), 6)
  match program.events[3] {
    PathPainted(_, FillStrokePath(NonZero), path, state) => {
      assert_eq(path.subpaths.length(), 1)
      assert_eq(state.line_width, 5.0)
    }
    _ => fail("expected fill-stroke path event")
  }
  match program.events[4] {
    ClipChanged(_, clip) => assert_eq(clip.clips.length(), 1)
    _ => fail("expected clip changed event")
  }
}

///|
test "interpret content reports operand failure with source offset" {
  let content = @content.parse_decoded_content(
    b"/Bad w",
    @content.ContentResources::empty(),
  )
  let result : Result[GraphicsProgram, PdfGraphicsError] = try? interpret_content(
    content,
    GraphicsInitialState::default(),
  )
  match result {
    Err(BadOperand(offset, reason)) => {
      assert_eq(offset, 5L)
      assert_eq(reason.contains("number"), true)
    }
    _ => fail("expected bad operand")
  }
}

///|
test "interpret content classifies deferred domains in input order" {
  let content = @content.parse_decoded_content(
    b"BT /F1 12 Tf ET /Im1 Do /Shade sh 0.5 g /Tag BMC EMC",
    @content.ContentResources::empty(),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.events.length(), 8)
  match program.events[0] {
    TextObjectBegan(_) => ()
    _ => fail("expected text begin")
  }
  match program.events[2] {
    TextObjectEnded(_) => ()
    _ => fail("expected text end")
  }
  match program.events[3] {
    ExternalObjectInvoked(_, name) =>
      assert_eq(name == @objects.PdfName::new(b"Im1"), true)
    _ => fail("expected xobject event")
  }
  match program.events[4] {
    ShadingSeen(_, name) =>
      assert_eq(name == @objects.PdfName::new(b"Shade"), true)
    _ => fail("expected shading event")
  }
  match program.events[5] {
    StateChanged(_, ColourChanged(Nonstroking, Device(DeviceGray), value), _) =>
      assert_eq(value.components, [0.5])
    _ => fail("expected color event")
  }
}
