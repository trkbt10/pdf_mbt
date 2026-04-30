///|
pub(all) enum HalftoneDefinition {
  TypeOneHalftone(TypeOneHalftone)
  TypeSixteenHalftone(TypeSixteenHalftone)
} derive(Eq, Debug)

///|
pub(all) struct TypeOneHalftone {
  screen : HalftoneScreen
  accurate_screens : Bool
  transfer_function : @graphics.ColourTransformFunction?
} derive(Eq, Debug)

///|
pub(all) struct TypeSixteenHalftone {
  primary_thresholds : ThresholdArray
  secondary_thresholds : ThresholdArray?
  transfer_function : @graphics.ColourTransformFunction?
} derive(Eq, Debug)

///|
pub fn parse_halftone_object(
  object : @objects.PdfObject,
  limits? : RenderLimits = RenderLimits::default(),
  offset? : Int64 = 0L,
) -> HalftoneDefinition raise PdfRenderingError {
  match object {
    @objects.PdfObject::Dictionary(dict) =>
      parse_halftone_dictionary(dict, offset)
    @objects.PdfObject::Stream(stream) =>
      parse_halftone_stream(stream, limits, offset)
    @objects.PdfObject::Ref(_) =>
      raise PdfRenderingError::InvalidResource(
        "halftone indirect references must be resolved before rendering",
      )
    _ =>
      raise PdfRenderingError::InvalidResource(
        "halftone object must be a dictionary or stream",
      )
  }
}

///|
pub fn TypeOneHalftone::generate_threshold_array(
  self : TypeOneHalftone,
  width : Int,
  height : Int,
  bits_per_sample? : Int = 8,
  limits? : RenderLimits = RenderLimits::default(),
) -> ThresholdArray raise PdfRenderingError {
  self.screen.generate_threshold_array(width, height, bits_per_sample~, limits~)
}

///|
fn parse_halftone_dictionary(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> HalftoneDefinition raise PdfRenderingError {
  match require_ht_int(dict, b"HalftoneType", offset) {
    1 => TypeOneHalftone(parse_type_one_halftone(dict, offset))
    16 =>
      raise PdfRenderingError::InvalidResource(
        "Type 16 halftones must be streams containing threshold bytes",
      )
    value =>
      raise PdfRenderingError::UnsupportedCapability(
        "halftone type " + value.to_string() + " is not supported",
      )
  }
}

///|
fn parse_halftone_stream(
  stream : @objects.PdfStream,
  limits : RenderLimits,
  offset : Int64,
) -> HalftoneDefinition raise PdfRenderingError {
  match require_ht_int(stream.dict, b"HalftoneType", offset) {
    16 =>
      TypeSixteenHalftone(parse_type_sixteen_halftone(stream, limits, offset))
    1 => TypeOneHalftone(parse_type_one_halftone(stream.dict, offset))
    value =>
      raise PdfRenderingError::UnsupportedCapability(
        "halftone type " + value.to_string() + " is not supported",
      )
  }
}

///|
fn parse_type_one_halftone(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> TypeOneHalftone raise PdfRenderingError {
  TypeOneHalftone::{
    screen: HalftoneScreen::new(
      require_ht_number(dict, b"Frequency", offset),
      require_ht_number(dict, b"Angle", offset),
      parse_spot_function(
        require_ht_object(dict, b"SpotFunction", offset),
        offset,
      ),
    ),
    accurate_screens: optional_ht_bool(dict, b"AccurateScreens", false),
    transfer_function: optional_ht_transfer(dict),
  }
}

///|
fn parse_type_sixteen_halftone(
  stream : @objects.PdfStream,
  limits : RenderLimits,
  offset : Int64,
) -> TypeSixteenHalftone raise PdfRenderingError {
  let width = require_ht_int(stream.dict, b"Width", offset)
  let height = require_ht_int(stream.dict, b"Height", offset)
  let width2 = optional_ht_int(stream.dict, b"Width2", offset)
  let height2 = optional_ht_int(stream.dict, b"Height2", offset)
  if (width2 is Some(_)) != (height2 is Some(_)) {
    raise PdfRenderingError::InvalidResource(
      "Type 16 Width2 and Height2 must be present together",
    )
  }
  let primary_count = width * height
  let secondary_count = match (width2, height2) {
    (Some(w2), Some(h2)) => w2 * h2
    _ => 0
  }
  let decoded = decode_ht_stream(stream)
  if decoded.length() != (primary_count + secondary_count) * 2 {
    raise PdfRenderingError::InvalidResource(
      "Type 16 threshold stream length does not match rectangle dimensions",
    )
  }
  let primary = ThresholdArray::{
    width,
    height,
    bits_per_sample: 16,
    values: read_ht_u16(decoded, 0, primary_count),
  }
  primary.validate()
  let secondary = match (width2, height2) {
    (Some(w2), Some(h2)) => {
      let second = ThresholdArray::{
        width: w2,
        height: h2,
        bits_per_sample: 16,
        values: read_ht_u16(decoded, primary_count * 2, secondary_count),
      }
      second.validate()
      Some(second)
    }
    _ => None
  }
  let total_bytes = (primary_count + secondary_count) * 2
  if total_bytes > limits.max_threshold_bytes {
    raise PdfRenderingError::LimitExceeded(
      "threshold bytes",
      total_bytes,
      limits.max_threshold_bytes,
    )
  }
  TypeSixteenHalftone::{
    primary_thresholds: primary,
    secondary_thresholds: secondary,
    transfer_function: optional_ht_transfer(stream.dict),
  }
}

///|
fn parse_spot_function(
  object : @objects.PdfObject,
  offset : Int64,
) -> SpotFunction raise PdfRenderingError {
  match object {
    @objects.PdfObject::Name(name) => spot_from_name(name, offset)
    @objects.PdfObject::Array(values) => {
      for value in values {
        if value is @objects.PdfObject::Name(name) {
          try spot_from_name(name, offset) catch {
            _ => ()
          } noraise {
            spot => return spot
          }
        }
      }
      raise PdfRenderingError::UnsupportedCapability(
        "SpotFunction array contains no recognized spot function name",
      )
    }
    _ =>
      raise PdfRenderingError::UnsupportedCapability(
        "direct SpotFunction function objects are not evaluated by the basic renderer",
      )
  }
}

///|
fn spot_from_name(
  name : @objects.PdfName,
  offset : Int64,
) -> SpotFunction raise PdfRenderingError {
  if name == ht_name(b"SimpleDot") {
    SimpleDot
  } else if name == ht_name(b"InvertedSimpleDot") {
    InvertedSimpleDot
  } else if name == ht_name(b"CosineDot") {
    CosineDot
  } else if name == ht_name(b"Line") {
    Line
  } else if name == ht_name(b"LineX") {
    LineX
  } else if name == ht_name(b"LineY") {
    LineY
  } else if name == ht_name(b"Round") {
    Round
  } else {
    raise PdfRenderingError::UnsupportedCapability(
      "unrecognized spot function at offset " + offset.to_string(),
    )
  }
}

///|
fn optional_ht_transfer(
  dict : @objects.PdfDictionary,
) -> @graphics.ColourTransformFunction? raise PdfRenderingError {
  match dict.get(ht_name(b"TransferFunction")) {
    None => None
    Some(@objects.PdfObject::Name(name)) =>
      if name == ht_name(b"Identity") {
        Some(@graphics.ColourTransformFunction::IdentityTransformFunction)
      } else {
        raise PdfRenderingError::UnsupportedCapability(
          "unsupported named halftone transfer function",
        )
      }
    Some(value) =>
      Some(
        @graphics.ColourTransformFunction::DirectTransformFunction(
          try
            @functions.parse_function_object(
              value,
              @functions.FunctionLimits::default(),
              0L,
            )
          catch {
            _ =>
              raise PdfRenderingError::ProviderFailure(
                "halftone", "transfer function could not be parsed",
              )
          } noraise {
            source => source
          },
        ),
      )
  }
}

///|
fn decode_ht_stream(
  stream : @objects.PdfStream,
) -> Bytes raise PdfRenderingError {
  try @filters.decode_stream(stream) catch {
    _ =>
      raise PdfRenderingError::ProviderFailure(
        "halftone stream", "threshold stream could not be decoded",
      )
  } noraise {
    bytes => bytes
  }
}

///|
fn read_ht_u16(bytes : Bytes, start : Int, count : Int) -> Array[Int] {
  let values : Array[Int] = []
  for index in 0..<count {
    values.push(
      bytes[start + index * 2].to_int() * 256 +
      bytes[start + index * 2 + 1].to_int(),
    )
  }
  values
}

///|
fn require_ht_object(
  dict : @objects.PdfDictionary,
  key : Bytes,
  _offset : Int64,
) -> @objects.PdfObject raise PdfRenderingError {
  match dict.get(ht_name(key)) {
    Some(value) => value
    None =>
      raise PdfRenderingError::InvalidResource(
        "halftone dictionary requires " + ht_name(key).to_text(),
      )
  }
}

///|
fn require_ht_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Int raise PdfRenderingError {
  match require_ht_object(dict, key, offset) {
    @objects.PdfObject::Integer(value) => value.to_int()
    _ =>
      raise PdfRenderingError::InvalidResource(
        ht_name(key).to_text() + " must be an integer",
      )
  }
}

///|
fn optional_ht_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Int? raise PdfRenderingError {
  match dict.get(ht_name(key)) {
    None => None
    Some(_) => Some(require_ht_int(dict, key, offset))
  }
}

///|
fn require_ht_number(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Double raise PdfRenderingError {
  match require_ht_object(dict, key, offset) {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise PdfRenderingError::InvalidResource(
        ht_name(key).to_text() + " must be a number",
      )
  }
}

///|
fn optional_ht_bool(
  dict : @objects.PdfDictionary,
  key : Bytes,
  fallback : Bool,
) -> Bool raise PdfRenderingError {
  match dict.get(ht_name(key)) {
    None => fallback
    Some(@objects.PdfObject::Boolean(value)) => value
    Some(_) =>
      raise PdfRenderingError::InvalidResource(
        ht_name(key).to_text() + " must be a boolean",
      )
  }
}

///|
fn ht_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}
