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
test "inline image rejects Length above 4096 bytes and JPXDecode filter" {
  let too_large : Result[ImageDescriptor, PdfGraphicsError] = try? validate_inline_image(
    inline_image_with_filter(None, 4097L, 4097),
  )
  match too_large {
    Err(InvalidImage(_, reason)) => assert_eq(reason.contains("4096"), true)
    _ => fail("expected inline image 4096 byte Length rejection")
  }

  let jpx : Result[ImageDescriptor, PdfGraphicsError] = try? validate_inline_image(
    inline_image_with_filter(Some(@objects.PdfName::new(b"JPXDecode")), 3L, 3),
  )
  match jpx {
    Err(InvalidImage(_, reason)) => assert_eq(reason.contains("filter"), true)
    _ => fail("expected JPXDecode inline image rejection")
  }
}

///|
test "direct explicit Mask stream must be an ImageMask" {
  let dict = image_dictionary(None)
  dict[@objects.PdfName::new(b"Mask")] = @objects.PdfObject::Stream(
    non_mask_image_stream(),
  )
  let result : Result[ImageDescriptor, PdfGraphicsError] = try? validate_image_dictionary(
    ImageSource::XObjectImage(Some(@objects.PdfName::new(b"Im1"))),
    dict,
    Bytes::from_array([b'\x00', b'\x00', b'\x00']),
    false,
    11L,
  )
  match result {
    Err(InvalidImage(offset, reason)) => {
      assert_eq(offset, 11L)
      assert_eq(reason.contains("ImageMask"), true)
    }
    _ => fail("expected explicit Mask ImageMask validation")
  }
}

///|
test "alternate image dictionary requires Image entry" {
  let dict = image_dictionary(None)
  dict[@objects.PdfName::new(b"Alternates")] = @objects.PdfObject::Array([
    @objects.PdfObject::Dictionary(Map::new()),
  ])
  let result : Result[ImageDescriptor, PdfGraphicsError] = try? validate_image_dictionary(
    ImageSource::XObjectImage(Some(@objects.PdfName::new(b"Im1"))),
    dict,
    Bytes::from_array([b'\x00', b'\x00', b'\x00']),
    false,
    12L,
  )
  match result {
    Err(InvalidGraphicsState(_, _)) | Err(InvalidImage(_, _)) => ()
    _ => fail("expected missing alternate Image entry rejection")
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
test "direct form helper interprets loaded form with scoped resources" {
  let base = form_stream_with_ref(Map::new())
  base.dict.remove(@objects.PdfName::new(b"Ref")) |> ignore
  let stream = @objects.PdfStream::{ dict: base.dict, data: b"0 0 2 2 re f" }
  let form = validate_form_xobject(
    Some(@objects.PdfName::new(b"Fm1")),
    stream,
    15L,
  )
  let parent = GraphicsState::initial(GraphicsInitialState::default())
  parent.set_line_width(3.0, 15L)
  let program = interpret_form_xobject(
    form,
    @content.ContentResources::empty(),
    parent,
    GraphicsInterpretOptions::default(),
    15L,
  )
  assert_eq(program.final_state.line_width, 3.0)
  assert_eq(program.events.length(), 3)
  match program.events[1] {
    PathPainted(_, FillPath(NonZero), _, state) =>
      assert_eq(state.line_width, 3.0)
    _ => fail("expected nested form paint from direct helper")
  }
}

///|
test "reference XObject dictionary requires target file and page" {
  let stream = form_stream_with_ref(Map::new())
  let missing : Result[FormXObject, PdfGraphicsError] = try? validate_form_xobject(
    Some(@objects.PdfName::new(b"Fm1")),
    stream,
    13L,
  )
  match missing {
    Err(InvalidGraphicsState(_, _)) | Err(InvalidXObject(_, _)) => ()
    _ => fail("expected missing reference F and Page rejection")
  }

  let ref_dict : @objects.PdfDictionary = Map::new()
  ref_dict[@objects.PdfName::new(b"F")] = @objects.PdfObject::String(
    b"target.pdf",
  )
  ref_dict[@objects.PdfName::new(b"Page")] = @objects.PdfObject::Integer(1L)
  let form = validate_form_xobject(
    Some(@objects.PdfName::new(b"Fm1")),
    form_stream_with_ref(ref_dict),
    14L,
  )
  match form.reference {
    Some(reference) => {
      assert_eq(reference.file_spec is Some(_), true)
      assert_eq(reference.page is Some(_), true)
    }
    None => fail("expected reference XObject metadata")
  }
}

///|
test "form XObject preserves validated PieceInfo" {
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
  let piece : @objects.PdfDictionary = Map::new()
  let data : @objects.PdfDictionary = Map::new()
  data[@objects.PdfName::new(b"LastModified")] = @objects.PdfObject::String(
    b"D:20260414",
  )
  data[@objects.PdfName::new(b"Private")] = @objects.PdfObject::String(
    b"opaque",
  )
  piece[@objects.PdfName::new(b"Tool")] = @objects.PdfObject::Dictionary(data)
  form_dict[@objects.PdfName::new(b"PieceInfo")] = @objects.PdfObject::Dictionary(
    piece,
  )

  let form = validate_form_xobject(
    Some(@objects.PdfName::new(b"Fm1")),
    @objects.PdfStream::{ dict: form_dict, data: b"" },
    9L,
  )
  match form.piece_info {
    Some(piece_info) =>
      assert_eq(piece_info.entries[0].last_modified, b"D:20260414")
    None => fail("expected form PieceInfo")
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
fn inline_image_with_filter(
  filter : @objects.PdfName?,
  length : Int64,
  data_length : Int,
) -> @content.PdfInlineImage {
  let dict = image_dictionary(None)
  dict[@objects.PdfName::new(b"Length")] = @objects.PdfObject::Integer(length)
  if filter is Some(name) {
    dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(name)
  }
  let data : Array[Byte] = []
  for _ in 0..<data_length {
    data.push(b'\x00')
  }
  @content.PdfInlineImage::{
    dictionary: dict,
    data: Bytes::from_array(data),
    start_offset: 10L,
    data_offset: 20L,
    end_offset: 30L,
  }
}

///|
fn non_mask_image_stream() -> @objects.PdfStream {
  @objects.PdfStream::{
    dict: image_dictionary(None),
    data: Bytes::from_array([b'\x00', b'\x00', b'\x00']),
  }
}

///|
fn form_stream_with_ref(
  ref_dict : @objects.PdfDictionary,
) -> @objects.PdfStream {
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
  form_dict[@objects.PdfName::new(b"Ref")] = @objects.PdfObject::Dictionary(
    ref_dict,
  )
  @objects.PdfStream::{ dict: form_dict, data: b"" }
}

///|
fn image_resource_context(
  oc : @objects.PdfObject?,
) -> @content.ContentResources {
  let image_dict = image_dictionary(oc)
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
fn image_dictionary(oc : @objects.PdfObject?) -> @objects.PdfDictionary {
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
  image_dict
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
