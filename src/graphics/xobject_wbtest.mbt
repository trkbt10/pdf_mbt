///|
test "Do resolves direct image XObject into descriptor event" {
  let content = @content.parse_decoded_content(
    b"/Im1 Do",
    image_resource_context(None),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.events.length(), 1)
  match program.events[0] {
    ImagePainted(_, descriptor, state) => {
      assert_eq(descriptor.layout.bytes_per_row, 3)
      assert_eq(state.ctm == GraphicsMatrix::identity(), true)
    }
    _ => fail("expected typed image event")
  }
}

///|
test "Do reports missing XObject resource as typed graphics error" {
  let content = @content.parse_decoded_content(
    b"/Missing Do",
    @content.ContentResources::empty(),
  )
  let result : Result[GraphicsProgram, PdfGraphicsError] = try? interpret_content(
    content,
    GraphicsInitialState::default(),
  )
  match result {
    Err(InvalidXObject(_, reason)) =>
      assert_eq(reason.contains("missing"), true)
    _ => fail("expected missing XObject error")
  }
}

///|
test "inline image validates Length and emits descriptor event" {
  let content = @content.parse_decoded_content(
    b"BI /W 1 /H 1 /CS /RGB /BPC 8 /Length 3 ID abc EI",
    @content.ContentResources::empty(),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.events.length(), 1)
  match program.events[0] {
    InlineImagePainted(_, descriptor, _) => {
      assert_eq(descriptor.width, 1)
      assert_eq(descriptor.layout.expected_decoded_length, 3)
    }
    _ => fail("expected inline image descriptor event")
  }
}

///|
test "Form XObject invocation scopes nested graphics and restores parent state" {
  let content = @content.parse_decoded_content(
    b"2 w /Fm1 Do",
    form_resource_context(),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.final_state.line_width, 2.0)
  assert_eq(program.events.length(), 4)
  match program.events[1] {
    FormXObjectBegan(_, form, state) => {
      assert_eq(form.bbox == GraphicsRect::new(0.0, 0.0, 10.0, 10.0), true)
      assert_eq(state.clipping_path.clips.length(), 1)
    }
    _ => fail("expected form begin")
  }
  match program.events[2] {
    PathPainted(_, FillPath(NonZero), _, state) =>
      assert_eq(state.line_width, 2.0)
    _ => fail("expected nested form paint")
  }
  match program.events[3] {
    FormXObjectEnded(_, _, state) => assert_eq(state.line_width, 2.0)
    _ => fail("expected form end")
  }
}

///|
test "hidden marked content suppresses paint but keeps state side effects" {
  let resources = optional_content_resource_context()
  let content = @content.parse_decoded_content(
    b"/OC /Hidden BDC 2 w 0 0 10 10 re S EMC", resources,
  )
  let program = interpret_content_with_options(
    content,
    GraphicsInitialState::default(),
    GraphicsInterpretOptions::{
      optional_content_state: OptionalContentState::from_hidden([], [
        @objects.PdfName::new(b"Hidden"),
      ]),
    },
  )
  assert_eq(program.final_state.line_width, 2.0)
  for event in program.events {
    match event {
      PathPainted(_, _, _, _) =>
        fail("hidden marked content must suppress paint")
      _ => ()
    }
  }
}

///|
test "hidden XObject optional content emits skipped outcome" {
  let oc_dict : @objects.PdfDictionary = Map::new()
  oc_dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"OCG"),
  )
  oc_dict[@objects.PdfName::new(b"Name")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Hidden"),
  )
  let content = @content.parse_decoded_content(
    b"/Im1 Do",
    image_resource_context(Some(@objects.PdfObject::Dictionary(oc_dict))),
  )
  let program = interpret_content_with_options(
    content,
    GraphicsInitialState::default(),
    GraphicsInterpretOptions::{
      optional_content_state: OptionalContentState::from_hidden([], [
        @objects.PdfName::new(b"Hidden"),
      ]),
    },
  )
  match program.events[0] {
    XObjectSkipped(_, name, Hidden) =>
      assert_eq(name == @objects.PdfName::new(b"Im1"), true)
    _ => fail("expected skipped hidden XObject")
  }
}

///|
fn image_resource_context(
  oc : @objects.PdfObject?,
) -> @content.ContentResources {
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
  if oc is Some(value) {
    image_dict[@objects.PdfName::new(b"OC")] = value
  }
  let xobjects : @objects.PdfDictionary = Map::new()
  xobjects[@objects.PdfName::new(b"Im1")] = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: image_dict,
    data: Bytes::from_array([b'\x00', b'\x00', b'\x00']),
  })
  let resources : @objects.PdfDictionary = Map::new()
  resources[@objects.PdfName::new(b"XObject")] = @objects.PdfObject::Dictionary(
    xobjects,
  )
  @content.ContentResources::from_dictionary(resources)
}

///|
fn form_resource_context() -> @content.ContentResources {
  let form_dict : @objects.PdfDictionary = Map::new()
  form_dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"XObject"),
  )
  form_dict[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Form"),
  )
  form_dict[@objects.PdfName::new(b"BBox")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(10L),
  ])
  let xobjects : @objects.PdfDictionary = Map::new()
  xobjects[@objects.PdfName::new(b"Fm1")] = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: form_dict,
    data: b"0 0 5 5 re f",
  })
  let resources : @objects.PdfDictionary = Map::new()
  resources[@objects.PdfName::new(b"XObject")] = @objects.PdfObject::Dictionary(
    xobjects,
  )
  @content.ContentResources::from_dictionary(resources)
}

///|
fn optional_content_resource_context() -> @content.ContentResources {
  let ocg : @objects.PdfDictionary = Map::new()
  ocg[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"OCG"),
  )
  ocg[@objects.PdfName::new(b"Name")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Hidden"),
  )
  let properties : @objects.PdfDictionary = Map::new()
  properties[@objects.PdfName::new(b"Hidden")] = @objects.PdfObject::Dictionary(
    ocg,
  )
  let resources : @objects.PdfDictionary = Map::new()
  resources[@objects.PdfName::new(b"Properties")] = @objects.PdfObject::Dictionary(
    properties,
  )
  @content.ContentResources::from_dictionary(resources)
}
