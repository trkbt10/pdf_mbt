///|
/// Section 8.6.4.1 General, "Device colour spaces": DeviceRGB represents
/// additive RGB colour, where output devices form colours by adding red,
/// green, and blue light sources together. Device colour spaces enable a page
/// description to specify colour values directly related to output-device
/// colourants such as display phosphor intensities; Figure 22 covers additive
/// and subtractive colour, and Table 61 lists DeviceRGB with DeviceGray and
/// DeviceCMYK.
pub(all) struct DeviceRgbColour {
  red : Double
  green : Double
  blue : Double
} derive(Eq, Debug)

///|
/// Section 8.6.4.1 General, "Device colour spaces": DeviceCMYK represents
/// subtractive CMYK colour, where output devices form colours by subtracting
/// light with cyan, magenta, yellow, and black inks. Device colour values map
/// directly, or by simple conversions, to output-device colourants; Figure 22
/// covers additive and subtractive colour, and Table 61 lists DeviceCMYK with
/// DeviceGray and DeviceRGB. The device colour spaces enable a page description
/// to control colours precisely for a particular output device, though results
/// might not be consistent from one device to another.
pub(all) struct DeviceCmykColour {
  cyan : Double
  magenta : Double
  yellow : Double
  black : Double
} derive(Eq, Debug)

///|
/// Section 8.6.5.1 General, "CIE-based colour spaces": CIE-based CalGray,
/// CalRGB, Lab, and ICCBased spaces specify colours independently of any
/// particular output device and relate their components to the tristimulus
/// values X, Y, and Z of the CIE 1931 XYZ space. Figure 23 shows variation from
/// uncalibrated colour, Figure 24 shows component transformations in a
/// CIE-based ABC colour space, and Tables 62 through 68 define calibrated
/// colour dictionaries, ICCBased profiles, and component ranges. The goal is
/// for the same colour specification to produce consistent results on
/// different output devices within each device gamut; CIE-based spaces are
/// defined as [name dictionary], and setting one initializes components to 0.0
/// or the nearest valid value.
pub(all) struct CieXyzColour {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
/// Direct scalar function source used by colour conversion policies such as
/// black generation, undercolour removal, transfer functions, and tint
/// transforms. The Identity name is handled without parsing a function object;
/// indirect functions are preserved as unresolved because graphics must not
/// load reader-owned objects.
pub(all) enum ColourTransformFunction {
  IdentityTransformFunction
  DirectTransformFunction(@functions.FunctionSource)
  UnresolvedTransformFunction(@objects.ObjectId)
} derive(Eq, Debug)

///|
/// Transfer function bundle for a colour value. A single function applies to
/// every component; otherwise the function count must match the component count.
pub(all) enum ColourTransfer {
  SingleTransfer(ColourTransformFunction)
  ComponentTransfers(Array[ColourTransformFunction])
} derive(Eq, Debug)

///|
pub fn device_gray_to_rgb(gray : Double) -> DeviceRgbColour {
  let value = colour_component(gray)
  DeviceRgbColour::{ red: value, green: value, blue: value }
}

///|
pub fn device_rgb_to_cmyk(
  rgb : DeviceRgbColour,
  black_generation? : ColourTransformFunction = IdentityTransformFunction,
  undercolour_removal? : ColourTransformFunction = IdentityTransformFunction,
  offset? : Int64 = 0L,
) -> DeviceCmykColour raise PdfGraphicsError {
  let c = 1.0 - colour_component(rgb.red)
  let m = 1.0 - colour_component(rgb.green)
  let y = 1.0 - colour_component(rgb.blue)
  let k = min3(c, m, y)
  let ucr = undercolour_removal.apply_scalar(k, offset~)
  let bg = black_generation.apply_scalar(k, offset~)
  DeviceCmykColour::{
    cyan: colour_component(c - ucr),
    magenta: colour_component(m - ucr),
    yellow: colour_component(y - ucr),
    black: colour_component(bg),
  }
}

///|
pub fn device_cmyk_to_rgb(cmyk : DeviceCmykColour) -> DeviceRgbColour {
  let c = colour_component(cmyk.cyan)
  let m = colour_component(cmyk.magenta)
  let y = colour_component(cmyk.yellow)
  let k = colour_component(cmyk.black)
  DeviceRgbColour::{
    red: 1.0 - colour_component(c + k),
    green: 1.0 - colour_component(m + k),
    blue: 1.0 - colour_component(y + k),
  }
}

///|
pub fn CalGrayParams::to_srgb(
  self : CalGrayParams,
  gray : Double,
) -> DeviceRgbColour {
  cie_xyz_d65_to_srgb(adapt_xyz_to_d65(self.to_xyz(gray), self.white_point))
}

///|
pub fn CalRGBParams::to_xyz(
  self : CalRGBParams,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> CieXyzColour raise PdfGraphicsError {
  if components.length() != 3 {
    raise PdfGraphicsError::BadOperand(
      offset, "CalRGB conversion requires three components",
    )
  }
  let a = @math.pow(colour_component(components[0]), self.gamma[0])
  let b = @math.pow(colour_component(components[1]), self.gamma[1])
  let c = @math.pow(colour_component(components[2]), self.gamma[2])
  CieXyzColour::{
    x: self.matrix[0] * a + self.matrix[3] * b + self.matrix[6] * c,
    y: self.matrix[1] * a + self.matrix[4] * b + self.matrix[7] * c,
    z: self.matrix[2] * a + self.matrix[5] * b + self.matrix[8] * c,
  }
}

///|
pub fn CalRGBParams::to_srgb(
  self : CalRGBParams,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  cie_xyz_d65_to_srgb(
    adapt_xyz_to_d65(self.to_xyz(components, offset~), self.white_point),
  )
}

///|
pub fn LabParams::to_xyz(
  self : LabParams,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> CieXyzColour raise PdfGraphicsError {
  if components.length() != 3 {
    raise PdfGraphicsError::BadOperand(
      offset, "Lab conversion requires three components",
    )
  }
  let l_star = clamp_double(components[0], 0.0, 100.0)
  let (a_star, b_star) = self.clamp_ab(components[1], components[2])
  let m = (l_star + 16.0) / 116.0
  let l = m + a_star / 500.0
  let n = m - b_star / 200.0
  CieXyzColour::{
    x: self.white_point[0] * lab_g(l),
    y: self.white_point[1] * lab_g(m),
    z: self.white_point[2] * lab_g(n),
  }
}

///|
pub fn LabParams::to_srgb(
  self : LabParams,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  cie_xyz_d65_to_srgb(
    adapt_xyz_to_d65(self.to_xyz(components, offset~), self.white_point),
  )
}

///|
pub fn lab_d50_to_srgb(
  lightness : Double,
  a : Double,
  b : Double,
) -> DeviceRgbColour {
  if a == 0.0 && b == 0.0 {
    if lightness <= 0.0 {
      return device_gray_to_rgb(0.0)
    }
    if lightness >= 100.0 {
      return device_gray_to_rgb(1.0)
    }
  }
  let params = LabParams::{
    white_point: d50_white_point(),
    black_point: [0.0, 0.0, 0.0],
    range: [-128.0, 127.0, -128.0, 127.0],
  }
  try params.to_srgb([lightness, a, b]) catch {
    _ => device_gray_to_rgb(0.0)
  } noraise {
    rgb => rgb
  }
}

///|
pub fn cie_xyz_d65_to_srgb(xyz : CieXyzColour) -> DeviceRgbColour {
  let red_linear = 3.2406 * xyz.x - 1.5372 * xyz.y - 0.4986 * xyz.z
  let green_linear = -0.9689 * xyz.x + 1.8758 * xyz.y + 0.0415 * xyz.z
  let blue_linear = 0.0557 * xyz.x - 0.2040 * xyz.y + 1.0570 * xyz.z
  DeviceRgbColour::{
    red: srgb_encode(red_linear),
    green: srgb_encode(green_linear),
    blue: srgb_encode(blue_linear),
  }
}

///|
/// Section 8.6.6.1 General, "Special colour spaces": Indexed is a special
/// colour space family, along with Pattern, Separation, and DeviceN, that adds
/// colour mapping to an underlying base colour space. Section 8.6.6.3 Indexed
/// colour spaces uses this lookup to map an index through a colour table into
/// a colour value in the base colour space, reducing sampled image data while
/// still allowing SC, SCN, sc, and scn colour selection.
pub fn IndexedParams::lookup_colour_value(
  self : IndexedParams,
  index : Double,
  offset? : Int64 = 0L,
) -> ColourValue raise PdfGraphicsError {
  let selected = clamp_double(
    @math.floor(index + 0.5),
    0.0,
    self.hival.to_double(),
  ).to_int()
  let lookup = colour_indexed_lookup_bytes(self.lookup, offset)
  let component_count = self.base.component_count()
  let start = selected * component_count
  if start + component_count > lookup.length() {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Indexed lookup table is shorter than selected colour index",
    )
  }
  let ranges = self.base.component_ranges()
  let components : Array[Double] = []
  for component in 0..<component_count {
    let range = ranges[component]
    let byte_value = lookup[start + component].to_int().to_double()
    components.push(range.min + byte_value / 255.0 * (range.max - range.min))
  }
  numeric_colour_value(self.base, components, offset)
}

///|
pub fn IndexedParams::lookup_device_rgb(
  self : IndexedParams,
  index : Double,
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  let value = self.lookup_colour_value(index, offset~)
  self.base.components_to_device_rgb(value.components, offset~)
}

///|
/// Section 8.6.6.4 Separation colour spaces: applies the tintTransform
/// function for a Separation colour space when the colourant named by
/// [/Separation name alternateSpace tintTransform] is unavailable on the output
/// device. The input tint is a single subtractive component in the range
/// 0.0 to 1.0, where 0.0 is the minimum amount of colourant and 1.0 is the
/// maximum; the function returns colour component values in the alternateSpace.
pub fn SeparationParams::alternate_colour_value(
  self : SeparationParams,
  tint : Double,
  offset? : Int64 = 0L,
) -> ColourValue raise PdfGraphicsError {
  let outputs = self.tint_transform.apply(
    [colour_component(tint)],
    self.alternate.component_count(),
    offset~,
  )
  numeric_colour_value(self.alternate, outputs, offset)
}

///|
pub fn DeviceNParams::alternate_colour_value(
  self : DeviceNParams,
  tints : Array[Double],
  offset? : Int64 = 0L,
) -> ColourValue raise PdfGraphicsError {
  if tints.length() != self.colorants.length() {
    raise PdfGraphicsError::BadOperand(
      offset, "DeviceN tint value count must match colorant count",
    )
  }
  let normalized : Array[Double] = []
  for tint in tints {
    normalized.push(colour_component(tint))
  }
  let outputs = self.tint_transform.apply(
    normalized,
    self.alternate.component_count(),
    offset~,
  )
  numeric_colour_value(self.alternate, outputs, offset)
}

///|
/// Section 8.6.5.8 Rendering intents: converts stored colour-space components
/// for preview while leaving rendering intent policy to the graphics state and
/// downstream renderer. PDF rendering intents are identified by ri, RI, or
/// image Intent; Table 69 lists AbsoluteColorimetric, RelativeColorimetric,
/// Saturation, and Perceptual, with unrecognised names defaulting to
/// RelativeColorimetric. This conversion entry point does not make output
/// device gamut compromises or override renderer-specific colour priorities.
pub fn ColourSpace::components_to_device_rgb(
  self : ColourSpace,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  let value = numeric_colour_value(self, components, offset)
  match self {
    Device(DeviceGray) => device_gray_to_rgb(value.components[0])
    Device(DeviceRGB) =>
      DeviceRgbColour::{
        red: value.components[0],
        green: value.components[1],
        blue: value.components[2],
      }
    Device(DeviceCMYK) =>
      device_cmyk_to_rgb(DeviceCmykColour::{
        cyan: value.components[0],
        magenta: value.components[1],
        yellow: value.components[2],
        black: value.components[3],
      })
    CalGray(params) => params.to_srgb(value.components[0])
    CalRGB(params) => params.to_srgb(value.components, offset~)
    Lab(params) => params.to_srgb(value.components, offset~)
    Indexed(params) => params.lookup_device_rgb(value.components[0], offset~)
    Separation(params) => {
      let alternate = params.alternate_colour_value(
        value.components[0],
        offset~,
      )
      params.alternate.components_to_device_rgb(alternate.components, offset~)
    }
    DeviceN(params) => {
      let alternate = params.alternate_colour_value(value.components, offset~)
      params.alternate.components_to_device_rgb(alternate.components, offset~)
    }
    ICCBased(params) =>
      icc_based_to_device_rgb(params, value.components, offset)
    Pattern(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Pattern colour space cannot be converted without pattern painting",
      )
  }
}

///|
pub fn apply_transfer_function(
  component : Double,
  transfer : ColourTransformFunction,
  offset? : Int64 = 0L,
) -> Double raise PdfGraphicsError {
  colour_component(transfer.apply_scalar(colour_component(component), offset~))
}

///|
pub fn apply_transfer_functions(
  components : Array[Double],
  transfer : ColourTransfer,
  offset? : Int64 = 0L,
) -> Array[Double] raise PdfGraphicsError {
  let outputs : Array[Double] = []
  match transfer {
    SingleTransfer(function) =>
      for component in components {
        outputs.push(apply_transfer_function(component, function, offset~))
      }
    ComponentTransfers(functions) => {
      if functions.length() != components.length() {
        raise PdfGraphicsError::BadOperand(
          offset, "transfer function count must match colour component count",
        )
      }
      for index in 0..<components.length() {
        outputs.push(
          apply_transfer_function(components[index], functions[index], offset~),
        )
      }
    }
  }
  outputs
}

///|
pub fn ColourState::selected_pattern(self : ColourState) -> @objects.PdfName? {
  self.colour_value.pattern
}

///|
fn icc_based_to_device_rgb(
  params : IccBasedParams,
  components : Array[Double],
  offset : Int64,
) -> DeviceRgbColour raise PdfGraphicsError {
  if components.length() != params.component_count() {
    raise PdfGraphicsError::BadOperand(
      offset, "ICCBased colour value component count mismatch",
    )
  }
  match params.alternate {
    Some(alternate) => alternate.components_to_device_rgb(components, offset~)
    None =>
      match params.detected_component_count() {
        1 => device_gray_to_rgb(components[0])
        3 =>
          DeviceRgbColour::{
            red: colour_component(components[0]),
            green: colour_component(components[1]),
            blue: colour_component(components[2]),
          }
        4 =>
          device_cmyk_to_rgb(DeviceCmykColour::{
            cyan: components[0],
            magenta: components[1],
            yellow: components[2],
            black: components[3],
          })
        _ =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "ICCBased colour component count cannot be converted to DeviceRGB",
          )
      }
  }
}

///|
fn colour_indexed_lookup_bytes(
  object : @objects.PdfObject,
  offset : Int64,
) -> Bytes raise PdfGraphicsError {
  match object {
    @objects.PdfObject::String(bytes) => bytes
    @objects.PdfObject::Stream(stream) => decode_colour_stream(stream, offset)
    @objects.PdfObject::Ref(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Indexed lookup stream must be resolved before conversion",
      )
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Indexed lookup must be a direct string or stream",
      )
  }
}

///|
pub fn ColourTransformFunction::apply_scalar(
  self : ColourTransformFunction,
  input : Double,
  offset? : Int64 = 0L,
) -> Double raise PdfGraphicsError {
  let outputs = self.apply([input], 1, offset~)
  outputs[0]
}

///|
pub fn ColourTransformFunction::apply(
  self : ColourTransformFunction,
  inputs : Array[Double],
  expected_outputs : Int,
  offset? : Int64 = 0L,
) -> Array[Double] raise PdfGraphicsError {
  match self {
    IdentityTransformFunction => {
      if inputs.length() != expected_outputs {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "Identity colour function output count does not match input count",
        )
      }
      inputs.copy()
    }
    UnresolvedTransformFunction(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "indirect colour function must be resolved before evaluation",
      )
    DirectTransformFunction(source) =>
      evaluate_typed_colour_function(source, inputs, expected_outputs, offset)
  }
}

///|
fn min3(a : Double, b : Double, c : Double) -> Double {
  let ab = if a < b { a } else { b }
  if ab < c {
    ab
  } else {
    c
  }
}

///|
fn colour_component(value : Double) -> Double {
  clamp_double(value, 0.0, 1.0)
}

///|
fn lab_g(value : Double) -> Double {
  let threshold = 6.0 / 29.0
  if value >= threshold {
    value * value * value
  } else {
    108.0 / 841.0 * (value - 4.0 / 29.0)
  }
}

///|
fn srgb_encode(linear : Double) -> Double {
  let value = colour_component(linear)
  if value <= 0.0031308 {
    colour_component(12.92 * value)
  } else {
    colour_component(1.055 * @math.pow(value, 1.0 / 2.4) - 0.055)
  }
}

///|
fn d50_white_point() -> Array[Double] {
  [0.96422, 1.0, 0.82521]
}

///|
fn d65_white_point() -> Array[Double] {
  [0.95047, 1.0, 1.08883]
}

///|
fn adapt_xyz_to_d65(
  xyz : CieXyzColour,
  source_white : Array[Double],
) -> CieXyzColour {
  adapt_xyz_between_whites(xyz, source_white, d65_white_point())
}

///|
fn adapt_xyz_between_whites(
  xyz : CieXyzColour,
  source_white : Array[Double],
  target_white : Array[Double],
) -> CieXyzColour {
  let source_lms = bradford_to_lms(
    source_white[0],
    source_white[1],
    source_white[2],
  )
  let target_lms = bradford_to_lms(
    target_white[0],
    target_white[1],
    target_white[2],
  )
  let value_lms = bradford_to_lms(xyz.x, xyz.y, xyz.z)
  let l = value_lms[0] * target_lms[0] / source_lms[0]
  let m = value_lms[1] * target_lms[1] / source_lms[1]
  let s = value_lms[2] * target_lms[2] / source_lms[2]
  bradford_from_lms(l, m, s)
}

///|
fn bradford_to_lms(x : Double, y : Double, z : Double) -> Array[Double] {
  [
    0.8951 * x + 0.2664 * y - 0.1614 * z,
    -0.7502 * x + 1.7135 * y + 0.0367 * z,
    0.0389 * x - 0.0685 * y + 1.0296 * z,
  ]
}

///|
fn bradford_from_lms(l : Double, m : Double, s : Double) -> CieXyzColour {
  CieXyzColour::{
    x: 0.9869929 * l - 0.1470543 * m + 0.1599627 * s,
    y: 0.4323053 * l + 0.5183603 * m + 0.0492912 * s,
    z: -0.0085287 * l + 0.0400428 * m + 0.9684867 * s,
  }
}

///|
fn ColourRange::clip(self : ColourRange, value : Double) -> Double {
  clamp_double(value, self.min, self.max)
}

///|
fn evaluate_typed_colour_function(
  source : @functions.FunctionSource,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let outputs = try
    @functions.evaluate_function_source(
      source,
      inputs,
      @functions.FunctionLimits::default(),
    )
  catch {
    error => raise PdfGraphicsError::FunctionFailure(error)
  } noraise {
    values => values
  }
  if outputs.length() != expected_outputs {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "colour function output count does not match expected component count",
    )
  }
  outputs
}

///|
fn evaluate_colour_function_dictionary(
  dict : @objects.PdfDictionary,
  decoded_stream : Bytes?,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let function_type = match dict.get(@objects.PdfName::new(b"FunctionType")) {
    Some(@objects.PdfObject::Integer(value)) => value
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "FunctionType must be an integer",
      )
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "colour transform function requires FunctionType",
      )
  }
  match function_type {
    0L => {
      let decoded = match decoded_stream {
        Some(data) => data
        None =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "Type 0 colour function requires a stream",
          )
      }
      evaluate_type0_colour_function(
        dict, decoded, inputs, expected_outputs, offset,
      )
    }
    2L => evaluate_type2_colour_function(dict, inputs, expected_outputs, offset)
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        "colour transform FunctionType " +
        function_type.to_string() +
        " is not supported for direct evaluation",
      )
  }
}

///|
fn decode_colour_function_stream(
  stream : @objects.PdfStream,
  offset : Int64,
) -> Bytes raise PdfGraphicsError {
  try @filters.decode_stream(stream) catch {
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "failed to decode Type 0 colour function stream",
      )
  } noraise {
    decoded => decoded
  }
}

///|
fn evaluate_type0_colour_function(
  dict : @objects.PdfDictionary,
  decoded : Bytes,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let sizes = required_positive_integer_array(dict, b"Size", offset)
  let input_count = sizes.length()
  if input_count == 0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 0 colour function requires at least one input dimension",
    )
  }
  if inputs.length() != input_count {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 0 colour function input count mismatch",
    )
  }
  let domain = required_interval_array(dict, b"Domain", input_count, offset)
  let range = required_interval_array(dict, b"Range", expected_outputs, offset)
  let encode = optional_sampled_encode_array(dict, sizes, offset)
  let decode = optional_sampled_decode_array(dict, range, offset)
  let bits_per_sample = required_bits_per_sample(dict, offset)
  let encoded = encoded_sample_positions(inputs, domain, encode)
  sampled_function_outputs(
    decoded, sizes, encoded, decode, bits_per_sample, expected_outputs, offset,
  )
}

///|
fn required_positive_integer_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Array[Int] raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Array(values)) => {
      let output : Array[Int] = []
      for value in values {
        let integer = require_integer(
          value,
          offset,
          @objects.PdfName::new(key).to_text(),
        )
        if integer <= 0L || integer > 2147483647L {
          raise PdfGraphicsError::InvalidGraphicsState(
            offset,
            @objects.PdfName::new(key).to_text() +
            " values must be positive integers",
          )
        }
        output.push(integer.to_int())
      }
      output
    }
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() + " must be an array",
      )
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        "colour function requires " + @objects.PdfName::new(key).to_text(),
      )
  }
}

///|
fn required_bits_per_sample(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Int raise PdfGraphicsError {
  let value = match dict.get(@objects.PdfName::new(b"BitsPerSample")) {
    Some(object) => require_integer(object, offset, "BitsPerSample")
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Type 0 colour function requires BitsPerSample",
      )
  }
  match value {
    1L | 2L | 4L | 8L | 12L | 16L | 24L | 32L => value.to_int()
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "unsupported Type 0 BitsPerSample value",
      )
  }
}

///|
fn optional_sampled_encode_array(
  dict : @objects.PdfDictionary,
  sizes : Array[Int],
  offset : Int64,
) -> Array[ColourRange] raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(b"Encode")) {
    Some(value) => interval_array(value, sizes.length(), offset, "Encode")
    None => {
      let encode : Array[ColourRange] = []
      for size in sizes {
        encode.push(ColourRange::{ min: 0.0, max: (size - 1).to_double() })
      }
      encode
    }
  }
}

///|
fn optional_sampled_decode_array(
  dict : @objects.PdfDictionary,
  range : Array[ColourRange],
  offset : Int64,
) -> Array[ColourRange] raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(b"Decode")) {
    Some(value) => interval_array(value, range.length(), offset, "Decode")
    None => range.copy()
  }
}

///|
fn encoded_sample_positions(
  inputs : Array[Double],
  domain : Array[ColourRange],
  encode : Array[ColourRange],
) -> Array[Double] {
  let positions : Array[Double] = []
  for index in 0..<inputs.length() {
    let clipped = domain[index].clip(inputs[index])
    let denominator = domain[index].max - domain[index].min
    let encoded = if denominator == 0.0 {
      encode[index].min
    } else {
      encode[index].min +
      (clipped - domain[index].min) *
      (encode[index].max - encode[index].min) /
      denominator
    }
    positions.push(encode[index].clip(encoded))
  }
  positions
}

///|
fn sampled_function_outputs(
  data : Bytes,
  sizes : Array[Int],
  encoded : Array[Double],
  decode : Array[ColourRange],
  bits_per_sample : Int,
  output_count : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  if sizes.length() > 12 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 0 colour function has too many input dimensions",
    )
  }
  require_sample_table_bits(data, sizes, output_count, bits_per_sample, offset)
  let lows : Array[Int] = []
  let highs : Array[Int] = []
  let fractions : Array[Double] = []
  for index in 0..<sizes.length() {
    let low = @math.floor(encoded[index]).to_int()
    let clipped_low = clamp_int(low, 0, sizes[index] - 1)
    let clipped_high = clamp_int(clipped_low + 1, 0, sizes[index] - 1)
    lows.push(clipped_low)
    highs.push(clipped_high)
    if clipped_high == clipped_low {
      fractions.push(0.0)
    } else {
      fractions.push(encoded[index] - clipped_low.to_double())
    }
  }
  let outputs = repeat_double(output_count, 0.0)
  let corner_count = 1 << sizes.length()
  for corner in 0..<corner_count {
    let mut weight = 1.0
    let indices : Array[Int] = []
    for dimension in 0..<sizes.length() {
      if ((corner >> dimension) & 1) == 0 {
        indices.push(lows[dimension])
        weight = weight * (1.0 - fractions[dimension])
      } else {
        indices.push(highs[dimension])
        weight = weight * fractions[dimension]
      }
    }
    if weight != 0.0 {
      for component in 0..<output_count {
        outputs[component] += weight *
          decoded_sample_value(
            data,
            sizes,
            indices,
            component,
            output_count,
            bits_per_sample,
            decode[component],
            offset,
          )
      }
    }
  }
  outputs
}

///|
fn require_sample_table_bits(
  data : Bytes,
  sizes : Array[Int],
  output_count : Int,
  bits_per_sample : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let mut sample_count = output_count
  for size in sizes {
    sample_count = sample_count * size
  }
  let required_bits = sample_count * bits_per_sample
  if data.length() * 8 < required_bits {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "truncated Type 0 colour function sample table",
    )
  }
}

///|
fn decoded_sample_value(
  data : Bytes,
  sizes : Array[Int],
  indices : Array[Int],
  component : Int,
  output_count : Int,
  bits_per_sample : Int,
  decode : ColourRange,
  offset : Int64,
) -> Double raise PdfGraphicsError {
  let sample_index = sampled_function_sample_index(sizes, indices)
  let value_index = sample_index * output_count + component
  let raw = read_sample_bits(
    data,
    value_index * bits_per_sample,
    bits_per_sample,
    offset,
  )
  let max_raw = (1L << bits_per_sample) - 1L
  decode.clip(
    decode.min +
    raw.to_double() / max_raw.to_double() * (decode.max - decode.min),
  )
}

///|
fn sampled_function_sample_index(
  sizes : Array[Int],
  indices : Array[Int],
) -> Int {
  let mut index = 0
  let mut stride = 1
  for dimension in 0..<sizes.length() {
    index += indices[dimension] * stride
    stride *= sizes[dimension]
  }
  index
}

///|
fn read_sample_bits(
  data : Bytes,
  bit_offset : Int,
  count : Int,
  offset : Int64,
) -> Int64 raise PdfGraphicsError {
  if count <= 0 || count > 32 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 0 sample bit count is out of range",
    )
  }
  if bit_offset + count > data.length() * 8 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "truncated Type 0 colour function sample table",
    )
  }
  let mut value = 0L
  for bit in 0..<count {
    let position = bit_offset + bit
    let byte_index = position / 8
    let bit_index = 7 - position % 8
    let bit_value = (data[byte_index].to_int() >> bit_index) & 1
    value = (value << 1) | bit_value.to_int64()
  }
  value
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn evaluate_type2_colour_function(
  dict : @objects.PdfDictionary,
  inputs : Array[Double],
  expected_outputs : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  if inputs.length() != 1 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 2 colour function requires one input",
    )
  }
  let domain = required_interval_array(dict, b"Domain", 1, offset)
  let range = optional_interval_array(dict, b"Range", expected_outputs, offset)
  let c0 = optional_output_array(dict, b"C0", offset)
  let c1 = optional_output_array(dict, b"C1", offset)
  let output_count = infer_type2_output_count(c0, c1, expected_outputs, offset)
  let c0_values = match c0 {
    Some(values) => values
    None => repeat_double(output_count, 0.0)
  }
  let c1_values = match c1 {
    Some(values) => values
    None => repeat_double(output_count, 1.0)
  }
  if c0_values.length() != output_count || c1_values.length() != output_count {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Type 2 C0 and C1 output counts must match",
    )
  }
  let exponent = match dict.get(@objects.PdfName::new(b"N")) {
    Some(value) => finite_colour_number(value, offset, "Type 2 N")
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Type 2 colour function requires N",
      )
  }
  let x = domain[0].clip(
    finite_double(inputs[0], offset, "colour function input"),
  )
  let factor = finite_double(@math.pow(x, exponent), offset, "Type 2 power")
  let outputs : Array[Double] = []
  for index in 0..<output_count {
    let raw = c0_values[index] + factor * (c1_values[index] - c0_values[index])
    let clipped = match range {
      Some(intervals) => intervals[index].clip(raw)
      None => raw
    }
    outputs.push(finite_double(clipped, offset, "colour function output"))
  }
  outputs
}

///|
fn infer_type2_output_count(
  c0 : Array[Double]?,
  c1 : Array[Double]?,
  expected_outputs : Int,
  offset : Int64,
) -> Int raise PdfGraphicsError {
  let count = match c0 {
    Some(values) => values.length()
    None =>
      match c1 {
        Some(values) => values.length()
        None => expected_outputs
      }
  }
  if count != expected_outputs {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "colour function output count mismatch",
    )
  }
  if count <= 0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "colour function must produce at least one output",
    )
  }
  count
}

///|
fn optional_output_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Array[Double]? raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => None
    Some(value) => Some(numeric_array(value, offset, key.to_string()))
  }
}

///|
fn required_interval_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected_count : Int,
  offset : Int64,
) -> Array[ColourRange] raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(value) =>
      interval_array(value, expected_count, offset, key.to_string())
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        "colour function requires " + @objects.PdfName::new(key).to_text(),
      )
  }
}

///|
fn optional_interval_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected_count : Int,
  offset : Int64,
) -> Array[ColourRange]? raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => None
    Some(value) =>
      Some(interval_array(value, expected_count, offset, key.to_string()))
  }
}

///|
fn interval_array(
  object : @objects.PdfObject,
  expected_count : Int,
  offset : Int64,
  label : String,
) -> Array[ColourRange] raise PdfGraphicsError {
  let values = numeric_array(object, offset, label)
  if values.length() != expected_count * 2 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset,
      label + " must contain interval pairs",
    )
  }
  let intervals : Array[ColourRange] = []
  for index in 0..<expected_count {
    let min = values[index * 2]
    let max = values[index * 2 + 1]
    if min > max {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " lower bound must not exceed upper bound",
      )
    }
    intervals.push(ColourRange::{ min, max })
  }
  intervals
}

///|
fn numeric_array(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[Double] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => {
      let numbers : Array[Double] = []
      for value in values {
        numbers.push(finite_colour_number(value, offset, label))
      }
      numbers
    }
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be an array",
      )
  }
}

///|
fn finite_colour_number(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  finite_double(colour_object_number(object, offset, label), offset, label)
}

///|
fn finite_double(
  value : Double,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  if value.is_nan() || value.is_inf() {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset,
      label + " must be finite",
    )
  }
  value
}

///|
fn repeat_double(count : Int, value : Double) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<count {
    values.push(value)
  }
  values
}
