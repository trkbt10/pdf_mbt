///|
test "ColourState fill and stroke helpers normalize values without mutation" {
  let initial = ColourState::initial()
  let filled = initial.with_fill_colour(ColourValue::{
    components: [1.5],
    pattern: None,
  })
  assert_eq(filled.colour_value.components, [1.0])
  assert_eq(initial.colour_value.components, [0.0])

  let stroked = initial.with_stroke_colour(ColourValue::{
    components: [-1.0],
    pattern: None,
  })
  assert_eq(stroked.colour_value.components, [0.0])
  assert_eq(stroked.colour_space == initial.colour_space, true)
}

///|
test "ColourState helpers preserve Pattern payload validation" {
  let state = ColourState::{
    colour_space: ColourSpace::Pattern(PatternParams::{
      underlying: Some(ColourSpace::Device(DeviceColourSpace::DeviceRGB)),
    }),
    colour_value: ColourValue::{ components: [], pattern: None },
  }
  let selected = state.with_stroke_colour(ColourValue::{
    components: [0.2, 0.4, 0.6],
    pattern: Some(@objects.PdfName::new(b"Tile")),
  })
  assert_eq(selected.colour_value.components, [0.2, 0.4, 0.6])
  assert_eq(
    selected.colour_value.pattern == Some(@objects.PdfName::new(b"Tile")),
    true,
  )
}

///|
test "ColourState resolves default device spaces through ColourDefaults" {
  let state = ColourState::{
    colour_space: ColourSpace::Device(DeviceColourSpace::DeviceRGB),
    colour_value: ColourValue::{ components: [0.0, 0.0, 0.0], pattern: None },
  }
  let defaults = ColourDefaults::{
    default_gray: None,
    default_rgb: Some(colour_state_cal_rgb_object()),
    default_cmyk: None,
  }
  let resolved = state.resolve_default_space(defaults)
  match resolved {
    CalRGB(params) => assert_eq(params.gamma, [1.0, 1.0, 1.0])
    _ => fail("expected DefaultRGB CalRGB resolution")
  }
}

///|
fn colour_state_cal_rgb_object() -> @objects.PdfObject {
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
