///|
/// Device colour spaces from ISO 32000-2 8.6.4.1 General.
/// DeviceGray controls achromatic light from black to white, DeviceRGB is the
/// additive red-green-blue model for displays, and DeviceCMYK is the
/// subtractive cyan-magenta-yellow-black process-colour model for printing.
pub(all) enum DeviceColourSpace {
  DeviceGray
  DeviceRGB
  DeviceCMYK
} derive(Eq, Debug)

///|
/// Minimum and maximum valid values for one colour component. Component
/// normalization substitutes the nearest valid value without error indication
/// where ISO 32000-2 colour-space rules require clamping.
pub(all) struct ColourRange {
  min : Double
  max : Double
} derive(Eq, Debug)

///|
/// CalGray CIE-based A colour space parameters. WhitePoint and BlackPoint are
/// CIE 1931 XYZ tristimulus values; Gamma decodes the single A gray component.
pub(all) struct CalGrayParams {
  white_point : Array[Double]
  black_point : Array[Double]
  gamma : Double
} derive(Eq, Debug)

///|
/// CalRGB CIE-based ABC colour space parameters. Gamma and Matrix define the
/// one-stage nonlinear transformation from calibrated red, green, and blue
/// components into the CIE 1931 XYZ representation.
pub(all) struct CalRGBParams {
  white_point : Array[Double]
  black_point : Array[Double]
  gamma : Array[Double]
  matrix : Array[Double]
} derive(Eq, Debug)

///|
/// Lab CIE-based ABC colour space parameters for CIE 1976 L*a*b*. The L*
/// component is constrained to 0..100 and Range supplies the a* and b* limits.
pub(all) struct LabParams {
  white_point : Array[Double]
  black_point : Array[Double]
  range : Array[Double]
} derive(Eq, Debug)

///|
/// ICCBased profile header summary. PDF 2.0 uses ICC.1:2010
/// (ISO 15076-1:2010) as listed in Table 66, and graphics source profiles are
/// constrained by Table 67 profile types: deviceClass must be scnr, mntr,
/// prtr, or spac, and colorSpace must be GRAY, RGB, CMYK, or Lab.
pub(all) struct IccProfileInfo {
  component_count : Int
  data_colour_space : @objects.PdfName
  decoded_length : Int
} derive(Eq, Debug)

///|
/// Source of an ICCBased colour space profile. DirectProfile stores validated
/// bytes from an ICC profile stream; IndirectProfile preserves reader-owned
/// object loading for a later integration layer.
pub(all) enum IccProfileSource {
  DirectProfile(IccProfileInfo)
  IndirectProfile(@objects.ObjectId)
} derive(Eq, Debug)

///|
/// ICCBased colour space dictionary parameters: required N component count,
/// optional Alternate colour space, optional Range array, and optional Metadata
/// stream. Source colour values are interpreted through the embedded ICC
/// profile; tint transformation and alternate conversion are not performed by
/// the graphics interpreter.
pub(all) struct IccBasedParams {
  source : IccProfileSource
  component_count : Int
  range : Array[ColourRange]
  alternate : ColourSpace?
  metadata : @objects.PdfObject?
} derive(Eq, Debug)

///|
/// Parameters for the special ISO 32000-2 Pattern colour space family.
/// A bare Pattern space selects coloured tiling patterns and shading patterns;
/// a Pattern space with an underlying colour space supplies components for
/// uncoloured tiling patterns.
pub(all) struct PatternParams {
  underlying : ColourSpace?
} derive(Eq, Debug)

///|
/// Indexed colour space parameters from ISO 32000-2 8.6.6.3. The lookup colour
/// table maps integer indices 0..hival to component values in the base colour
/// space and may be supplied by a byte string, stream, or indirect object.
pub(all) struct IndexedParams {
  base : ColourSpace
  hival : Int
  lookup : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Separation colour space parameters from ISO 32000-2 8.6.6.4. A single tint
/// component controls one colourant, including the special All and None names;
/// alternate and tintTransform are preserved for renderer policy.
pub(all) struct SeparationParams {
  colorant : @objects.PdfName
  alternate : ColourSpace
  tint_transform : @objects.PdfObject
} derive(Eq, Debug)

///|
/// DeviceN attributes dictionary from ISO 32000-2 Table 70. Subtype may be
/// DeviceN or NChannel; Colorants, Process, and MixingHints (Table 72) carry
/// structural information for spot colourants, process colour components, and
/// blending hints without evaluating colour conversions.
pub(all) struct DeviceNAttributes {
  subtype : @objects.PdfName?
  colorants : @objects.PdfDictionary?
  process : @objects.PdfDictionary?
  mixing_hints : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// DeviceN and NChannel colour space parameters from ISO 32000-2 8.6.6.5.
/// DeviceN represents high-fidelity colour and multitone colour with multiple
/// tint components, all initially 1.0. NChannel adds process/spot metadata for
/// flexible downstream rendering.
pub(all) struct DeviceNParams {
  colorants : Array[@objects.PdfName]
  alternate : ColourSpace
  tint_transform : @objects.PdfObject
  attributes : DeviceNAttributes?
} derive(Eq, Debug)

///|
/// PDF colour space families used by graphics operators for ISO 32000-2 8.6
/// colour specification, separated from device-dependent colour rendering.
/// This model records device-independent abstract colours and the colour-space
/// family data needed by downstream consumers; raster output device work such
/// as colour conversion, gamma correction, halftoning, and scan conversion is
/// intentionally outside graphics interpretation. CIE-based spaces preserve
/// the data needed for implicit conversion of CIE-Based colour spaces by a
/// renderer, but the conversion itself remains hidden renderer policy.
///
/// Source excerpt:
/// `spec/extracted/8.6-colour-spaces.spec.txt`.
pub(all) enum ColourSpace {
  Device(DeviceColourSpace)
  CalGray(CalGrayParams)
  CalRGB(CalRGBParams)
  Lab(LabParams)
  ICCBased(IccBasedParams)
  Pattern(PatternParams)
  Indexed(IndexedParams)
  Separation(SeparationParams)
  DeviceN(DeviceNParams)
} derive(Eq, Debug)

///|
/// DefaultGray, DefaultRGB, and DefaultCMYK resource entries used to remap
/// DeviceGray, DeviceRGB, and DeviceCMYK colour spaces systematically into
/// compatible default colour spaces.
pub(all) struct ColourDefaults {
  default_gray : @objects.PdfObject?
  default_rgb : @objects.PdfObject?
  default_cmyk : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub fn ColourDefaults::empty() -> ColourDefaults {
  ColourDefaults::{ default_gray: None, default_rgb: None, default_cmyk: None }
}

///|
/// Parses a colour space object, including device, CIE-based, ICCBased,
/// Pattern, Indexed, Separation, DeviceN, NChannel, and default remapped
/// colour-space families used by ISO 32000-2 clause 8.6.
pub fn parse_colour_space_object(
  object : @objects.PdfObject,
  defaults : ColourDefaults,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  parse_colour_space_object_with_defaults(object, defaults, true, offset)
}

///|
fn parse_colour_space_object_with_defaults(
  object : @objects.PdfObject,
  defaults : ColourDefaults,
  allow_defaults : Bool,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) =>
      parse_colour_space_name(name, defaults, allow_defaults, offset)
    @objects.PdfObject::Array(values) =>
      parse_colour_space_array(values, defaults, allow_defaults, offset)
    @objects.PdfObject::Stream(stream) =>
      ColourSpace::ICCBased(validate_icc_based_stream(stream, defaults, offset))
    @objects.PdfObject::Ref(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "indirect colour space references must be resolved before graphics interpretation",
      )
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "colour space must be a name, array, or direct stream",
      )
  }
}

///|
fn parse_colour_space_name(
  name : @objects.PdfName,
  defaults : ColourDefaults,
  allow_defaults : Bool,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if name == @objects.PdfName::new(b"DeviceGray") {
    defaulted_device_space(
      DeviceColourSpace::DeviceGray,
      defaults,
      allow_defaults,
      offset,
    )
  } else if name == @objects.PdfName::new(b"DeviceRGB") {
    defaulted_device_space(
      DeviceColourSpace::DeviceRGB,
      defaults,
      allow_defaults,
      offset,
    )
  } else if name == @objects.PdfName::new(b"DeviceCMYK") {
    defaulted_device_space(
      DeviceColourSpace::DeviceCMYK,
      defaults,
      allow_defaults,
      offset,
    )
  } else if name == @objects.PdfName::new(b"Pattern") {
    ColourSpace::Pattern(PatternParams::{ underlying: None })
  } else {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset,
      "unknown direct colour space name " + name.to_text(),
    )
  }
}

///|
fn defaulted_device_space(
  device : DeviceColourSpace,
  defaults : ColourDefaults,
  allow_defaults : Bool,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  let fallback = ColourSpace::Device(device)
  if !allow_defaults {
    return fallback
  }
  let default_object = match device {
    DeviceGray => defaults.default_gray
    DeviceRGB => defaults.default_rgb
    DeviceCMYK => defaults.default_cmyk
  }
  match default_object {
    None => fallback
    Some(object) => {
      let space = parse_colour_space_object_with_defaults(
        object,
        ColourDefaults::empty(),
        false,
        offset,
      )
      validate_default_space(device, space, offset)
      space
    }
  }
}

///|
fn validate_default_space(
  device : DeviceColourSpace,
  space : ColourSpace,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if space.component_count() != ColourSpace::Device(device).component_count() {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "default device colour space component count mismatch",
    )
  }
  match space {
    Lab(_) | Indexed(_) | Pattern(_) | Separation(_) | DeviceN(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "default device colour space family is not permitted",
      )
    _ => ()
  }
}

///|
fn parse_colour_space_array(
  values : Array[@objects.PdfObject],
  defaults : ColourDefaults,
  allow_defaults : Bool,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() == 0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "colour space array must not be empty",
    )
  }
  let family = match values[0] {
    @objects.PdfObject::Name(name) => name
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "colour space array family must be a name",
      )
  }
  if family == @objects.PdfName::new(b"DeviceGray") ||
    family == @objects.PdfName::new(b"DeviceRGB") ||
    family == @objects.PdfName::new(b"DeviceCMYK") ||
    family == @objects.PdfName::new(b"Pattern") {
    parse_family_name_array(family, values, defaults, allow_defaults, offset)
  } else if family == @objects.PdfName::new(b"CalGray") {
    parse_cal_gray(values, offset)
  } else if family == @objects.PdfName::new(b"CalRGB") {
    parse_cal_rgb(values, offset)
  } else if family == @objects.PdfName::new(b"Lab") {
    parse_lab(values, offset)
  } else if family == @objects.PdfName::new(b"ICCBased") {
    parse_icc_based(values, defaults, offset)
  } else if family == @objects.PdfName::new(b"Indexed") ||
    family == @objects.PdfName::new(b"I") {
    parse_indexed(values, defaults, offset)
  } else if family == @objects.PdfName::new(b"Separation") {
    parse_separation(values, defaults, offset)
  } else if family == @objects.PdfName::new(b"DeviceN") {
    parse_device_n(values, defaults, offset)
  } else {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset,
      "unsupported colour space family " + family.to_text(),
    )
  }
}

///|
fn parse_family_name_array(
  family : @objects.PdfName,
  values : Array[@objects.PdfObject],
  defaults : ColourDefaults,
  allow_defaults : Bool,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if family == @objects.PdfName::new(b"Pattern") {
    if values.length() == 1 {
      ColourSpace::Pattern(PatternParams::{ underlying: None })
    } else if values.length() == 2 {
      let underlying = parse_colour_space_object_with_defaults(
        values[1],
        defaults,
        allow_defaults,
        offset,
      )
      match underlying {
        Pattern(_) =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "Pattern colour space cannot use Pattern as an underlying space",
          )
        _ =>
          ColourSpace::Pattern(PatternParams::{ underlying: Some(underlying) })
      }
    } else {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Pattern colour space array must contain one or two entries",
      )
    }
  } else {
    if values.length() != 1 {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "device colour space array must contain only the family name",
      )
    }
    parse_colour_space_name(family, defaults, allow_defaults, offset)
  }
}

///|
fn parse_cal_gray(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 2 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "CalGray colour space must contain a dictionary",
    )
  }
  let dict = require_dictionary(values[1], offset, "CalGray")
  ColourSpace::CalGray(CalGrayParams::{
    white_point: required_white_point(dict, offset),
    black_point: optional_black_point(dict, offset),
    gamma: optional_positive_number(dict, b"Gamma", 1.0, offset),
  })
}

///|
fn parse_cal_rgb(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 2 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "CalRGB colour space must contain a dictionary",
    )
  }
  let dict = require_dictionary(values[1], offset, "CalRGB")
  ColourSpace::CalRGB(CalRGBParams::{
    white_point: required_white_point(dict, offset),
    black_point: optional_black_point(dict, offset),
    gamma: optional_positive_array(dict, b"Gamma", 3, [1.0, 1.0, 1.0], offset),
    matrix: optional_number_array(
      dict,
      b"Matrix",
      9,
      [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
      offset,
    ),
  })
}

///|
fn parse_lab(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 2 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Lab colour space must contain a dictionary",
    )
  }
  let dict = require_dictionary(values[1], offset, "Lab")
  let range = optional_number_array(
    dict,
    b"Range",
    4,
    [-100.0, 100.0, -100.0, 100.0],
    offset,
  )
  validate_range_pairs(range, offset, "Lab Range")
  ColourSpace::Lab(LabParams::{
    white_point: required_white_point(dict, offset),
    black_point: optional_black_point(dict, offset),
    range,
  })
}

///|
fn parse_icc_based(
  values : Array[@objects.PdfObject],
  defaults : ColourDefaults,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 2 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICCBased colour space must contain a profile stream",
    )
  }
  match values[1] {
    @objects.PdfObject::Stream(stream) =>
      ColourSpace::ICCBased(validate_icc_based_stream(stream, defaults, offset))
    @objects.PdfObject::Ref(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICCBased profile stream must be direct for graphics validation",
      )
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICCBased profile must be a stream",
      )
  }
}

///|
fn parse_indexed(
  values : Array[@objects.PdfObject],
  defaults : ColourDefaults,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 4 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Indexed colour space must contain base, hival, and lookup",
    )
  }
  let base = parse_colour_space_object_with_defaults(
    values[1],
    defaults,
    true,
    offset,
  )
  match base {
    Pattern(_) | Indexed(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Indexed base colour space cannot be Pattern or Indexed",
      )
    _ => ()
  }
  let hival = require_integer(values[2], offset, "Indexed hival")
  if hival < 0L || hival > 255L {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Indexed hival must be in range 0..255",
    )
  }
  validate_indexed_lookup(base, hival.to_int(), values[3], offset)
  ColourSpace::Indexed(IndexedParams::{
    base,
    hival: hival.to_int(),
    lookup: values[3],
  })
}

///|
fn parse_separation(
  values : Array[@objects.PdfObject],
  defaults : ColourDefaults,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 4 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Separation colour space must contain name, alternate, and tint transform",
    )
  }
  let colorant = require_name(values[1], offset, "Separation colorant")
  let alternate = parse_colour_space_object_with_defaults(
    values[2],
    defaults,
    true,
    offset,
  )
  validate_alternate_colour_space(alternate, offset, "Separation alternate")
  validate_tint_transform(values[3], offset)
  ColourSpace::Separation(SeparationParams::{
    colorant,
    alternate,
    tint_transform: values[3],
  })
}

///|
fn parse_device_n(
  values : Array[@objects.PdfObject],
  defaults : ColourDefaults,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if values.length() != 4 && values.length() != 5 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "DeviceN colour space must contain names, alternate, tint transform, and optional attributes",
    )
  }
  let colorants = require_name_array(values[1], offset, "DeviceN colorants")
  validate_device_n_names(colorants, offset)
  let alternate = parse_colour_space_object_with_defaults(
    values[2],
    defaults,
    true,
    offset,
  )
  validate_alternate_colour_space(alternate, offset, "DeviceN alternate")
  validate_tint_transform(values[3], offset)
  let attributes = if values.length() == 5 {
    Some(parse_device_n_attributes(values[4], colorants, defaults, offset))
  } else {
    None
  }
  ColourSpace::DeviceN(DeviceNParams::{
    colorants,
    alternate,
    tint_transform: values[3],
    attributes,
  })
}

///|
fn validate_device_n_names(
  names : Array[@objects.PdfName],
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if names.length() == 0 || names.length() > 32 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "DeviceN component count must be in range 1..32",
    )
  }
  for i in 0..<names.length() {
    if names[i] == @objects.PdfName::new(b"All") {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "DeviceN colorants must not include All",
      )
    }
    if names[i] != @objects.PdfName::new(b"None") {
      for j in (i + 1)..<names.length() {
        if names[i] == names[j] {
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "DeviceN colorant names must be unique except None",
          )
        }
      }
    }
  }
}

///|
fn parse_device_n_attributes(
  object : @objects.PdfObject,
  colorants : Array[@objects.PdfName],
  defaults : ColourDefaults,
  offset : Int64,
) -> DeviceNAttributes raise PdfGraphicsError {
  let dict = require_dictionary(object, offset, "DeviceN attributes")
  let subtype = optional_name_from_dict(dict, b"Subtype", offset)
  let colorants_dict = optional_dictionary_from_dict(dict, b"Colorants", offset)
  let process = optional_dictionary_from_dict(dict, b"Process", offset)
  let mixing_hints = optional_dictionary_from_dict(dict, b"MixingHints", offset)
  if colorants_dict is Some(value) {
    validate_device_n_colorants_dictionary(value, defaults, offset)
  }
  if subtype == Some(@objects.PdfName::new(b"NChannel")) {
    for name in colorants {
      if name == @objects.PdfName::new(b"None") {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "NChannel colorants must not include None",
        )
      }
    }
    validate_nchannel_attributes(
      colorants, colorants_dict, process, mixing_hints, defaults, offset,
    )
  }
  DeviceNAttributes::{
    subtype,
    colorants: colorants_dict,
    process,
    mixing_hints,
  }
}

///|
fn validate_device_n_colorants_dictionary(
  dict : @objects.PdfDictionary,
  defaults : ColourDefaults,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  for entry in dict.to_array() {
    let (key, value) = entry
    let space = parse_colour_space_object_with_defaults(
      value, defaults, true, offset,
    )
    match space {
      Separation(params) =>
        if params.colorant != key {
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "DeviceN Colorants entry key must match Separation colorant",
          )
        }
      _ =>
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "DeviceN Colorants entries must be Separation colour spaces",
        )
    }
  }
}

///|
fn validate_nchannel_attributes(
  colorants : Array[@objects.PdfName],
  colorants_dict : @objects.PdfDictionary?,
  process : @objects.PdfDictionary?,
  mixing_hints : @objects.PdfDictionary?,
  defaults : ColourDefaults,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let process_components = match process {
    None => []
    Some(dict) => validate_nchannel_process(dict, defaults, offset)
  }
  for name in colorants {
    if name != @objects.PdfName::new(b"None") &&
      !process_components.contains(name) {
      match colorants_dict {
        Some(dict) =>
          if !dict.contains(name) {
            raise PdfGraphicsError::InvalidGraphicsState(
              offset, "NChannel spot colorant is missing from Colorants",
            )
          }
        None =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "NChannel spot colorants require a Colorants dictionary",
          )
      }
    }
  }
  if mixing_hints is Some(dict) {
    validate_mixing_hints(dict, colorants, offset)
  }
}

///|
fn validate_nchannel_process(
  dict : @objects.PdfDictionary,
  defaults : ColourDefaults,
  offset : Int64,
) -> Array[@objects.PdfName] raise PdfGraphicsError {
  let space_object = match dict.get(@objects.PdfName::new(b"ColorSpace")) {
    Some(value) => value
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "NChannel Process must contain ColorSpace",
      )
  }
  let space = parse_colour_space_object_with_defaults(
    space_object, defaults, true, offset,
  )
  validate_alternate_colour_space(space, offset, "NChannel Process ColorSpace")
  if space is Lab(_) {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "NChannel Process ColorSpace cannot be Lab",
    )
  }
  let components_object = match dict.get(@objects.PdfName::new(b"Components")) {
    Some(value) => value
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "NChannel Process must contain Components",
      )
  }
  let components = require_name_array(
    components_object, offset, "NChannel Process Components",
  )
  if components.length() != space.component_count() {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "NChannel process component count must match process colour space",
    )
  }
  components
}

///|
fn validate_mixing_hints(
  dict : @objects.PdfDictionary,
  colorants : Array[@objects.PdfName],
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let mut has_solidities = false
  let mut printing_order : Array[@objects.PdfName]? = None
  for entry in dict.to_array() {
    let (key, value) = entry
    if key == @objects.PdfName::new(b"Solidities") {
      has_solidities = true
      match value {
        @objects.PdfObject::Dictionary(inner) =>
          for inner_entry in inner.to_array() {
            let (_, solidity) = inner_entry
            let number = colour_object_number(
              solidity, offset, "NChannel Solidities value",
            )
            if number < 0.0 || number > 1.0 {
              raise PdfGraphicsError::InvalidGraphicsState(
                offset, "NChannel Solidities values must be in range 0..1",
              )
            }
          }
        _ =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "NChannel mixing hint entries must be dictionaries",
          )
      }
    } else if key == @objects.PdfName::new(b"DotGain") {
      match value {
        @objects.PdfObject::Dictionary(_) => ()
        _ =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "NChannel mixing hint entries must be dictionaries",
          )
      }
    } else if key == @objects.PdfName::new(b"PrintingOrder") {
      printing_order = Some(
        require_name_array(value, offset, "NChannel PrintingOrder"),
      )
    }
  }
  if has_solidities && printing_order is None {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "NChannel Solidities requires PrintingOrder",
    )
  }
  if printing_order is Some(order) {
    for name in colorants {
      if !order.contains(name) {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "NChannel PrintingOrder must include every DeviceN colorant",
        )
      }
    }
  }
}

///|
fn validate_alternate_colour_space(
  space : ColourSpace,
  offset : Int64,
  label : String,
) -> Unit raise PdfGraphicsError {
  match space {
    Pattern(_) | Indexed(_) | Separation(_) | DeviceN(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " cannot be a special colour space",
      )
    _ => ()
  }
}

///|
fn validate_tint_transform(
  object : @objects.PdfObject,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Null =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "tint transform must be present",
      )
    _ => ()
  }
}

///|
fn validate_indexed_lookup(
  base : ColourSpace,
  hival : Int,
  lookup : @objects.PdfObject,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let components = base.component_count()
  let entries = hival + 1
  if components > 0 && entries > 2147483647 / components {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Indexed lookup byte length overflow",
    )
  }
  let expected = components * entries
  match lookup {
    @objects.PdfObject::String(bytes) =>
      if bytes.length() != expected {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "Indexed lookup string length does not match base components",
        )
      }
    @objects.PdfObject::Stream(stream) => {
      let decoded = decode_colour_stream(stream, offset)
      if decoded.length() != expected {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "Indexed lookup stream length does not match base components",
        )
      }
    }
    @objects.PdfObject::Ref(_) => ()
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "Indexed lookup must be a string, stream, or indirect reference",
      )
  }
}

///|
pub fn ColourSpace::component_count(self : ColourSpace) -> Int {
  match self {
    Device(DeviceGray) => 1
    Device(DeviceRGB) => 3
    Device(DeviceCMYK) => 4
    CalGray(_) => 1
    CalRGB(_) => 3
    Lab(_) => 3
    ICCBased(params) => params.component_count
    Indexed(_) => 1
    Pattern(params) =>
      match params.underlying {
        Some(space) => space.component_count()
        None => 0
      }
    Separation(_) => 1
    DeviceN(params) => params.colorants.length()
  }
}

///|
pub fn ColourSpace::component_ranges(self : ColourSpace) -> Array[ColourRange] {
  match self {
    Device(DeviceGray) | Device(DeviceRGB) | CalGray(_) | CalRGB(_) =>
      repeat_range(self.component_count(), 0.0, 1.0)
    Device(DeviceCMYK) => repeat_range(4, 0.0, 1.0)
    Lab(params) =>
      [
        ColourRange::{ min: 0.0, max: 100.0 },
        ColourRange::{ min: params.range[0], max: params.range[1] },
        ColourRange::{ min: params.range[2], max: params.range[3] },
      ]
    ICCBased(params) => params.range.copy()
    Indexed(params) =>
      [ColourRange::{ min: 0.0, max: params.hival.to_double() }]
    Pattern(params) =>
      match params.underlying {
        Some(space) => space.component_ranges()
        None => []
      }
    Separation(_) => [ColourRange::{ min: 0.0, max: 1.0 }]
    DeviceN(params) => repeat_range(params.colorants.length(), 0.0, 1.0)
  }
}

///|
/// Returns the initial current colour for a colour space. DeviceGray,
/// DeviceRGB, CalGray, and CalRGB start at 0.0 components; DeviceCMYK starts
/// at [0.0 0.0 0.0 1.0]; Lab and ICCBased use the nearest valid range value;
/// Indexed starts at 0; Separation and DeviceN tint components start at 1.0.
pub fn ColourSpace::initial_value(self : ColourSpace) -> ColourValue {
  match self {
    Device(DeviceCMYK) =>
      ColourValue::{ components: [0.0, 0.0, 0.0, 1.0], pattern: None }
    ICCBased(params) =>
      ColourValue::{
        components: initial_from_ranges(params.range),
        pattern: None,
      }
    Pattern(params) =>
      match params.underlying {
        Some(space) => {
          let value = space.initial_value()
          ColourValue::{ components: value.components.copy(), pattern: None }
        }
        None => ColourValue::{ components: [], pattern: None }
      }
    Separation(_) => ColourValue::{ components: [1.0], pattern: None }
    DeviceN(params) => {
      let components : Array[Double] = []
      for _ in 0..<params.colorants.length() {
        components.push(1.0)
      }
      ColourValue::{ components, pattern: None }
    }
    _ => {
      let components : Array[Double] = []
      for _ in 0..<self.component_count() {
        components.push(0.0)
      }
      ColourValue::{ components, pattern: None }
    }
  }
}

///|
fn initial_from_ranges(ranges : Array[ColourRange]) -> Array[Double] {
  let values : Array[Double] = []
  for range in ranges {
    values.push(range.min)
  }
  values
}

///|
fn repeat_range(count : Int, min : Double, max : Double) -> Array[ColourRange] {
  let ranges : Array[ColourRange] = []
  for _ in 0..<count {
    ranges.push(ColourRange::{ min, max })
  }
  ranges
}

///|
pub fn ColourSpace::copy(self : ColourSpace) -> ColourSpace {
  match self {
    Device(device) => Device(device)
    CalGray(params) =>
      CalGray(CalGrayParams::{
        white_point: params.white_point.copy(),
        black_point: params.black_point.copy(),
        gamma: params.gamma,
      })
    CalRGB(params) =>
      CalRGB(CalRGBParams::{
        white_point: params.white_point.copy(),
        black_point: params.black_point.copy(),
        gamma: params.gamma.copy(),
        matrix: params.matrix.copy(),
      })
    Lab(params) =>
      Lab(LabParams::{
        white_point: params.white_point.copy(),
        black_point: params.black_point.copy(),
        range: params.range.copy(),
      })
    ICCBased(params) =>
      ICCBased(IccBasedParams::{
        source: params.source,
        component_count: params.component_count,
        range: params.range.copy(),
        alternate: match params.alternate {
          Some(space) => Some(space.copy())
          None => None
        },
        metadata: params.metadata,
      })
    Pattern(params) =>
      Pattern(PatternParams::{
        underlying: match params.underlying {
          Some(space) => Some(space.copy())
          None => None
        },
      })
    Indexed(params) =>
      Indexed(IndexedParams::{
        base: params.base.copy(),
        hival: params.hival,
        lookup: params.lookup,
      })
    Separation(params) =>
      Separation(SeparationParams::{
        colorant: params.colorant,
        alternate: params.alternate.copy(),
        tint_transform: params.tint_transform,
      })
    DeviceN(params) =>
      DeviceN(DeviceNParams::{
        colorants: params.colorants.copy(),
        alternate: params.alternate.copy(),
        tint_transform: params.tint_transform,
        attributes: params.attributes,
      })
  }
}

///|
fn required_white_point(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let white = match dict.get(@objects.PdfName::new(b"WhitePoint")) {
    Some(value) => require_number_array(value, 3, offset, "WhitePoint")
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "calibrated colour space requires WhitePoint",
      )
  }
  if white[0] <= 0.0 || white[1] != 1.0 || white[2] <= 0.0 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "WhitePoint must have positive X and Z and Y equal to 1",
    )
  }
  white
}

///|
fn optional_black_point(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let black = match dict.get(@objects.PdfName::new(b"BlackPoint")) {
    Some(value) => require_number_array(value, 3, offset, "BlackPoint")
    None => [0.0, 0.0, 0.0]
  }
  for value in black {
    if value < 0.0 {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "BlackPoint values must be nonnegative",
      )
    }
  }
  black
}

///|
fn optional_positive_number(
  dict : @objects.PdfDictionary,
  key : Bytes,
  fallback : Double,
  offset : Int64,
) -> Double raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => fallback
    Some(value) => {
      let number = colour_object_number(
        value,
        offset,
        @objects.PdfName::new(key).to_text(),
      )
      if number <= 0.0 {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset,
          @objects.PdfName::new(key).to_text() + " values must be positive",
        )
      }
      number
    }
  }
}

///|
fn optional_positive_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  count : Int,
  fallback : Array[Double],
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  let values = optional_number_array(dict, key, count, fallback, offset)
  for value in values {
    if value <= 0.0 {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() + " values must be positive",
      )
    }
  }
  values
}

///|
fn optional_number_array(
  dict : @objects.PdfDictionary,
  key : Bytes,
  count : Int,
  fallback : Array[Double],
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => fallback.copy()
    Some(value) =>
      require_number_array(
        value,
        count,
        offset,
        @objects.PdfName::new(key).to_text(),
      )
  }
}

///|
fn require_number_array(
  object : @objects.PdfObject,
  count : Int,
  offset : Int64,
  label : String,
) -> Array[Double] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => {
      if values.length() != count {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset,
          label + " array has invalid length",
        )
      }
      let output : Array[Double] = []
      for value in values {
        output.push(colour_object_number(value, offset, label))
      }
      output
    }
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be an array",
      )
  }
}

///|
fn validate_range_pairs(
  values : Array[Double],
  offset : Int64,
  label : String,
) -> Unit raise PdfGraphicsError {
  let mut index = 0
  while index < values.length() {
    if values[index] > values[index + 1] {
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " lower bound must not exceed upper bound",
      )
    }
    index = index + 2
  }
}

///|
fn require_dictionary(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> @objects.PdfDictionary raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be a dictionary",
      )
  }
}

///|
fn optional_dictionary_from_dict(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> @objects.PdfDictionary? raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => None
    Some(@objects.PdfObject::Dictionary(value)) => Some(value)
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() + " must be a dictionary",
      )
  }
}

///|
fn optional_name_from_dict(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> @objects.PdfName? raise PdfGraphicsError {
  match dict.get(@objects.PdfName::new(key)) {
    None => None
    Some(@objects.PdfObject::Name(value)) => Some(value)
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        @objects.PdfName::new(key).to_text() + " must be a name",
      )
  }
}

///|
fn require_integer(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Int64 raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Integer(value) => value
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be an integer",
      )
  }
}

///|
fn require_name(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> @objects.PdfName raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(value) => value
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be a name",
      )
  }
}

///|
fn require_name_array(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[@objects.PdfName] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => {
      let names : Array[@objects.PdfName] = []
      for value in values {
        names.push(require_name(value, offset, label))
      }
      names
    }
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be an array of names",
      )
  }
}

///|
fn colour_object_number(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        label + " must be a number",
      )
  }
}
