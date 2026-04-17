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
    ClipChanged(_, clip) => {
      assert_eq(clip.clips.length(), 1)
      let subpath = clip.clips[0].path.subpaths[0]
      assert_eq(subpath.start == GraphicsPoint::new(10.0, 20.0), true)
      match subpath.segments[1] {
        LineTo(point) =>
          assert_eq(point == GraphicsPoint::new(30.0, 40.0), true)
        _ => fail("expected transformed rectangle segment")
      }
    }
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
    interpreter_test_shading_resources(),
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
    ImagePainted(_, descriptor, _) => {
      assert_eq(descriptor.width, 1)
      assert_eq(descriptor.height, 1)
    }
    _ => fail("expected image xobject event")
  }
  match program.events[4] {
    ShadingPainted(_, DirectShading(Some(name), _), _) =>
      assert_eq(name == @objects.PdfName::new(b"Shade"), true)
    _ => fail("expected shading event")
  }
  match program.events[5] {
    StateChanged(_, ColourChanged(Nonstroking, Device(DeviceGray), value), _) =>
      assert_eq(value.components, [0.5])
    _ => fail("expected color event")
  }
}

///|
fn interpreter_test_shading_resources() -> @content.ContentResources {
  let shading_dict : @objects.PdfDictionary = Map::new()
  shading_dict[@objects.PdfName::new(b"ShadingType")] = @objects.PdfObject::Integer(
    2L,
  )
  shading_dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"DeviceRGB"),
  )
  shading_dict[@objects.PdfName::new(b"Coords")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(1L),
    @objects.PdfObject::Integer(0L),
  ])
  shading_dict[@objects.PdfName::new(b"Function")] = @objects.PdfObject::Dictionary(
    Map::new(),
  )
  let shadings : @objects.PdfDictionary = Map::new()
  shadings[@objects.PdfName::new(b"Shade")] = @objects.PdfObject::Dictionary(
    shading_dict,
  )
  let resources : @objects.PdfDictionary = Map::new()
  resources[@objects.PdfName::new(b"Shading")] = @objects.PdfObject::Dictionary(
    shadings,
  )
  let image_dict : @objects.PdfDictionary = Map::new()
  image_dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"XObject"),
  )
  image_dict[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Image"),
  )
  image_dict[@objects.PdfName::new(b"Width")] = @objects.PdfObject::Integer(1L)
  image_dict[@objects.PdfName::new(b"Height")] = @objects.PdfObject::Integer(1L)
  image_dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"DeviceRGB"),
  )
  image_dict[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    8L,
  )
  let xobjects : @objects.PdfDictionary = Map::new()
  xobjects[@objects.PdfName::new(b"Im1")] = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: image_dict,
    data: Bytes::from_array([b'\x00', b'\x00', b'\x00']),
  })
  resources[@objects.PdfName::new(b"XObject")] = @objects.PdfObject::Dictionary(
    xobjects,
  )
  @content.ContentResources::from_dictionary(resources)
}
