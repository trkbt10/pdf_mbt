///|
test "separation target allocates process and spot planes" {
  let spot = @objects.PdfName::new(b"SpotBlue")
  let simulated = RasterDevice::cmyk(2, 2).with_spot_colourants([spot])
  let target = SeparationTarget::allocate(simulated, RasterDevice::rgb(2, 2))

  assert_eq(target.plane_count(), 5)
  match target.plane_index(spot) {
    Some(index) => assert_eq(index, 4)
    None => fail("expected spot plane")
  }
}

///|
test "separation simulation multiplies plane contributions into actual device" {
  let cyan = @objects.PdfName::new(b"Cyan")
  let target = SeparationTarget::allocate(
    RasterDevice::gray(1, 1).with_process_colourants([cyan]),
    RasterDevice::rgb(1, 1),
  )
  target.paint_colourant(cyan, 0, 0, 0.25)
  let simulated = simulate_separations(target)

  assert_eq(
    simulated.pixel_format.native_colour_space == NativeColourSpace::NativeRGB,
    true,
  )
  assert_eq(simulated.read_component_byte(0, 0, 0, 0).to_int(), 191)
  assert_eq(simulated.read_component_byte(0, 0, 1, 0).to_int(), 191)
  assert_eq(simulated.read_component_byte(0, 0, 2, 0).to_int(), 191)
}
