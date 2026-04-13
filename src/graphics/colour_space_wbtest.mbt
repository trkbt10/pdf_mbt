///|
test "device and calibrated colour spaces expose components ranges and initial values" {
  let cmyk = parse_colour_space_object(
    @objects.PdfObject::Name(@objects.PdfName::new(b"DeviceCMYK")),
    ColourDefaults::empty(),
    1L,
  )
  assert_eq(cmyk.component_count(), 4)
  assert_eq(cmyk.initial_value().components, [1.0, 1.0, 1.0, 1.0])

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
fn icc_stream(n : Int64, signature : Bytes, size : Int) -> @objects.PdfStream {
  let data : Array[Byte] = []
  for _ in 0..<size {
    data.push(b'\x00')
  }
  if size >= 20 {
    data[0] = ((size >> 24) & 0xff).to_byte()
    data[1] = ((size >> 16) & 0xff).to_byte()
    data[2] = ((size >> 8) & 0xff).to_byte()
    data[3] = (size & 0xff).to_byte()
    data[16] = signature[0]
    data[17] = signature[1]
    data[18] = signature[2]
    data[19] = signature[3]
  }
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Integer(n)
  @objects.PdfStream::{ dict, data: Bytes::from_array(data) }
}
