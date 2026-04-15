///|
fn colour_value(components : Array[Double]) -> @graphics.ColourValue {
  @graphics.ColourValue::{ components, pattern: None }
}

///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_eq(actual.is_close(expected, absolute_tolerance=0.000001), true)
}

///|
fn pdf_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn pdf_real(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn type2_function(
  c0 : Double,
  c1 : Double,
  exponent : Double,
) -> @graphics.ColourTransformFunction {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"FunctionType")] = @objects.PdfObject::Integer(2L)
  dict[pdf_name(b"Domain")] = @objects.PdfObject::Array([
    pdf_real(0.0),
    pdf_real(1.0),
  ])
  dict[pdf_name(b"C0")] = @objects.PdfObject::Array([pdf_real(c0)])
  dict[pdf_name(b"C1")] = @objects.PdfObject::Array([pdf_real(c1)])
  dict[pdf_name(b"N")] = pdf_real(exponent)
  @graphics.ColourTransformFunction::DirectTransformFunction(
    @objects.PdfObject::Dictionary(dict),
  )
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

///|
test "device rgb to cmyk conversion records black generation and undercolour removal" {
  let conversion = convert_device_rgb_to_device_cmyk(
    @graphics.DeviceRgbColour::{ red: 0.2, green: 0.5, blue: 0.75 },
    black_generation=type2_function(0.0, 0.5, 1.0),
    undercolour_removal=type2_function(0.0, 0.1, 1.0),
  )

  assert_close(conversion.intermediate_cyan, 0.8)
  assert_close(conversion.intermediate_magenta, 0.5)
  assert_close(conversion.intermediate_yellow, 0.25)
  assert_close(conversion.nominal_black, 0.25)
  assert_close(conversion.undercolour_removed, 0.025)
  assert_close(conversion.generated_black, 0.125)
  assert_close(conversion.colour.cyan, 0.775)
  assert_close(conversion.colour.magenta, 0.475)
  assert_close(conversion.colour.yellow, 0.225)
  assert_close(conversion.colour.black, 0.125)
}
