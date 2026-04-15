///|
fn colour_fn_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn colour_fn_number(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn type2_colour_function(
  c0 : Array[Double],
  c1 : Array[Double],
  exponent : Double,
) -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  let c0_objects : Array[@objects.PdfObject] = []
  let c1_objects : Array[@objects.PdfObject] = []
  for value in c0 {
    c0_objects.push(colour_fn_number(value))
  }
  for value in c1 {
    c1_objects.push(colour_fn_number(value))
  }
  dict[colour_fn_name(b"FunctionType")] = @objects.PdfObject::Integer(2L)
  dict[colour_fn_name(b"Domain")] = @objects.PdfObject::Array([
    colour_fn_number(0.0),
    colour_fn_number(1.0),
  ])
  dict[colour_fn_name(b"C0")] = @objects.PdfObject::Array(c0_objects)
  dict[colour_fn_name(b"C1")] = @objects.PdfObject::Array(c1_objects)
  dict[colour_fn_name(b"N")] = colour_fn_number(exponent)
  @objects.PdfObject::Dictionary(dict)
}

///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_eq(actual.is_close(expected, absolute_tolerance=0.000001), true)
}

///|
test "device gray and cmyk rgb conversions follow classic formulas" {
  let rgb = device_gray_to_rgb(0.25)
  assert_close(rgb.red, 0.25)
  assert_close(rgb.green, 0.25)
  assert_close(rgb.blue, 0.25)

  let cmyk = device_rgb_to_cmyk(DeviceRgbColour::{
    red: 0.2,
    green: 0.5,
    blue: 0.75,
  })
  assert_close(cmyk.cyan, 0.55)
  assert_close(cmyk.magenta, 0.25)
  assert_close(cmyk.yellow, 0.0)
  assert_close(cmyk.black, 0.25)

  let restored = device_cmyk_to_rgb(DeviceCmykColour::{
    cyan: 0.55,
    magenta: 0.25,
    yellow: 0.0,
    black: 0.25,
  })
  assert_close(restored.red, 0.2)
  assert_close(restored.green, 0.5)
  assert_close(restored.blue, 0.75)
}

///|
test "rgb to cmyk applies direct black generation and undercolour removal" {
  let cmyk = device_rgb_to_cmyk(
    DeviceRgbColour::{ red: 0.2, green: 0.5, blue: 0.75 },
    black_generation=DirectTransformFunction(
      type2_colour_function([0.0], [0.5], 1.0),
    ),
    undercolour_removal=DirectTransformFunction(
      type2_colour_function([0.0], [0.1], 1.0),
    ),
  )
  assert_close(cmyk.cyan, 0.775)
  assert_close(cmyk.magenta, 0.475)
  assert_close(cmyk.yellow, 0.225)
  assert_close(cmyk.black, 0.125)
}

///|
test "calibrated gray and rgb convert to CIE XYZ" {
  let cal_gray = CalGrayParams::{
    white_point: [0.95047, 1.0, 1.08883],
    black_point: [0.0, 0.0, 0.0],
    gamma: 2.0,
  }
  let gray_xyz = cal_gray.to_xyz(0.5)
  assert_close(gray_xyz.x, 0.2376175)
  assert_close(gray_xyz.y, 0.25)
  assert_close(gray_xyz.z, 0.2722075)

  let cal_rgb = CalRGBParams::{
    white_point: [0.95047, 1.0, 1.08883],
    black_point: [0.0, 0.0, 0.0],
    gamma: [1.0, 1.0, 1.0],
    matrix: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
  }
  let rgb_xyz = cal_rgb.to_xyz([0.2, 0.4, 0.6])
  assert_close(rgb_xyz.x, 0.2)
  assert_close(rgb_xyz.y, 0.4)
  assert_close(rgb_xyz.z, 0.6)
}

///|
test "Lab D50 conversion maps neutral endpoints to sRGB endpoints" {
  let white = lab_d50_to_srgb(100.0, 0.0, 0.0)
  assert_close(white.red, 1.0)
  assert_close(white.green, 1.0)
  assert_close(white.blue, 1.0)

  let black = lab_d50_to_srgb(0.0, 0.0, 0.0)
  assert_close(black.red, 0.0)
  assert_close(black.green, 0.0)
  assert_close(black.blue, 0.0)
}

///|
test "Indexed lookup maps selected bytes through base component ranges" {
  let params = IndexedParams::{
    base: ColourSpace::Device(DeviceColourSpace::DeviceRGB),
    hival: 1,
    lookup: @objects.PdfObject::String(
      Bytes::from_array([b'\xff', b'\x00', b'\x00', b'\x00', b'\x80', b'\xff']),
    ),
  }
  let value = params.lookup_colour_value(1.0)
  assert_close(value.components[0], 0.0)
  assert_close(value.components[1], 128.0 / 255.0)
  assert_close(value.components[2], 1.0)
  let rgb = params.lookup_device_rgb(1.0)
  assert_close(rgb.red, 0.0)
  assert_close(rgb.green, 128.0 / 255.0)
  assert_close(rgb.blue, 1.0)
}

///|
test "Separation and DeviceN apply tint transforms to alternate spaces" {
  let separation = SeparationParams::{
    colorant: colour_fn_name(b"Spot"),
    alternate: ColourSpace::Device(DeviceColourSpace::DeviceGray),
    tint_transform: type2_colour_function([1.0], [0.0], 1.0),
  }
  let alternate = separation.alternate_colour_value(0.25)
  assert_close(alternate.components[0], 0.75)

  let device_n = DeviceNParams::{
    colorants: [
      colour_fn_name(b"Cyan"),
      colour_fn_name(b"Magenta"),
      colour_fn_name(b"Yellow"),
    ],
    alternate: ColourSpace::Device(DeviceColourSpace::DeviceRGB),
    tint_transform: @objects.PdfObject::Name(colour_fn_name(b"Identity")),
    attributes: None,
  }
  let rgb = device_n.alternate_colour_value([0.1, 0.2, 0.3])
  assert_close(rgb.components[0], 0.1)
  assert_close(rgb.components[1], 0.2)
  assert_close(rgb.components[2], 0.3)
}

///|
test "transfer functions apply one in one out transforms to components" {
  let gamma = DirectTransformFunction(type2_colour_function([0.0], [1.0], 2.0))
  let single = apply_transfer_functions([0.5, 0.25], SingleTransfer(gamma))
  assert_close(single[0], 0.25)
  assert_close(single[1], 0.0625)

  let component = apply_transfer_functions(
    [0.2, 0.7],
    ComponentTransfers([
      DirectTransformFunction(type2_colour_function([0.0], [1.0], 1.0)),
      DirectTransformFunction(type2_colour_function([1.0], [0.0], 1.0)),
    ]),
  )
  assert_close(component[0], 0.2)
  assert_close(component[1], 0.3)
}

///|
test "ICCBased component detection and pattern state accessors are exposed" {
  let info = IccProfileInfo::{
    component_count: 3,
    data_colour_space: colour_fn_name(b"RGB "),
    decoded_length: 128,
    rendering_intent: RenderingIntent::RelativeColorimetric,
  }
  let params = IccBasedParams::{
    source: IccProfileSource::DirectProfile(info),
    component_count: 3,
    range: [
      ColourRange::{ min: 0.0, max: 1.0 },
      ColourRange::{ min: 0.0, max: 1.0 },
      ColourRange::{ min: 0.0, max: 1.0 },
    ],
    alternate: None,
    metadata: None,
  }
  assert_eq(params.detected_component_count(), 3)

  let state = ColourState::{
    colour_space: ColourSpace::Pattern(PatternParams::{
      underlying: Some(ColourSpace::Device(DeviceColourSpace::DeviceRGB)),
    }),
    colour_value: ColourValue::{
      components: [0.1, 0.2, 0.3],
      pattern: Some(colour_fn_name(b"Tile")),
    },
  }
  assert_eq(state.selected_pattern() == Some(colour_fn_name(b"Tile")), true)
}
