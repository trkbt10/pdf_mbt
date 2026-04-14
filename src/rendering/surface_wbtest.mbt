///|
test "raster surface allocation follows device dimensions and components" {
  let device = RasterDevice::rgb(4, 3)
  let surface = RasterSurface::allocate(device)

  assert_eq(surface.width, 4)
  assert_eq(surface.height, 3)
  assert_eq(surface.pixel_format.component_count, 3)
  assert_eq(surface.pixel_format.bytes_per_component, 1)
  assert_eq(surface.component_buffers.length(), 3)
  assert_eq(surface.component_buffer_length(), 12)
}

///|
test "surface pixel addressing is stable and half open at bounds" {
  let surface = RasterSurface::allocate(RasterDevice::rgb(4, 3))
  let address = surface.pixel_address(2, 1, 1, 0)

  assert_eq(address.x, 2)
  assert_eq(address.y, 1)
  assert_eq(address.component, 1)
  assert_eq(address.buffer_offset, 6)

  let out_of_bounds : Result[PixelAddress, PdfRenderingError] = try? surface.pixel_address(
    4, 1, 0, 0,
  )
  match out_of_bounds {
    Err(PixelOutOfBounds(x, y)) => {
      assert_eq(x, 4)
      assert_eq(y, 1)
    }
    _ => fail("expected half-open x bound to reject x == width")
  }
}

///|
test "surface component byte writes stay in the addressed component plane" {
  let surface = RasterSurface::allocate(RasterDevice::rgb(2, 2))
  surface.write_component_byte(1, 1, 2, 0, b'\x7f')

  assert_eq(surface.read_component_byte(1, 1, 2, 0), b'\x7f')
  assert_eq(surface.read_component_byte(1, 1, 0, 0), b'\x00')
  assert_eq(surface.read_component_byte(1, 0, 2, 0), b'\x00')
}

///|
test "sixteen bit surfaces reserve two bytes per component sample" {
  let surface = RasterSurface::allocate(
    RasterDevice::gray(2, 1).with_bits_per_component(16),
  )
  assert_eq(surface.pixel_format.bytes_per_component, 2)
  assert_eq(surface.component_buffer_length(), 4)

  surface.write_component_byte(1, 0, 0, 1, b'\xaa')
  assert_eq(surface.pixel_address(1, 0, 0, 1).buffer_offset, 3)
  assert_eq(surface.read_component_byte(1, 0, 0, 1), b'\xaa')
}
