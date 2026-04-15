///|
test "threshold array screens a single additive component" {
  let thresholds = ThresholdArray::{
    width: 2,
    height: 2,
    bits_per_sample: 8,
    values: [1, 128, 255, 64],
  }

  assert_eq(thresholds.screen_component(0.0, 0, 0), false)
  assert_eq(thresholds.screen_component(0.5, 1, 0), false)
  assert_eq(thresholds.screen_component(0.5, 1, 1), true)
  assert_eq(thresholds.screen_component(1.0, 2, 0), true)
}

///|
test "halftone screen generates threshold values from a spot function" {
  let screen = HalftoneScreen::new(120.0, 30.0, SpotFunction::CosineDot)
  let thresholds = screen.generate_threshold_array(3, 3)

  assert_eq(thresholds.width, 3)
  assert_eq(thresholds.height, 3)
  assert_eq(thresholds.bits_per_sample, 8)
  assert_eq(thresholds.values.length(), 9)
  thresholds.validate()
}

///|
test "spot function samples stay ordered for simple dot center" {
  let center = SpotFunction::SimpleDot.sample(0.0, 0.0)
  let corner = SpotFunction::SimpleDot.sample(1.0, 1.0)

  assert_eq(center > corner, true)
}

///|
fn halftone_test_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
test "type one halftone dictionary parses screen fields and generates thresholds" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[halftone_test_name(b"HalftoneType")] = @objects.PdfObject::Integer(1L)
  dict[halftone_test_name(b"Frequency")] = @objects.PdfObject::Real(120.0)
  dict[halftone_test_name(b"Angle")] = @objects.PdfObject::Real(30.0)
  dict[halftone_test_name(b"SpotFunction")] = @objects.PdfObject::Name(
    halftone_test_name(b"CosineDot"),
  )
  dict[halftone_test_name(b"AccurateScreens")] = @objects.PdfObject::Boolean(
    true,
  )

  match parse_halftone_object(@objects.PdfObject::Dictionary(dict)) {
    TypeOneHalftone(halftone) => {
      assert_eq(halftone.screen.frequency, 120.0)
      assert_eq(halftone.screen.angle, 30.0)
      assert_eq(halftone.screen.spot_function == SpotFunction::CosineDot, true)
      assert_eq(halftone.accurate_screens, true)
      assert_eq(halftone.generate_threshold_array(2, 2).values.length(), 4)
    }
    _ => fail("expected Type 1 halftone")
  }
}

///|
test "type sixteen halftone stream parses big endian threshold rectangles" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[halftone_test_name(b"HalftoneType")] = @objects.PdfObject::Integer(16L)
  dict[halftone_test_name(b"Width")] = @objects.PdfObject::Integer(2L)
  dict[halftone_test_name(b"Height")] = @objects.PdfObject::Integer(1L)
  dict[halftone_test_name(b"Width2")] = @objects.PdfObject::Integer(1L)
  dict[halftone_test_name(b"Height2")] = @objects.PdfObject::Integer(1L)
  let stream = @objects.PdfStream::{
    dict,
    data: Bytes::from_array([
      b'\x00', b'\x01', b'\x12', b'\x34', b'\xff', b'\xff',
    ]),
  }

  match parse_halftone_object(@objects.PdfObject::Stream(stream)) {
    TypeSixteenHalftone(halftone) => {
      assert_eq(halftone.primary_thresholds.width, 2)
      assert_eq(halftone.primary_thresholds.values[0], 1)
      assert_eq(halftone.primary_thresholds.values[1], 4660)
      match halftone.secondary_thresholds {
        Some(second) => assert_eq(second.values[0], 65535)
        None => fail("expected second rectangle")
      }
    }
    _ => fail("expected Type 16 halftone")
  }
}
