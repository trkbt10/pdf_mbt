///|
fn colour_value(components : Array[Double]) -> @graphics.ColourValue {
  @graphics.ColourValue::{ components, pattern: None }
}

///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_eq(actual.is_close(expected, absolute_tolerance=0.000001), true)
}

///|
test "raster device resolves native colour space and preserves native components" {
  let device = RasterDevice::cmyk(2, 2)
  assert_eq(device.native_space() == NativeColourSpace::NativeCMYK, true)
  let native = device.convert_colour(
    colour_value([0.1, 0.2, 0.3, 0.4]),
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceCMYK),
  )

  assert_eq(native.colour_space == NativeColourSpace::NativeCMYK, true)
  assert_eq(native.component_count(), 4)
  assert_close(native.components[0], 0.1)
  assert_close(native.components[1], 0.2)
  assert_close(native.components[2], 0.3)
  assert_close(native.components[3], 0.4)
}

///|
test "raster device converts device gray to native cmyk through classic formulas" {
  let native = RasterDevice::cmyk(2, 2).convert_colour(
    colour_value([0.25]),
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceGray),
  )

  assert_eq(native.colour_space == NativeColourSpace::NativeCMYK, true)
  assert_close(native.components[0], 0.0)
  assert_close(native.components[1], 0.0)
  assert_close(native.components[2], 0.0)
  assert_close(native.components[3], 0.75)
}

///|
test "raster device converts device rgb to native gray with ntsc weights" {
  let native = RasterDevice::gray(2, 2).convert_colour(
    colour_value([0.2, 0.5, 0.75]),
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceRGB),
  )

  assert_eq(native.colour_space == NativeColourSpace::NativeGray, true)
  assert_close(native.components[0], 0.4375)
}

///|
test "cie rendering intents map to explicit gamut mapping strategies" {
  let absolute = apply_cie_rendering_intent(
    @graphics.RenderingIntent::AbsoluteColorimetric,
  )
  assert_eq(
    absolute.strategy == GamutMappingStrategy::AbsoluteColorimetricGamutMapping,
    true,
  )
  assert_eq(absolute.preserve_source_white, true)

  let relative = apply_cie_rendering_intent(
    @graphics.RenderingIntent::RelativeColorimetric,
  )
  assert_eq(
    relative.strategy == GamutMappingStrategy::RelativeColorimetricGamutMapping,
    true,
  )
  assert_eq(relative.preserve_source_white, false)

  let saturation = apply_cie_rendering_intent(
    @graphics.RenderingIntent::Saturation,
  )
  assert_eq(
    saturation.strategy == GamutMappingStrategy::SaturationGamutMapping,
    true,
  )
  assert_eq(saturation.preserve_saturation, true)

  let perceptual = apply_cie_rendering_intent(
    @graphics.RenderingIntent::Perceptual,
  )
  assert_eq(
    perceptual.strategy == GamutMappingStrategy::PerceptualGamutMapping,
    true,
  )
  assert_eq(perceptual.perceptual_compression, true)
}
