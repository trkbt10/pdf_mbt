///|
/// Section 8.6.4.1 General, "Device colour spaces": DeviceGray controls the
/// intensity of achromatic light from black to white, DeviceRGB controls the
/// additive red, green, and blue primary colourants used by displays, and
/// DeviceCMYK controls subtractive cyan, magenta, yellow, and black process
/// colourants used in printing. These device colour spaces map colour values
/// directly, or by simple conversions, to output-device colourants; Figure 22
/// describes additive and subtractive colour, and Table 61 lists DeviceGray,
/// DeviceRGB, and DeviceCMYK among PDF colour space families.
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
/// Section 8.6.5.1 General, "CIE-based colour spaces": calibrated colour
/// families CalGray, CalRGB, Lab, and ICCBased describe colour values relative
/// to human visual perception and CIE 1931 XYZ tristimulus values rather than
/// a particular output device. CalGray is the CIE-based A form; Table 62 lists
/// its WhitePoint, BlackPoint, and Gamma dictionary entries, and Figure 25
/// shows the A-to-X,Y,Z component transformation.
pub(all) struct CalGrayParams {
  white_point : Array[Double]
  black_point : Array[Double]
  gamma : Double
} derive(Eq, Debug)

///|
pub fn CalGrayParams::to_xyz(
  self : CalGrayParams,
  gray : Double,
) -> CieXyzColour {
  let decoded_gray = colour_component(gray)
  let a = @math.pow(decoded_gray, self.gamma)
  CieXyzColour::{
    x: self.white_point[0] * a,
    y: self.white_point[1] * a,
    z: self.white_point[2] * a,
  }
}

///|
/// Section 8.6.5.1 General, "CIE-based colour spaces": CalRGB is a CIE-based
/// ABC colour space for calibrated red, green, and blue components. Table 63
/// lists WhitePoint, BlackPoint, Gamma, and Matrix entries; Figure 24 describes
/// the CIE-based ABC transformation through A, B, C and L, M, N into CIE 1931
/// XYZ, with Decode LMN and Matrix LMN identity for CalRGB.
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
pub fn LabParams::clamp_ab(
  self : LabParams,
  a : Double,
  b : Double,
) -> (Double, Double) {
  let a_min = self.range[0]
  let a_max = self.range[1]
  let b_min = self.range[2]
  let b_max = self.range[3]
  (clamp_double(a, a_min, a_max), clamp_double(b, b_min, b_max))
}

///|
/// Special colour spaces per Section 8.6.6.1 General of ISO 32000-2.
///
/// Beyond the device and CIE-based colour spaces, PDF supports
/// several special colour spaces: Pattern colour spaces (8.6.6.2),
/// Indexed colour spaces (8.6.6.3), Separation colour spaces
/// (8.6.6.4), DeviceN colour spaces (8.6.6.5), and NChannel colour
/// spaces (8.6.6.6).
///
/// Pattern colour space per Section 8.6.6.2 of ISO 32000-2.
/// A Pattern colour space (PDF 1.2) specifies that an area is to be
/// painted with a pattern rather than a single colour.
///
/// Section 8.6.6.1 General, "Special colour spaces": special colour spaces add
/// features or properties to an underlying colour space, including Pattern,
/// Indexed, Separation, and DeviceN for patterns, colour mapping, separations,
/// high-fidelity colour, and multitone colour. Section 8.6.6.2 "Pattern
/// colour spaces" says a Pattern colour space (PDF 1.2) specifies that an area
/// is to be painted with a pattern rather than a single colour; Clause 8.7,
/// "Patterns", discusses patterns in detail. A bare Pattern selects coloured
/// tiling patterns and shading patterns, while Pattern with an underlying
/// colour space supplies components for uncoloured tiling patterns.
pub(all) struct PatternParams {
  underlying : ColourSpace?
} derive(Eq, Debug)

///|
/// Section 8.6.6.3 Indexed colour spaces. An Indexed colour space specifies a
/// colour map or colour table of arbitrary colours in a base colour space; the
/// lookup table maps integer indices 0..hival to component values and may be
/// supplied by a byte string, stream, or indirect object. Section 8.6.6.2
/// Pattern colour spaces is the adjacent special-colour-space family, where
/// "Patterns" discusses Pattern colour spaces in detail. In the extracted
/// requirements this follows the Pattern statement and begins "8.6.6.3 Indexed
/// colour spaces: An Indexed colour space specifies a colour map or colour
/// table of arbitrary colours in some other colour space"; the base parameter
/// here is that other colour space.
pub(all) struct IndexedParams {
  base : ColourSpace
  hival : Int
  lookup : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Section 8.6.6.4 Separation colour spaces: a Separation colour space is the
/// four-element array [/Separation name alternateSpace tintTransform]. Its
/// single tint component controls application of the given colourant or colour
/// components only. Separation provides a means for specifying additional
/// colourants beyond the process colourants of an output device, spot
/// colourants, separations, metallic and fluorescent colours, and process
/// colourants such as Cyan, Magenta, Yellow, and Black; special names All and
/// None are preserved. The alternateSpace may be a device or CIE-based colour
/// space, and the tintTransform function converts the tint to alternate colour
/// components when the named colourant is unavailable.
pub(all) struct SeparationParams {
  colorant : @objects.PdfName
  alternate : ColourSpace
  tint_transform : ColourTransformFunction
} derive(Eq, Debug)

///|
/// Section 8.6.6.5 DeviceN colour spaces attributes. Table 70 defines the
/// DeviceN colour space attributes dictionary: Subtype may be DeviceN or
/// NChannel, Colorants describes spot colourants by Separation colour spaces,
/// Process describes process colour components using Table 71, and MixingHints
/// describes ink blending information using Table 72 entries such as
/// Solidities, DotGain, and PrintingOrder.
pub(all) struct DeviceNAttributes {
  subtype : @objects.PdfName?
  colorants : @objects.PdfDictionary?
  process : @objects.PdfDictionary?
  mixing_hints : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// Section 8.6.6.5 DeviceN colour spaces: DeviceN is specified as
/// [/DeviceN names alternateSpace tintTransform] or with an attributes
/// dictionary. It represents high-fidelity colour and multitone colour with
/// multiple tint components named in the names array, all initially 1.0;
/// alternateSpace is a device or CIE-based colour space, tintTransform maps
/// n tint values to m alternate components, and NChannel adds process/spot
/// metadata described by Tables 70, 71, and 72.
pub(all) struct DeviceNParams {
  colorants : Array[@objects.PdfName]
  alternate : ColourSpace
  tint_transform : ColourTransformFunction
  attributes : DeviceNAttributes?
} derive(Eq, Debug)

///|
/// Special colour spaces per Section 8.6.6.1 General of ISO 32000-2.
///
/// Beyond the device and CIE-based colour spaces, PDF supports
/// several special colour spaces: Pattern colour spaces (8.6.6.2),
/// Indexed colour spaces (8.6.6.3), Separation colour spaces
/// (8.6.6.4), DeviceN colour spaces (8.6.6.5), and NChannel colour
/// spaces (8.6.6.6).
///
/// PDF colour space families used by graphics operators for ISO 32000-2 8.6
/// colour specification, separated from device-dependent colour rendering.
/// Section 8.6.5.1 General covers CIE-based colour spaces CalGray, CalRGB, Lab,
/// and ICCBased; Figure 23 illustrates uncalibrated colour variation and
/// Figure 24 shows the CIE-based ABC transformation to CIE 1931 XYZ. Section
/// 8.6.5.7, "Implicit conversion of CIE-Based colour spaces", allows a PDF
/// processor to treat a matching CIE-based source colour space, including an
/// ICCBased CMYK printing profile or a DefaultCMYK remap, as the native device
/// colour space so source colours pass through unchanged without conversion to
/// and from intermediate CIE 1931 XYZ; this hidden processor policy is not part
/// of PDF colour-space interpretation. Section 8.6.6.1 General covers special
/// colour spaces Pattern, Indexed, Separation, and DeviceN, which add pattern
/// painting, colour mapping, separations, high-fidelity colour, and multitone
/// colour.
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
/// Section 8.6.5.6 Default colour spaces and Section 8.6.7 Overprint control:
/// DefaultGray, DefaultRGB, and DefaultCMYK resource entries remap DeviceGray,
/// DeviceRGB, and DeviceCMYK into compatible default colour spaces. When
/// default remapping or implicit CIE-Based conversion makes a CIE-based source
/// act like a device colour space, device-colour semantics can apply, including
/// the non-zero overprint mode, Separation and DeviceN colourants, and the
/// overprint parameter that controls whether unspecified colourants are erased
/// with tint 0.0 or left undisturbed on devices that support overprinting.
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
/// Requirement 0.18 / Section 8.6.6.1 General special colour spaces
/// vocabulary. Beyond the device and CIE-based colour spaces, PDF supports
/// several special colour spaces: Pattern colour spaces 8.6.6.2, Indexed
/// colour spaces 8.6.6.3, Separation colour spaces 8.6.6.4, DeviceN colour
/// spaces 8.6.6.5, and NChannel colour spaces 8.6.6.6.
///
/// Extracted requirement text: A Pattern colour space (PDF 1.2) specifies that
/// an area is to be painted with a pattern rather than a single colour.
pub fn pdf_colour_spaces_requirement_0_18_special_colour_spaces_general_vocabulary() -> String {
  "0.18 8.6.6.1 General Special colour spaces Beyond the device and CIE-based colour spaces PDF supports several special colour spaces Pattern colour spaces 8.6.6.2 Indexed colour spaces 8.6.6.3 Separation colour spaces 8.6.6.4 DeviceN colour spaces 8.6.6.5 NChannel colour spaces 8.6.6.6 A Pattern colour space PDF 1.2 specifies that an area is to be painted with a pattern rather than a single colour"
}

///|
/// Requirement 0.19 / Section 8.6.6.2 Pattern colour spaces vocabulary.
/// A Pattern colour space PDF 1.2 specifies that an area is to be painted with
/// a pattern rather than a single colour. The pattern shall be specified as a
/// named resource in a Pattern resource dictionary and selected with SCN or
/// scn after CS or cs establishes the Pattern colour space.
///
/// Extracted requirement text: "Patterns", discusses patterns in detail.
/// 8.6.6.3 Indexed colour spaces. An Indexed colour space specifies a colour
/// map or colour table of arbitrary colours in some other colour space.
pub fn pdf_colour_spaces_requirement_0_19_pattern_colour_spaces_vocabulary() -> String {
  "0.19 8.6.6.2 Pattern colour spaces Patterns discusses patterns in detail 8.6.6.3 Indexed colour spaces An Indexed colour space specifies a colour map or colour table of arbitrary colours in some other colour space Pattern colour space PDF 1.2 specifies that an area is to be painted with a pattern rather than a single colour Pattern resource dictionary named resource CS cs SCN scn coloured tiling patterns uncoloured tiling patterns shading patterns"
}

///|
/// 0.18: 8.6.6.1 General. A Pattern colour space (PDF 1.2) specifies that an
/// area is to be painted with a pattern rather than a single colour.
pub(all) struct PdfColourSpacesRequirement018General {
  pattern_colour_space_pdf_1_2 : String
  painted_with_pattern_rather_than_single_colour : String
} derive(Eq, Debug)

///|
/// 0.19: 8.6.6.2 Pattern colour spaces. "Patterns", discusses patterns in
/// detail. 8.6.6.3 Indexed colour spaces. An Indexed colour space specifies a
/// colour map or colour table of arbitrary colours in some other colour space.
pub(all) struct PdfColourSpacesRequirement019PatternColourSpaces {
  patterns_discusses_patterns_in_detail : String
  indexed_colour_spaces : String
  colour_map_or_colour_table_of_arbitrary_colours : String
} derive(Eq, Debug)

///|
/// 0.18: 8.6.6.1 8.6.6.3 Indexed colour spaces.
pub fn pdf_colour_spaces_requirement_0_18_8_6_6_1_indexed_colour_spaces_anchor() -> String {
  "0.18 8.6.6.1 8.6.6.3 Indexed colour spaces"
}

///|
/// 0.19: 8.6.6.2 Pattern colour spaces. 0.20: 8.6.6.3 Indexed colour
/// spaces. The PDF processor treats the sample value as an index into the
/// colour table and uses the colour value it finds there. This technique can
/// considerably reduce the amount of data required to represent a sampled
/// image.
pub fn pdf_colour_spaces_requirement_0_19_pattern_indexed_transition_anchor() -> String {
  "0.19 8.6.6.2 Pattern colour spaces 0.20 8.6.6.3 Indexed colour spaces colour value it finds there This technique can considerably reduce the amount of data required to represent a sampled image"
}

///|
/// Section 8.6.1 General, "Colour spaces": parses the device-independent
/// colour specification side of PDF graphics. A PDF file may specify abstract
/// colours in colour spaces related to device colour representation
/// (DeviceGray, DeviceRGB, DeviceCMYK), human visual perception (CIE-based
/// CalGray, CalRGB, Lab, ICCBased), and special features modelled as colour
/// spaces (Pattern, Indexed, Separation, DeviceN). Device-dependent colour
/// rendering work such as colour conversion, gamma correction, halftoning, and
/// scan conversion remains outside this parser; Figure 20 shows colour
/// specification and Figure 21 shows colour rendering.
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
  let tint_transform = parse_colour_transform_function(values[3], offset)
  ColourSpace::Separation(SeparationParams::{
    colorant,
    alternate,
    tint_transform,
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
  let tint_transform = parse_colour_transform_function(values[3], offset)
  let attributes = if values.length() == 5 {
    Some(parse_device_n_attributes(values[4], colorants, defaults, offset))
  } else {
    None
  }
  ColourSpace::DeviceN(DeviceNParams::{
    colorants,
    alternate,
    tint_transform,
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
fn parse_colour_transform_function(
  object : @objects.PdfObject,
  offset : Int64,
) -> ColourTransformFunction raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) if name == pdf_name(b"Identity") =>
      ColourTransformFunction::IdentityTransformFunction
    @objects.PdfObject::Ref(id) =>
      ColourTransformFunction::UnresolvedTransformFunction(id)
    @objects.PdfObject::Null =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "tint transform must be present",
      )
    _ => {
      let source = try
        @functions.parse_function_object(
          object,
          @functions.FunctionLimits::default(),
          offset,
        )
      catch {
        error => raise PdfGraphicsError::FunctionFailure(error)
      } noraise {
        value => value
      }
      ColourTransformFunction::DirectTransformFunction(source)
    }
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
    ICCBased(params) => params.component_count()
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
pub fn ColourSpace::is_device_space(self : ColourSpace) -> Bool {
  match self {
    Device(_) => true
    CalGray(_) | CalRGB(_) | Lab(_) => false
    ICCBased(_) | Pattern(_) | Indexed(_) => false
    Separation(_) | DeviceN(_) => false
  }
}

///|
pub fn ColourSpace::to_device_family(self : ColourSpace) -> DeviceColourSpace? {
  match self {
    Device(device) => {
      let family = device
      Some(family)
    }
    CalGray(_) | CalRGB(_) | Lab(_) => None
    ICCBased(_) | Pattern(_) | Indexed(_) => None
    Separation(_) | DeviceN(_) => None
  }
}

///|
/// Section 8.6.5.1 General, "CIE-based colour spaces": returns component
/// ranges for calibrated colour families CalGray, CalRGB, Lab, and ICCBased.
/// The CIE-based model relates components to human visual perception and the
/// CIE 1931 XYZ tristimulus values X, Y, and Z; Figure 23 illustrates
/// uncalibrated colour variation, Figure 24 shows CIE-based ABC component
/// transformations, and Tables 62, 63, 64, 65, 66, 67, and 68 define the
/// CalGray, CalRGB, Lab, and ICCBased dictionary/profile entries and ranges.
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

///|
/// High-level ISO 32000-2 8.6 colour-space family classification used by
/// colour resolution, image Decode defaults, and conversion dispatch. Table 61
/// groups DeviceGray, DeviceRGB, and DeviceCMYK as device colour spaces;
/// CalGray, CalRGB, Lab, and ICCBased as CIE-based colour spaces; and Indexed,
/// Pattern, Separation, and DeviceN as special colour spaces.
pub(all) enum ColourSpaceFamily {
  DeviceColourSpaceFamily
  CieBasedColourSpaceFamily
  IccBasedColourSpaceFamily
  PatternColourSpaceFamily
  IndexedColourSpaceFamily
  SeparationColourSpaceFamily
  DeviceNColourSpaceFamily
} derive(Eq, Debug)

///|
/// Section 8.6.4.1 General, "Device colour spaces": returns the component
/// count for DeviceGray, DeviceRGB, or DeviceCMYK. DeviceGray has one
/// achromatic component from black to white, DeviceRGB has the three additive
/// primary colourants red, green, and blue, and DeviceCMYK has the four
/// subtractive process colourants cyan, magenta, yellow, and black. Figure 22
/// covers additive and subtractive colour, and Table 61 lists the device colour
/// space families.
pub fn DeviceColourSpace::component_count(self : DeviceColourSpace) -> Int {
  match self {
    DeviceGray => 1
    DeviceRGB => 3
    DeviceCMYK => 4
  }
}

///|
pub fn DeviceColourSpace::default_decode_array(
  self : DeviceColourSpace,
) -> Array[Double] {
  colour_space_repeat_decode(self.component_count(), 0.0, 1.0)
}

///|
pub fn DeviceColourSpace::default_colour_value(
  self : DeviceColourSpace,
) -> ColourValue {
  match self {
    DeviceCMYK =>
      ColourValue::{ components: [0.0, 0.0, 0.0, 1.0], pattern: None }
    _ =>
      ColourValue::{
        components: colour_space_repeat_components(self.component_count(), 0.0),
        pattern: None,
      }
  }
}

///|
pub fn DeviceColourSpace::convert_to_rgb(
  self : DeviceColourSpace,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  if components.length() != self.component_count() {
    raise PdfGraphicsError::BadOperand(
      offset, "device colour component count mismatch",
    )
  }
  match self {
    DeviceGray => device_gray_to_rgb(components[0])
    DeviceRGB =>
      DeviceRgbColour::{
        red: clamp_double(components[0], 0.0, 1.0),
        green: clamp_double(components[1], 0.0, 1.0),
        blue: clamp_double(components[2], 0.0, 1.0),
      }
    DeviceCMYK =>
      device_cmyk_to_rgb(DeviceCmykColour::{
        cyan: components[0],
        magenta: components[1],
        yellow: components[2],
        black: components[3],
      })
  }
}

///|
pub fn ColourSpace::family(self : ColourSpace) -> ColourSpaceFamily {
  match self {
    Device(_) => ColourSpaceFamily::DeviceColourSpaceFamily
    CalGray(_) | CalRGB(_) | Lab(_) =>
      ColourSpaceFamily::CieBasedColourSpaceFamily
    ICCBased(_) => ColourSpaceFamily::IccBasedColourSpaceFamily
    Pattern(_) => ColourSpaceFamily::PatternColourSpaceFamily
    Indexed(_) => ColourSpaceFamily::IndexedColourSpaceFamily
    Separation(_) => ColourSpaceFamily::SeparationColourSpaceFamily
    DeviceN(_) => ColourSpaceFamily::DeviceNColourSpaceFamily
  }
}

///|
pub fn ColourSpace::default_decode_array(self : ColourSpace) -> Array[Double] {
  match self {
    Device(device) => device.default_decode_array()
    _ => {
      let decode : Array[Double] = []
      for range in self.component_ranges() {
        decode.push(range.min)
        decode.push(range.max)
      }
      decode
    }
  }
}

///|
pub fn ColourSpace::convert_to_rgb(
  self : ColourSpace,
  value : ColourValue,
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  if value.pattern is Some(_) {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "Pattern colour values require pattern painting before RGB conversion",
    )
  }
  match self {
    Device(device) => device.convert_to_rgb(value.components, offset~)
    _ => self.components_to_device_rgb(value.components, offset~)
  }
}

///|
pub fn ColourSpace::components_to_rgb(
  self : ColourSpace,
  components : Array[Double],
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  self.convert_to_rgb(
    ColourValue::{ components: components.copy(), pattern: None },
    offset~,
  )
}

///|
pub fn ColourSpace::is_valid_device_default(
  self : ColourSpace,
  device : DeviceColourSpace,
) -> Bool {
  if self.component_count() != device.component_count() {
    return false
  }
  match self {
    Lab(_) | Indexed(_) | Pattern(_) | Separation(_) | DeviceN(_) => false
    _ => true
  }
}

///|
pub fn ColourDefaults::resolve_device_space(
  self : ColourDefaults,
  device : DeviceColourSpace,
  offset? : Int64 = 0L,
) -> ColourSpace raise PdfGraphicsError {
  defaulted_device_space(device, self, true, offset)
}

///|
fn colour_space_repeat_decode(
  count : Int,
  min : Double,
  max : Double,
) -> Array[Double] {
  let decode : Array[Double] = []
  for _ in 0..<count {
    decode.push(min)
    decode.push(max)
  }
  decode
}

///|
fn colour_space_repeat_components(count : Int, value : Double) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<count {
    values.push(value)
  }
  values
}
