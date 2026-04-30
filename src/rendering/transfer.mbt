///|
pub(all) enum TransferFunctionSet {
  SingleTransferFunction(TransferFunctionRef)
  ComponentTransferFunctions(Array[TransferFunctionRef])
} derive(Eq, Debug)

///|
pub(all) enum TransferSource {
  DeviceDefaultTransfer
  GraphicsStateTR
  GraphicsStateTR2
  HalftoneTransferOverride
} derive(Eq, Debug)

///|
pub(all) struct ResolvedTransferFunctions {
  source : TransferSource
  functions : TransferFunctionSet
} derive(Eq, Debug)

///|
pub(all) struct AdditiveNativeColour {
  colour_space : NativeColourSpace
  components : Array[Double]
} derive(Eq, Debug)

///|
pub fn AdditiveNativeColour::component_count(
  self : AdditiveNativeColour,
) -> Int {
  self.components.length()
}

///|
pub fn TransferFunctionSet::identity() -> TransferFunctionSet {
  SingleTransferFunction(TransferFunctionRef::IdentityTransfer)
}

///|
pub fn TransferFunctionSet::function_for_component(
  self : TransferFunctionSet,
  component : Int,
) -> TransferFunctionRef raise PdfRenderingError {
  match self {
    SingleTransferFunction(function) => function
    ComponentTransferFunctions(functions) =>
      if component < 0 || component >= functions.length() {
        raise PdfRenderingError::InvalidResource(
          "transfer component index out of bounds",
        )
      } else {
        functions[component]
      }
  }
}

///|
pub fn resolve_graphics_state_transfer(
  state : @graphics.GraphicsState,
  device : RasterDevice,
  halftone_override? : TransferFunctionRef = TransferFunctionRef::IdentityTransfer,
  offset? : Int64 = 0L,
) -> ResolvedTransferFunctions raise PdfRenderingError {
  if halftone_override != TransferFunctionRef::IdentityTransfer {
    ResolvedTransferFunctions::{
      source: HalftoneTransferOverride,
      functions: SingleTransferFunction(halftone_override),
    }
  } else {
    match state.deferred_entries.get(rendering_name(b"TR2")) {
      Some(object) =>
        ResolvedTransferFunctions::{
          source: GraphicsStateTR2,
          functions: transfer_set_from_object(object, offset),
        }
      None =>
        match state.deferred_entries.get(rendering_name(b"TR")) {
          Some(object) =>
            ResolvedTransferFunctions::{
              source: GraphicsStateTR,
              functions: transfer_set_from_object(object, offset),
            }
          None =>
            ResolvedTransferFunctions::{
              source: DeviceDefaultTransfer,
              functions: match device.default_transfer {
                Some(function) => SingleTransferFunction(function)
                None => TransferFunctionSet::identity()
              },
            }
        }
    }
  }
}

///|
pub fn apply_transfer_functions(
  colour : NativeColour,
  source_space : @graphics.ColourSpace,
  transfer : TransferFunctionSet,
) -> AdditiveNativeColour raise PdfRenderingError {
  if source_space ==
    @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceGray) &&
    colour.colour_space == NativeColourSpace::NativeCMYK {
    AdditiveNativeColour::{
      colour_space: colour.colour_space,
      components: [
        1.0,
        1.0,
        1.0,
        transfer
        .function_for_component(0)
        .apply_component(colour_component(1.0 - colour.components[3])),
      ],
    }
  } else {
    let additive : Array[Double] = []
    for index in 0..<colour.components.length() {
      additive.push(
        transfer
        .function_for_component(index)
        .apply_component(
          native_component_to_additive(
            colour.colour_space,
            colour.components[index],
          ),
        ),
      )
    }
    AdditiveNativeColour::{
      colour_space: colour.colour_space,
      components: additive,
    }
  }
}

///|
pub fn native_component_to_additive(
  colour_space : NativeColourSpace,
  component : Double,
) -> Double {
  match colour_space {
    NativeGray | NativeRGB => colour_component(component)
    NativeCMYK => colour_component(1.0 - component)
  }
}

///|
fn transfer_set_from_object(
  object : @objects.PdfObject,
  offset : Int64,
) -> TransferFunctionSet raise PdfRenderingError {
  match object {
    @objects.PdfObject::Array(values) => {
      let functions : Array[TransferFunctionRef] = []
      for value in values {
        functions.push(TransferFunctionRef::from_object(value, offset~))
      }
      ComponentTransferFunctions(functions)
    }
    _ =>
      SingleTransferFunction(TransferFunctionRef::from_object(object, offset~))
  }
}

///|
fn rendering_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}
