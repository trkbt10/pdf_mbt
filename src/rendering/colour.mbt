///|
pub(all) struct NativeColour {
  colour_space : NativeColourSpace
  components : Array[Double]
} derive(Eq, Debug)

///|
pub(all) enum GamutMappingStrategy {
  AbsoluteColorimetricGamutMapping
  RelativeColorimetricGamutMapping
  SaturationGamutMapping
  PerceptualGamutMapping
} derive(Eq, Debug)

///|
pub(all) struct CieRenderingIntentApplication {
  intent : @graphics.RenderingIntent
  strategy : GamutMappingStrategy
  preserve_source_white : Bool
  preserve_saturation : Bool
  perceptual_compression : Bool
} derive(Eq, Debug)

///|
pub(all) struct DeviceRgbToCmykConversion {
  intermediate_cyan : Double
  intermediate_magenta : Double
  intermediate_yellow : Double
  nominal_black : Double
  undercolour_removed : Double
  generated_black : Double
  colour : @graphics.DeviceCmykColour
} derive(Eq, Debug)

///|
pub(all) enum DeviceConversionMode {
  NativeDeviceComponents
  ClassicDeviceFallback
  ProviderManagedCieIccTransform
} derive(Eq, Debug)

///|
pub(all) struct DeviceColourPolicy {
  mode : DeviceConversionMode
  requires_transform_provider : Bool
  preserves_separation_colourants : Bool
} derive(Eq, Debug)

///|
pub fn NativeColour::component_count(self : NativeColour) -> Int {
  self.components.length()
}

///|
pub fn apply_cie_rendering_intent(
  intent : @graphics.RenderingIntent,
) -> CieRenderingIntentApplication {
  let strategy = gamut_mapping_strategy_for_intent(intent)
  CieRenderingIntentApplication::{
    intent,
    strategy,
    preserve_source_white: strategy == AbsoluteColorimetricGamutMapping,
    preserve_saturation: strategy == SaturationGamutMapping,
    perceptual_compression: strategy == PerceptualGamutMapping,
  }
}

///|
pub fn gamut_mapping_strategy_for_intent(
  intent : @graphics.RenderingIntent,
) -> GamutMappingStrategy {
  match intent {
    AbsoluteColorimetric => AbsoluteColorimetricGamutMapping
    RelativeColorimetric => RelativeColorimetricGamutMapping
    Saturation => SaturationGamutMapping
    Perceptual => PerceptualGamutMapping
  }
}

///|
pub fn GamutMappingStrategy::map_component(
  self : GamutMappingStrategy,
  component : Double,
) -> Double {
  match self {
    AbsoluteColorimetricGamutMapping | RelativeColorimetricGamutMapping =>
      colour_component(component)
    SaturationGamutMapping => colour_component(component)
    PerceptualGamutMapping => colour_component(component)
  }
}

///|
pub fn convert_device_rgb_to_device_cmyk(
  rgb : @graphics.DeviceRgbColour,
  black_generation? : @graphics.ColourTransformFunction = @graphics.ColourTransformFunction::IdentityTransformFunction,
  undercolour_removal? : @graphics.ColourTransformFunction = @graphics.ColourTransformFunction::IdentityTransformFunction,
  offset? : Int64 = 0L,
) -> DeviceRgbToCmykConversion raise PdfRenderingError {
  let c = 1.0 - colour_component(rgb.red)
  let m = 1.0 - colour_component(rgb.green)
  let y = 1.0 - colour_component(rgb.blue)
  let k = @graphics.min3(c, m, y)
  let ucr = try undercolour_removal.apply_scalar(k, offset~) catch {
    _ =>
      raise PdfRenderingError::ProviderFailure(
        "undercolour removal", "UCR(k) could not be evaluated",
      )
  } noraise {
    value => value
  }
  let bg = try black_generation.apply_scalar(k, offset~) catch {
    _ =>
      raise PdfRenderingError::ProviderFailure(
        "black generation", "BG(k) could not be evaluated",
      )
  } noraise {
    value => value
  }
  let colour = try
    @graphics.device_rgb_to_cmyk(
      rgb,
      black_generation~,
      undercolour_removal~,
      offset~,
    )
  catch {
    _ =>
      raise PdfRenderingError::ProviderFailure(
        "DeviceRGB to DeviceCMYK", "RGB to CMYK conversion could not be evaluated",
      )
  } noraise {
    value => value
  }
  DeviceRgbToCmykConversion::{
    intermediate_cyan: c,
    intermediate_magenta: m,
    intermediate_yellow: y,
    nominal_black: k,
    undercolour_removed: ucr,
    generated_black: bg,
    colour,
  }
}

///|
pub fn RasterDevice::native_space(self : RasterDevice) -> NativeColourSpace {
  self.native_colour_space
}

///|
pub fn RasterDevice::convert_colour(
  self : RasterDevice,
  colour : @graphics.ColourValue,
  source_space : @graphics.ColourSpace,
  offset? : Int64 = 0L,
) -> NativeColour raise PdfRenderingError {
  self.validate()
  if colour.pattern is Some(_) {
    raise PdfRenderingError::UnsupportedCapability(
      "Pattern colour values require pattern painting before native conversion",
    )
  }
  match source_space {
    @graphics.ColourSpace::Device(device_space) =>
      convert_device_colour_to_native(
        self.native_colour_space,
        device_space,
        colour.components,
        offset,
      )
    _ => {
      let rgb = try
        source_space.components_to_device_rgb(colour.components, offset~)
      catch {
        _ =>
          raise PdfRenderingError::ProviderFailure(
            "colour conversion", "source colour space could not be converted to DeviceRGB",
          )
      } noraise {
        value => value
      }
      rgb_to_native_colour(self.native_colour_space, rgb)
    }
  }
}

///|
pub fn choose_device_colour_policy(
  device : RasterDevice,
  source_space : @graphics.ColourSpace,
) -> DeviceColourPolicy {
  match source_space {
    @graphics.ColourSpace::Device(source) =>
      if source == device.native_colour_space.to_device_colour_space() {
        DeviceColourPolicy::{
          mode: NativeDeviceComponents,
          requires_transform_provider: false,
          preserves_separation_colourants: false,
        }
      } else {
        DeviceColourPolicy::{
          mode: ClassicDeviceFallback,
          requires_transform_provider: false,
          preserves_separation_colourants: false,
        }
      }
    @graphics.ColourSpace::Separation(_) | @graphics.ColourSpace::DeviceN(_) =>
      DeviceColourPolicy::{
        mode: ProviderManagedCieIccTransform,
        requires_transform_provider: true,
        preserves_separation_colourants: true,
      }
    _ =>
      DeviceColourPolicy::{
        mode: ProviderManagedCieIccTransform,
        requires_transform_provider: true,
        preserves_separation_colourants: false,
      }
  }
}

///|
pub fn render_colour_to_native(
  colour_state : @graphics.ColourState,
  device : RasterDevice,
  providers : RenderingProviders,
  offset? : Int64 = 0L,
) -> NativeColour raise PdfRenderingError {
  let policy = choose_device_colour_policy(device, colour_state.colour_space)
  if policy.requires_transform_provider && !providers.colour_transform {
    raise PdfRenderingError::ProviderFailure(
      "CIE/ICC colour transform",
      "missing colour transform provider at offset " + offset.to_string(),
    )
  }
  device.convert_colour(
    colour_state.colour_value,
    colour_state.colour_space,
    offset~,
  )
}

///|
pub fn NativeColourSpace::to_device_colour_space(
  self : NativeColourSpace,
) -> @graphics.DeviceColourSpace {
  match self {
    NativeGray => @graphics.DeviceColourSpace::DeviceGray
    NativeRGB => @graphics.DeviceColourSpace::DeviceRGB
    NativeCMYK => @graphics.DeviceColourSpace::DeviceCMYK
  }
}

///|
pub fn NativeColour::as_graphics_colour_value(
  self : NativeColour,
) -> @graphics.ColourValue {
  @graphics.ColourValue::{ components: self.components.copy(), pattern: None }
}

///|
fn convert_device_colour_to_native(
  native : NativeColourSpace,
  source : @graphics.DeviceColourSpace,
  components : Array[Double],
  offset : Int64,
) -> NativeColour raise PdfRenderingError {
  validate_component_count(source_component_count(source), components, offset)
  match (native, source) {
    (NativeGray, @graphics.DeviceColourSpace::DeviceGray) =>
      NativeColour::{
        colour_space: native,
        components: [colour_component(components[0])],
      }
    (NativeRGB, @graphics.DeviceColourSpace::DeviceRGB) =>
      NativeColour::{
        colour_space: native,
        components: [
          colour_component(components[0]),
          colour_component(components[1]),
          colour_component(components[2]),
        ],
      }
    (NativeCMYK, @graphics.DeviceColourSpace::DeviceCMYK) =>
      NativeColour::{
        colour_space: native,
        components: [
          colour_component(components[0]),
          colour_component(components[1]),
          colour_component(components[2]),
          colour_component(components[3]),
        ],
      }
    _ => {
      let rgb = try
        @graphics.ColourSpace::Device(source).components_to_device_rgb(
          components,
          offset~,
        )
      catch {
        _ =>
          raise PdfRenderingError::ProviderFailure(
            "colour conversion", "device colour space could not be converted to DeviceRGB",
          )
      } noraise {
        value => value
      }
      rgb_to_native_colour(native, rgb)
    }
  }
}

///|
fn rgb_to_native_colour(
  native : NativeColourSpace,
  rgb : @graphics.DeviceRgbColour,
) -> NativeColour raise PdfRenderingError {
  match native {
    NativeGray =>
      NativeColour::{
        colour_space: native,
        components: [device_rgb_to_gray(rgb)],
      }
    NativeRGB =>
      NativeColour::{
        colour_space: native,
        components: [
          colour_component(rgb.red),
          colour_component(rgb.green),
          colour_component(rgb.blue),
        ],
      }
    NativeCMYK => {
      let cmyk = try @graphics.device_rgb_to_cmyk(rgb) catch {
        _ =>
          raise PdfRenderingError::ProviderFailure(
            "colour conversion", "DeviceRGB could not be converted to DeviceCMYK",
          )
      } noraise {
        value => value
      }
      NativeColour::{
        colour_space: native,
        components: [cmyk.cyan, cmyk.magenta, cmyk.yellow, cmyk.black],
      }
    }
  }
}

///|
fn source_component_count(source : @graphics.DeviceColourSpace) -> Int {
  match source {
    DeviceGray => 1
    DeviceRGB => 3
    DeviceCMYK => 4
  }
}

///|
fn validate_component_count(
  expected : Int,
  components : Array[Double],
  offset : Int64,
) -> Unit raise PdfRenderingError {
  if components.length() != expected {
    raise PdfRenderingError::InvalidResource(
      "colour component count mismatch at offset " + offset.to_string(),
    )
  }
}

///|
fn device_rgb_to_gray(rgb : @graphics.DeviceRgbColour) -> Double {
  colour_component(
    0.3 * colour_component(rgb.red) +
    0.59 * colour_component(rgb.green) +
    0.11 * colour_component(rgb.blue),
  )
}

///|
fn colour_component(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

