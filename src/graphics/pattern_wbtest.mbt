///|
test "tiling pattern stream validates required fields and defaults matrix" {
  let resource = parse_pattern_object(
    name(b"Tile"),
    @objects.PdfObject::Stream(
      tiling_stream(PatternPaintType::Coloured, 10.0, 10.0),
    ),
    ColourDefaults::empty(),
    12L,
  )
  match resource {
    DirectPattern(pattern_name, Tiling(pattern)) => {
      assert_eq(pattern_name == name(b"Tile"), true)
      assert_eq(pattern.paint_type == PatternPaintType::Coloured, true)
      assert_eq(pattern.tiling_type == TilingType::NoDistortion, true)
      assert_eq(pattern.matrix == GraphicsMatrix::identity(), true)
      assert_eq(pattern.bbox == GraphicsRect::new(0.0, 0.0, 0.0, 20.0), true)
    }
    _ => fail("expected direct tiling pattern")
  }
}

///|
test "tiling pattern rejects zero step values" {
  let result : Result[PatternResource, PdfGraphicsError] = try? parse_pattern_object(
    name(b"Tile"),
    @objects.PdfObject::Stream(
      tiling_stream(PatternPaintType::Uncoloured, 0.0, 10.0),
    ),
    ColourDefaults::empty(),
    44L,
  )
  match result {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 44L)
      assert_eq(reason.contains("nonzero"), true)
    }
    _ => fail("expected zero step rejection")
  }
}

///|
test "shading pattern wrapper validates direct axial shading defaults" {
  let resource = parse_pattern_object(
    name(b"ShadePattern"),
    @objects.PdfObject::Dictionary(shading_pattern_dict(axial_shading_object())),
    ColourDefaults::empty(),
    5L,
  )
  match resource {
    DirectPattern(_, Shading(pattern)) => {
      assert_eq(pattern.matrix == GraphicsMatrix::identity(), true)
      match pattern.shading {
        DirectShading(None, shading) =>
          match shading.kind {
            Axial(axial) => {
              assert_eq(axial.domain, [0.0, 1.0])
              assert_eq(axial.extend_start, false)
              assert_eq(axial.coincident_axis, false)
            }
            _ => fail("expected axial shading")
          }
        _ => fail("expected direct shading")
      }
    }
    _ => fail("expected shading pattern")
  }
}

///|
test "mesh shading validates packed Type 4 records" {
  let resource = parse_shading_object(
    Some(name(b"Mesh")),
    @objects.PdfObject::Stream(type4_mesh_stream()),
    ColourDefaults::empty(),
    9L,
  )
  match resource {
    DirectShading(Some(shading_name), shading) => {
      assert_eq(shading_name == name(b"Mesh"), true)
      match shading.kind {
        FreeFormMesh(mesh) => {
          assert_eq(mesh.summary.vertex_count, 3)
          assert_eq(mesh.summary.triangle_count, 1)
          assert_eq(mesh.summary.decoded_length, 18)
        }
        _ => fail("expected free-form mesh")
      }
    }
    _ => fail("expected direct mesh shading")
  }
}

///|
test "Pattern colour selection validates uncoloured tiling operands and emits event" {
  let resources = resources_with_pattern_and_space(
    tiling_stream(PatternPaintType::Uncoloured, 10.0, 10.0),
  )
  let content = @content.parse_decoded_content(
    b"/P cs 0.1 0.2 0.3 /Tile scn", resources,
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.events.length(), 2)
  match program.events[1] {
    PatternColourSelected(
      _,
      Nonstroking,
      DirectPattern(_, Tiling(pattern)),
      value,
      _
    ) => {
      assert_eq(pattern.paint_type == PatternPaintType::Uncoloured, true)
      assert_eq(value.components, [0.1, 0.2, 0.3])
      assert_eq(value.pattern == Some(name(b"Tile")), true)
    }
    _ => fail("expected pattern colour selection event")
  }
}

///|
test "sh operator validates Shading resources without mutating current colour" {
  let resources = resources_with_shading(axial_shading_object())
  let content = @content.parse_decoded_content(b"0.2 g /S sh", resources)
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.events.length(), 2)
  match program.events[1] {
    ShadingPainted(_, DirectShading(Some(shading_name), shading), state) => {
      assert_eq(shading_name == name(b"S"), true)
      match shading.kind {
        Axial(_) => ()
        _ => fail("expected axial shading")
      }
      assert_eq(state.nonstroking_colour.colour_value.components, [0.2])
    }
    _ => fail("expected shading painted event")
  }
}

///|
fn name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn num(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn int(value : Int64) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value)
}

///|
fn tiling_stream(
  paint_type : PatternPaintType,
  x_step : Double,
  y_step : Double,
) -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[name(b"Type")] = @objects.PdfObject::Name(name(b"Pattern"))
  dict[name(b"PatternType")] = int(1L)
  dict[name(b"PaintType")] = match paint_type {
    Coloured => int(1L)
    Uncoloured => int(2L)
  }
  dict[name(b"TilingType")] = int(2L)
  dict[name(b"BBox")] = @objects.PdfObject::Array([
    int(0L),
    int(0L),
    int(0L),
    int(20L),
  ])
  dict[name(b"XStep")] = num(x_step)
  dict[name(b"YStep")] = num(y_step)
  dict[name(b"Resources")] = @objects.PdfObject::Dictionary(Map::new())
  @objects.PdfStream::{ dict, data: b"0 0 m" }
}

///|
fn shading_pattern_dict(shading : @objects.PdfObject) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[name(b"Type")] = @objects.PdfObject::Name(name(b"Pattern"))
  dict[name(b"PatternType")] = int(2L)
  dict[name(b"Shading")] = shading
  dict
}

///|
fn axial_shading_object() -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[name(b"ShadingType")] = int(2L)
  dict[name(b"ColorSpace")] = @objects.PdfObject::Name(name(b"DeviceRGB"))
  dict[name(b"Coords")] = @objects.PdfObject::Array([
    int(0L),
    int(0L),
    int(1L),
    int(0L),
  ])
  dict[name(b"Function")] = @objects.PdfObject::Dictionary(Map::new())
  @objects.PdfObject::Dictionary(dict)
}

///|
fn type4_mesh_stream() -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[name(b"ShadingType")] = int(4L)
  dict[name(b"ColorSpace")] = @objects.PdfObject::Name(name(b"DeviceRGB"))
  dict[name(b"BitsPerCoordinate")] = int(8L)
  dict[name(b"BitsPerComponent")] = int(8L)
  dict[name(b"BitsPerFlag")] = int(8L)
  dict[name(b"Decode")] = @objects.PdfObject::Array([
    int(0L),
    int(1L),
    int(0L),
    int(1L),
    int(0L),
    int(1L),
    int(0L),
    int(1L),
    int(0L),
    int(1L),
  ])
  @objects.PdfStream::{
    dict,
    data: Bytes::from_array([
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01', b'\x00', b'\x00', b'\x00',
    ]),
  }
}

///|
fn resources_with_pattern_and_space(
  stream : @objects.PdfStream,
) -> @content.ContentResources {
  let colour_spaces : @objects.PdfDictionary = Map::new()
  colour_spaces[name(b"P")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(name(b"Pattern")),
    @objects.PdfObject::Name(name(b"DeviceRGB")),
  ])
  let patterns : @objects.PdfDictionary = Map::new()
  patterns[name(b"Tile")] = @objects.PdfObject::Stream(stream)
  let resources : @objects.PdfDictionary = Map::new()
  resources[name(b"ColorSpace")] = @objects.PdfObject::Dictionary(colour_spaces)
  resources[name(b"Pattern")] = @objects.PdfObject::Dictionary(patterns)
  @content.ContentResources::from_dictionary(resources)
}

///|
fn resources_with_shading(
  shading : @objects.PdfObject,
) -> @content.ContentResources {
  let shadings : @objects.PdfDictionary = Map::new()
  shadings[name(b"S")] = shading
  let resources : @objects.PdfDictionary = Map::new()
  resources[name(b"Shading")] = @objects.PdfObject::Dictionary(shadings)
  @content.ContentResources::from_dictionary(resources)
}
