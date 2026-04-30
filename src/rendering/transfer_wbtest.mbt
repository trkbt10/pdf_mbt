///|
fn identity_name() -> @objects.PdfObject {
  @objects.PdfObject::Name(@objects.PdfName::new(b"Identity"))
}

///|
fn transfer_state_with(
  name : Bytes,
  object : @objects.PdfObject,
) -> @graphics.GraphicsState {
  let state = @graphics.GraphicsState::initial(
    @graphics.GraphicsInitialState::default(),
  )
  state.deferred_entries[@objects.PdfName::new(name)] = object
  state
}

///|
test "transfer resolver selects tr2 over tr" {
  let state = transfer_state_with(b"TR", identity_name())
  state.deferred_entries[@objects.PdfName::new(b"TR2")] = identity_name()
  let resolved = resolve_graphics_state_transfer(state, RasterDevice::rgb(1, 1))

  assert_eq(resolved.source == TransferSource::GraphicsStateTR2, true)
}

///|
test "transfer functions convert subtractive components to additive form" {
  let colour = NativeColour::{
    colour_space: NativeColourSpace::NativeCMYK,
    components: [0.1, 0.2, 0.3, 0.4],
  }
  let additive = apply_transfer_functions(
    colour,
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceCMYK),
    TransferFunctionSet::identity(),
  )

  assert_close(additive.components[0], 0.9)
  assert_close(additive.components[1], 0.8)
  assert_close(additive.components[2], 0.7)
  assert_close(additive.components[3], 0.6)
}

///|
test "device gray to cmyk transfer uses only gray transfer function" {
  let transfer = TransferFunctionSet::SingleTransferFunction(
    TransferFunctionRef::DirectTransfer(
      match type2_function(0.0, 0.5, 1.0) {
        DirectTransformFunction(source) => source
        _ => fail("expected direct function")
      },
    ),
  )
  let colour = NativeColour::{
    colour_space: NativeColourSpace::NativeCMYK,
    components: [0.0, 0.0, 0.0, 0.25],
  }
  let additive = apply_transfer_functions(
    colour,
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceGray),
    transfer,
  )

  assert_close(additive.components[0], 1.0)
  assert_close(additive.components[1], 1.0)
  assert_close(additive.components[2], 1.0)
  assert_close(additive.components[3], 0.375)
}
