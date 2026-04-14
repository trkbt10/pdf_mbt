///|
test "convenience colour operators mutate typed colour state and clamp values" {
  let content = @content.parse_decoded_content(
    b"1.5 g 0.1 0.2 0.3 RG",
    @content.ContentResources::empty(),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.events.length(), 2)
  match program.events[0] {
    StateChanged(_, ColourChanged(Nonstroking, Device(DeviceGray), value), _) =>
      assert_eq(value.components, [1.0])
    _ => fail("expected nonstroking gray colour change")
  }
  match program.events[1] {
    StateChanged(_, ColourChanged(Stroking, Device(DeviceRGB), value), _) =>
      assert_eq(value.components, [0.1, 0.2, 0.3])
    _ => fail("expected stroking RGB colour change")
  }
}

///|
test "named colour spaces resolve resources and reset current colour" {
  let resources = resources_with_colour_space(
    @objects.PdfName::new(b"CS1"),
    cal_rgb_object(),
  )
  let content = @content.parse_decoded_content(b"/CS1 cs", resources)
  let program = interpret_content(content, GraphicsInitialState::default())
  match program.final_state.nonstroking_colour.colour_space {
    CalRGB(_) => ()
    _ => fail("expected CalRGB current colour space")
  }
  assert_eq(program.final_state.nonstroking_colour.colour_value.components, [
    0.0, 0.0, 0.0,
  ])
}

///|
test "default device remapping preserves convenience operator components" {
  let colour_spaces : @objects.PdfDictionary = Map::new()
  colour_spaces[@objects.PdfName::new(b"DefaultRGB")] = cal_rgb_object()
  let resources = resources_with_colour_spaces(colour_spaces)
  let content = @content.parse_decoded_content(b"0.2 0.3 0.4 rg", resources)
  let program = interpret_content(content, GraphicsInitialState::default())
  match program.final_state.nonstroking_colour.colour_space {
    CalRGB(_) => ()
    _ => fail("expected DefaultRGB CalRGB remap")
  }
  assert_eq(program.final_state.nonstroking_colour.colour_value.components, [
    0.2, 0.3, 0.4,
  ])
}

///|
test "SC rejects ICCBased while SCN accepts it" {
  let resources = resources_with_colour_space(
    @objects.PdfName::new(b"I"),
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
      @objects.PdfObject::Stream(test_icc_stream(3L, b"RGB ")),
    ]),
  )
  let bad = @content.parse_decoded_content(b"/I CS 0.1 0.2 0.3 SC", resources)
  let bad_result : Result[GraphicsProgram, PdfGraphicsError] = try? interpret_content(
    bad,
    GraphicsInitialState::default(),
  )
  match bad_result {
    Err(BadOperand(_, reason)) => assert_eq(reason.contains("SC/sc"), true)
    _ => fail("expected SC ICCBased rejection")
  }

  let good = @content.parse_decoded_content(b"/I CS 0.1 0.2 0.3 SCN", resources)
  let program = interpret_content(good, GraphicsInitialState::default())
  match program.final_state.stroking_colour.colour_space {
    ICCBased(_) => ()
    _ => fail("expected ICCBased current colour space")
  }
  assert_eq(program.final_state.stroking_colour.colour_value.components, [
    0.1, 0.2, 0.3,
  ])
}

///|
test "SCN stores Pattern payloads with underlying components" {
  let colour_spaces : @objects.PdfDictionary = Map::new()
  colour_spaces[@objects.PdfName::new(b"P")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"Pattern")),
    @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceRGB")),
  ])
  let resources = resources_with_colour_spaces_and_patterns(
    colour_spaces,
    @objects.PdfName::new(b"Tile"),
    colour_operator_tiling_stream(),
  )
  let content = @content.parse_decoded_content(
    b"/P cs 0.1 0.2 0.3 /Tile scn", resources,
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  let value = program.final_state.nonstroking_colour.colour_value
  assert_eq(value.components, [0.1, 0.2, 0.3])
  assert_eq(value.pattern == Some(@objects.PdfName::new(b"Tile")), true)
}

///|
fn resources_with_colour_spaces_and_patterns(
  colour_spaces : @objects.PdfDictionary,
  pattern_name : @objects.PdfName,
  pattern_stream : @objects.PdfStream,
) -> @content.ContentResources {
  let patterns : @objects.PdfDictionary = Map::new()
  patterns[pattern_name] = @objects.PdfObject::Stream(pattern_stream)
  let resource_dict : @objects.PdfDictionary = Map::new()
  resource_dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Dictionary(
    colour_spaces,
  )
  resource_dict[@objects.PdfName::new(b"Pattern")] = @objects.PdfObject::Dictionary(
    patterns,
  )
  @content.ContentResources::from_dictionary(resource_dict)
}

///|
fn colour_operator_tiling_stream() -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Pattern"),
  )
  dict[@objects.PdfName::new(b"PatternType")] = @objects.PdfObject::Integer(1L)
  dict[@objects.PdfName::new(b"PaintType")] = @objects.PdfObject::Integer(2L)
  dict[@objects.PdfName::new(b"TilingType")] = @objects.PdfObject::Integer(1L)
  dict[@objects.PdfName::new(b"BBox")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(10L),
  ])
  dict[@objects.PdfName::new(b"XStep")] = @objects.PdfObject::Integer(10L)
  dict[@objects.PdfName::new(b"YStep")] = @objects.PdfObject::Integer(10L)
  dict[@objects.PdfName::new(b"Resources")] = @objects.PdfObject::Dictionary(
    Map::new(),
  )
  @objects.PdfStream::{ dict, data: b"" }
}

///|
test "SCN rejects missing Pattern resources" {
  let content = @content.parse_decoded_content(
    b"/P cs 0.1 0.2 0.3 /Tile scn",
    resources_with_colour_space(
      @objects.PdfName::new(b"P"),
      @objects.PdfObject::Array([
        @objects.PdfObject::Name(@objects.PdfName::new(b"Pattern")),
        @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceRGB")),
      ]),
    ),
  )
  let result : Result[GraphicsProgram, PdfGraphicsError] = try? interpret_content(
    content,
    GraphicsInitialState::default(),
  )
  match result {
    Err(ResourceFailure(_, reason)) =>
      assert_eq(reason.contains("Pattern"), true)
    _ => fail("expected missing Pattern resource failure")
  }
}

///|
test "restricted colour contexts ignore colour operators rendering intent and shading" {
  let initial = GraphicsInitialState::{
    ctm: GraphicsMatrix::identity(),
    initial_clip: None,
    user_unit: 1.0,
    page_rotate: 0,
    colour_restriction: ColourRestriction::Type3Glyph,
  }
  let content = @content.parse_decoded_content(
    b"0.5 g /AbsoluteColorimetric ri /S sh",
    @content.ContentResources::empty(),
  )
  let program = interpret_content(content, initial)
  assert_eq(program.events.length(), 0)
  assert_eq(
    program.final_state.rendering_intent ==
    RenderingIntent::RelativeColorimetric,
    true,
  )
  assert_eq(program.final_state.nonstroking_colour.colour_value.components, [
    0.0,
  ])
}

///|
fn resources_with_colour_space(
  name : @objects.PdfName,
  object : @objects.PdfObject,
) -> @content.ContentResources {
  let colour_spaces : @objects.PdfDictionary = Map::new()
  colour_spaces[name] = object
  resources_with_colour_spaces(colour_spaces)
}

///|
fn resources_with_colour_spaces(
  colour_spaces : @objects.PdfDictionary,
) -> @content.ContentResources {
  let resource_dict : @objects.PdfDictionary = Map::new()
  resource_dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Dictionary(
    colour_spaces,
  )
  @content.ContentResources::from_dictionary(resource_dict)
}

///|
fn cal_rgb_object() -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"WhitePoint")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(1L),
    @objects.PdfObject::Integer(1L),
    @objects.PdfObject::Integer(1L),
  ])
  @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"CalRGB")),
    @objects.PdfObject::Dictionary(dict),
  ])
}

///|
fn test_icc_stream(n : Int64, signature : Bytes) -> @objects.PdfStream {
  let data : Array[Byte] = []
  for _ in 0..<128 {
    data.push(b'\x00')
  }
  data[3] = b'\x80'
  data[12] = b'm'
  data[13] = b'n'
  data[14] = b't'
  data[15] = b'r'
  data[16] = signature[0]
  data[17] = signature[1]
  data[18] = signature[2]
  data[19] = signature[3]
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Integer(n)
  @objects.PdfStream::{ dict, data: Bytes::from_array(data) }
}
