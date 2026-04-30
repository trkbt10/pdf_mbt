///|
test "continuous tone halftone pass through writes component bytes" {
  let device = RasterDevice::gray(2, 2)
  let mark = apply_halftone(
    AdditiveNativeColour::{
      colour_space: NativeColourSpace::NativeGray,
      components: [0.5],
    },
    DevicePixelPoint::{ x: 0, y: 0 },
    None,
    device,
  )
  assert_eq(mark.components[0].to_int(), 128)
}

///|
test "threshold halftone uses device space coordinates" {
  let device = RasterDevice::gray(2, 2)
  let halftoned = RasterDevice::{
    width: device.width,
    height: device.height,
    resolution_x: device.resolution_x,
    resolution_y: device.resolution_y,
    native_colour_space: device.native_colour_space,
    process_colourants: device.process_colourants,
    spot_colourants: device.spot_colourants,
    continuous_tone: false,
    bits_per_component: device.bits_per_component,
    output_profile: device.output_profile,
    default_transfer: device.default_transfer,
    default_halftone: device.default_halftone,
    limits: device.limits,
  }
  let threshold = ThresholdArray::{
    width: 1,
    height: 1,
    bits_per_sample: 8,
    values: [200],
  }
  let mark = apply_halftone(
    AdditiveNativeColour::{
      colour_space: NativeColourSpace::NativeGray,
      components: [0.5],
    },
    DevicePixelPoint::{ x: 9, y: 9 },
    Some(threshold),
    halftoned,
  )
  assert_eq(mark.components[0].to_int(), 0)
}

///|
test "fill device rect treats zero width and height as one visible pixel line" {
  let surface = RasterSurface::allocate(RasterDevice::gray(3, 3))
  let mark = DevicePixelMark::{ components: [b'\xff'] }
  let painted = fill_device_rect(surface, 1, 1, 1, 1, mark)

  assert_eq(painted, 1)
  assert_eq(surface.read_component_byte(1, 1, 0, 0), b'\xff')
}

///|
test "image centre sampling skips unused high resolution samples" {
  let sample = image_source_sample_for_device_pixel(10, 10, 0, 0, 2, 2)

  assert_eq(sample.x, 2)
  assert_eq(sample.y, 2)
}
