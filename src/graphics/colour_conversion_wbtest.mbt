///|
fn colour_fn_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn colour_fn_number(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
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
  let bg_dict : @objects.PdfDictionary = Map::new()
  bg_dict[colour_fn_name(b"FunctionType")] = @objects.PdfObject::Integer(2L)
  bg_dict[colour_fn_name(b"Domain")] = @objects.PdfObject::Array([
    colour_fn_number(0.0),
    colour_fn_number(1.0),
  ])
  bg_dict[colour_fn_name(b"C0")] = @objects.PdfObject::Array([
    colour_fn_number(0.0),
  ])
  bg_dict[colour_fn_name(b"C1")] = @objects.PdfObject::Array([
    colour_fn_number(0.5),
  ])
  bg_dict[colour_fn_name(b"N")] = colour_fn_number(1.0)

  let ucr_dict : @objects.PdfDictionary = Map::new()
  ucr_dict[colour_fn_name(b"FunctionType")] = @objects.PdfObject::Integer(2L)
  ucr_dict[colour_fn_name(b"Domain")] = @objects.PdfObject::Array([
    colour_fn_number(0.0),
    colour_fn_number(1.0),
  ])
  ucr_dict[colour_fn_name(b"C0")] = @objects.PdfObject::Array([
    colour_fn_number(0.0),
  ])
  ucr_dict[colour_fn_name(b"C1")] = @objects.PdfObject::Array([
    colour_fn_number(0.1),
  ])
  ucr_dict[colour_fn_name(b"N")] = colour_fn_number(1.0)

  let cmyk = device_rgb_to_cmyk(
    DeviceRgbColour::{ red: 0.2, green: 0.5, blue: 0.75 },
    black_generation=DirectTransformFunction(
      @objects.PdfObject::Dictionary(bg_dict),
    ),
    undercolour_removal=DirectTransformFunction(
      @objects.PdfObject::Dictionary(ucr_dict),
    ),
  )
  assert_close(cmyk.cyan, 0.775)
  assert_close(cmyk.magenta, 0.475)
  assert_close(cmyk.yellow, 0.225)
  assert_close(cmyk.black, 0.125)
}
