///|
test "device and calibrated colour spaces expose components ranges and initial values" {
  let cmyk = parse_colour_space_object(
    @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceCMYK")),
    ColourDefaults::empty(),
    1L,
  )
  assert_eq(cmyk.component_count(), 4)
  assert_eq(cmyk.initial_value().components, [0.0, 0.0, 0.0, 1.0])
  assert_eq(cmyk.is_device_space(), true)
  assert_eq(
    cmyk.to_device_family() == Some(DeviceColourSpace::DeviceCMYK),
    true,
  )

  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"WhitePoint")] = number_array([1.0, 1.0, 1.0])
  dict[@objects.PdfName::new(b"Gamma")] = @objects.PdfObject::Real(2.2)
  let cal_gray = parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"CalGray")),
      @objects.PdfObject::Dictionary(dict),
    ]),
    ColourDefaults::empty(),
    2L,
  )
  assert_eq(cal_gray.component_count(), 1)
  assert_eq(cal_gray.is_device_space(), false)
  assert_eq(cal_gray.to_device_family() == None, true)
  assert_eq(
    cal_gray.component_ranges() == [ColourRange::{ min: 0.0, max: 1.0 }],
    true,
  )
  assert_eq(cal_gray.initial_value().components, [0.0])
}

///|
test "calibrated colour spaces reject malformed dictionaries" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"WhitePoint")] = number_array([1.0, 2.0, 1.0])
  let result : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"CalRGB")),
      @objects.PdfObject::Dictionary(dict),
    ]),
    ColourDefaults::empty(),
    7L,
  )
  match result {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 7L)
      assert_eq(reason.contains("WhitePoint"), true)
    }
    _ => fail("expected invalid white point")
  }
}

///|
test "Indexed validates bases and direct lookup lengths" {
  let recursive : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"Indexed")),
      @objects.PdfObject::Array([
        @objects.PdfObject::Name(@objects.PdfName::new(b"Indexed")),
        @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceRGB")),
        @objects.PdfObject::Integer(0L),
        @objects.PdfObject::String(
          Bytes::from_array([b'\x00', b'\x00', b'\x00']),
        ),
      ]),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::String(Bytes::from_array([b'\x00'])),
    ]),
    ColourDefaults::empty(),
    10L,
  )
  match recursive {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 10L)
      assert_eq(reason.contains("Indexed"), true)
    }
    _ => fail("expected recursive Indexed rejection")
  }

  let bad_lookup : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"Indexed")),
      @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceRGB")),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::String(Bytes::from_array([b'\x00', b'\x00', b'\x00'])),
    ]),
    ColourDefaults::empty(),
    11L,
  )
  match bad_lookup {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 11L)
      assert_eq(reason.contains("lookup"), true)
    }
    _ => fail("expected Indexed lookup length rejection")
  }
}

///|
test "special colour spaces reject invalid alternates and DeviceN attributes" {
  let bad_sep : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"Separation")),
      @objects.PdfObject::Name(@objects.PdfName::new(b"Spot")),
      @objects.PdfObject::Name(@objects.PdfName::new(b"Pattern")),
      @objects.PdfObject::Dictionary(Map::new()),
    ]),
    ColourDefaults::empty(),
    20L,
  )
  match bad_sep {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 20L)
      assert_eq(reason.contains("alternate"), true)
    }
    _ => fail("expected Separation alternate rejection")
  }

  let duplicate : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    device_n_object(
      [@objects.PdfName::new(b"Spot"), @objects.PdfName::new(b"Spot")],
      None,
    ),
    ColourDefaults::empty(),
    21L,
  )
  match duplicate {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 21L)
      assert_eq(reason.contains("unique"), true)
    }
    _ => fail("expected DeviceN duplicate rejection")
  }

  let none_repeat = parse_colour_space_object(
    device_n_object(
      [@objects.PdfName::new(b"None"), @objects.PdfName::new(b"None")],
      None,
    ),
    ColourDefaults::empty(),
    22L,
  )
  assert_eq(none_repeat.component_count(), 2)

  let attrs : @objects.PdfDictionary = Map::new()
  attrs[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"NChannel"),
  )
  let missing_colorants : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    device_n_object([@objects.PdfName::new(b"Spot")], Some(attrs)),
    ColourDefaults::empty(),
    23L,
  )
  match missing_colorants {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 23L)
      assert_eq(reason.contains("Colorants"), true)
    }
    _ => fail("expected NChannel Colorants requirement")
  }
}

///|
test "ICCBased direct profile streams validate header and component count" {
  let rgb = parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
      @objects.PdfObject::Stream(icc_stream(3L, b"RGB ", 128)),
    ]),
    ColourDefaults::empty(),
    30L,
  )
  assert_eq(rgb.component_count(), 3)

  let short : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
      @objects.PdfObject::Stream(icc_stream(3L, b"RGB ", 64)),
    ]),
    ColourDefaults::empty(),
    31L,
  )
  match short {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 31L)
      assert_eq(reason.contains("128-byte"), true)
    }
    _ => fail("expected short ICC rejection")
  }

  let mismatch : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
      @objects.PdfObject::Stream(icc_stream(1L, b"RGB ", 128)),
    ]),
    ColourDefaults::empty(),
    32L,
  )
  match mismatch {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 32L)
      assert_eq(reason.contains("N"), true)
    }
    _ => fail("expected ICC N mismatch")
  }

  let bad_class : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
      @objects.PdfObject::Stream(
        icc_stream_with_class(3L, b"RGB ", 128, b"link"),
      ),
    ]),
    ColourDefaults::empty(),
    33L,
  )
  match bad_class {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 33L)
      assert_eq(reason.contains("deviceClass"), true)
    }
    _ => fail("expected ICC deviceClass rejection")
  }
}

///|
test "NChannel validates Table 70 attributes and Table 72 mixing hints" {
  let attrs = nchannel_attributes(
    @objects.PdfName::new(b"Spot"),
    @objects.PdfName::new(b"Spot"),
    true,
  )
  let nchannel = parse_colour_space_object(
    device_n_object([@objects.PdfName::new(b"Spot")], Some(attrs)),
    ColourDefaults::empty(),
    40L,
  )
  assert_eq(nchannel.component_count(), 1)

  let no_printing_order = nchannel_attributes(
    @objects.PdfName::new(b"Spot"),
    @objects.PdfName::new(b"Spot"),
    false,
  )
  let missing_order : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    device_n_object([@objects.PdfName::new(b"Spot")], Some(no_printing_order)),
    ColourDefaults::empty(),
    41L,
  )
  match missing_order {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 41L)
      assert_eq(reason.contains("PrintingOrder"), true)
    }
    _ => fail("expected NChannel PrintingOrder requirement")
  }

  let mismatched = nchannel_attributes(
    @objects.PdfName::new(b"Spot"),
    @objects.PdfName::new(b"OtherSpot"),
    true,
  )
  let bad_colorant : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    device_n_object([@objects.PdfName::new(b"Spot")], Some(mismatched)),
    ColourDefaults::empty(),
    42L,
  )
  match bad_colorant {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 42L)
      assert_eq(reason.contains("Colorants"), true)
    }
    _ => fail("expected NChannel Colorants mismatch")
  }

  let none_attrs = nchannel_attributes(
    @objects.PdfName::new(b"Spot"),
    @objects.PdfName::new(b"Spot"),
    true,
  )
  let none_result : Result[ColourSpace, PdfGraphicsError] = try? parse_colour_space_object(
    device_n_object([@objects.PdfName::new(b"None")], Some(none_attrs)),
    ColourDefaults::empty(),
    43L,
  )
  match none_result {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 43L)
      assert_eq(reason.contains("None"), true)
    }
    _ => fail("expected NChannel None rejection")
  }
}

///|
fn number_array(values : Array[Double]) -> @objects.PdfObject {
  let output : Array[@objects.PdfObject] = []
  for value in values {
    output.push(@objects.PdfObject::Real(value))
  }
  @objects.PdfObject::Array(output)
}

///|
fn device_n_object(
  names : Array[@objects.PdfName],
  attributes : @objects.PdfDictionary?,
) -> @objects.PdfObject {
  let name_objects : Array[@objects.PdfObject] = []
  for name in names {
    name_objects.push(@objects.PdfObject::Name(name))
  }
  let values = [
    @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceN")),
    @objects.PdfObject::Array(name_objects),
    @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceCMYK")),
    @objects.PdfObject::Dictionary(Map::new()),
  ]
  if attributes is Some(dict) {
    values.push(@objects.PdfObject::Dictionary(dict))
  }
  @objects.PdfObject::Array(values)
}

///|
fn nchannel_attributes(
  dict_key : @objects.PdfName,
  separation_name : @objects.PdfName,
  include_printing_order : Bool,
) -> @objects.PdfDictionary {
  let colorants : @objects.PdfDictionary = Map::new()
  colorants[dict_key] = separation_object(separation_name)
  let solidities : @objects.PdfDictionary = Map::new()
  solidities[@objects.PdfName::new(b"Default")] = @objects.PdfObject::Real(0.0)
  solidities[@objects.PdfName::new(b"Spot")] = @objects.PdfObject::Real(1.0)
  let mixing_hints : @objects.PdfDictionary = Map::new()
  mixing_hints[@objects.PdfName::new(b"Solidities")] = @objects.PdfObject::Dictionary(
    solidities,
  )
  if include_printing_order {
    mixing_hints[@objects.PdfName::new(b"PrintingOrder")] = @objects.PdfObject::Array([
        @objects.PdfObject::Name(@objects.PdfName::new(b"Spot")),
        @objects.PdfObject::Name(@objects.PdfName::new(b"Unused")),
      ],
    )
  }
  let attrs : @objects.PdfDictionary = Map::new()
  attrs[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"NChannel"),
  )
  attrs[@objects.PdfName::new(b"Colorants")] = @objects.PdfObject::Dictionary(
    colorants,
  )
  attrs[@objects.PdfName::new(b"MixingHints")] = @objects.PdfObject::Dictionary(
    mixing_hints,
  )
  attrs
}

///|
fn separation_object(name : @objects.PdfName) -> @objects.PdfObject {
  @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"Separation")),
    @objects.PdfObject::Name(name),
    @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceCMYK")),
    @objects.PdfObject::Dictionary(Map::new()),
  ])
}

///|
fn icc_stream(n : Int64, signature : Bytes, size : Int) -> @objects.PdfStream {
  icc_stream_with_class(n, signature, size, b"mntr")
}

///|
fn icc_stream_with_class(
  n : Int64,
  signature : Bytes,
  size : Int,
  device_class : Bytes,
) -> @objects.PdfStream {
  let data : Array[Byte] = []
  for _ in 0..<size {
    data.push(b'\x00')
  }
  if size >= 20 {
    data[0] = ((size >> 24) & 0xff).to_byte()
    data[1] = ((size >> 16) & 0xff).to_byte()
    data[2] = ((size >> 8) & 0xff).to_byte()
    data[3] = (size & 0xff).to_byte()
    data[12] = device_class[0]
    data[13] = device_class[1]
    data[14] = device_class[2]
    data[15] = device_class[3]
    data[16] = signature[0]
    data[17] = signature[1]
    data[18] = signature[2]
    data[19] = signature[3]
  }
  if size >= 68 {
    data[36] = b'a'
    data[37] = b'c'
    data[38] = b's'
    data[39] = b'p'
    data[67] = b'\x01'
  }
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Integer(n)
  @objects.PdfStream::{ dict, data: Bytes::from_array(data) }
}

///|
test "colour space dispatch methods expose families decode and rgb conversion" {
  let cmyk = ColourSpace::Device(DeviceColourSpace::DeviceCMYK)
  assert_eq(cmyk.family() == ColourSpaceFamily::DeviceColourSpaceFamily, true)
  assert_eq(
    cmyk.to_device_family() == Some(DeviceColourSpace::DeviceCMYK),
    true,
  )
  assert_eq(cmyk.default_decode_array(), [
    0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0,
  ])
  assert_eq(cmyk.is_valid_device_default(DeviceColourSpace::DeviceCMYK), true)
  let rgb = cmyk.components_to_rgb([0.0, 1.0, 1.0, 0.0])
  assert_eq(rgb.red, 1.0)
  assert_eq(rgb.green, 0.0)
  assert_eq(rgb.blue, 0.0)
}

///|
test "CalGray and Lab parameter methods live beside their type definitions" {
  let cal_gray = CalGrayParams::{
    white_point: [0.95047, 1.0, 1.08883],
    black_point: [0.0, 0.0, 0.0],
    gamma: 2.0,
  }
  let xyz = cal_gray.to_xyz(0.5)
  assert_eq(xyz.x.is_close(0.2376175, absolute_tolerance=0.000001), true)
  assert_eq(xyz.y.is_close(0.25, absolute_tolerance=0.000001), true)
  assert_eq(xyz.z.is_close(0.2722075, absolute_tolerance=0.000001), true)

  let lab = LabParams::{
    white_point: [0.95047, 1.0, 1.08883],
    black_point: [0.0, 0.0, 0.0],
    range: [-10.0, 20.0, -30.0, 40.0],
  }
  let (a, b) = lab.clamp_ab(-20.0, 45.0)
  assert_eq(a, -10.0)
  assert_eq(b, 40.0)
}

///|
test "ICC profile header parser extracts component count and rendering intent" {
  let header = parse_icc_profile_header(test_icc_header_bytes(b"RGB ", 2L), 71L)
  assert_eq(header.component_count, 3)
  assert_eq(header.rendering_intent == RenderingIntent::Saturation, true)
  assert_eq(header.data_colour_space == @objects.PdfName::new(b"RGB "), true)
}

///|
fn test_icc_header_bytes(signature : Bytes, intent : Int64) -> Bytes {
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
  data[20] = b'X'
  data[21] = b'Y'
  data[22] = b'Z'
  data[23] = b' '
  data[36] = b'a'
  data[37] = b'c'
  data[38] = b's'
  data[39] = b'p'
  data[64] = ((intent >> 24) & 0xff).to_byte()
  data[65] = ((intent >> 16) & 0xff).to_byte()
  data[66] = ((intent >> 8) & 0xff).to_byte()
  data[67] = (intent & 0xff).to_byte()
  Bytes::from_array(data)
}
