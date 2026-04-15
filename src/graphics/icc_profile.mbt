///|
/// ICCBased profile header summary. PDF 2.0 uses ICC.1:2010
/// (ISO 15076-1:2010) as listed in Table 66, and graphics source profiles are
/// constrained by Table 67 profile types: deviceClass must be scnr, mntr,
/// prtr, or spac, and colorSpace must be GRAY, RGB, CMYK, or Lab.
pub(all) struct IccProfileInfo {
  component_count : Int
  data_colour_space : @objects.PdfName
  decoded_length : Int
  rendering_intent : RenderingIntent
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
pub fn IccBasedParams::from_profile_header(bytes : Bytes) -> IccBasedParams {
  let signature = read_signature_or(bytes, 16, b"")
  let component_count = icc_signature_component_count_or_zero(signature)
  let rendering_intent = icc_rendering_intent_or_default(
    read_u32_be_or(bytes, 64, 1L),
  )
  let info = IccProfileInfo::{
    component_count,
    data_colour_space: @objects.PdfName::new(signature),
    decoded_length: bytes.length(),
    rendering_intent,
  }
  IccBasedParams::{
    source: IccProfileSource::DirectProfile(info),
    component_count,
    range: default_icc_ranges(component_count),
    alternate: None,
    metadata: None,
  }
}

///|
pub fn IccBasedParams::component_count(self : IccBasedParams) -> Int {
  let declared_count = self.component_count
  match self.source {
    DirectProfile(info) =>
      if info.component_count > 0 {
        info.component_count
      } else {
        declared_count
      }
    IndirectProfile(_) => declared_count
  }
}

///|
pub fn IccBasedParams::detected_component_count(self : IccBasedParams) -> Int {
  match self.source {
    DirectProfile(info) => info.component_count
    IndirectProfile(_) => self.component_count
  }
}

///|
fn validate_icc_based_stream(
  stream : @objects.PdfStream,
  defaults : ColourDefaults,
  offset : Int64,
) -> IccBasedParams raise PdfGraphicsError {
  let component_count = match stream.dict.get(@objects.PdfName::new(b"N")) {
    Some(@objects.PdfObject::Integer(value)) => {
      if value != 1L && value != 3L && value != 4L {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "ICCBased N must be 1, 3, or 4",
        )
      }
      value.to_int()
    }
    Some(_) =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICCBased N entry must be an integer",
      )
    None =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICCBased profile stream requires N",
      )
  }
  let alternate = match stream.dict.get(@objects.PdfName::new(b"Alternate")) {
    None => None
    Some(value) => {
      let space = parse_colour_space_object(value, defaults, offset)
      if space.component_count() != component_count {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "ICCBased Alternate component count must match N",
        )
      }
      match space {
        Pattern(_) | Indexed(_) | Separation(_) | DeviceN(_) =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "ICCBased Alternate cannot be a special colour space",
          )
        _ => Some(space)
      }
    }
  }
  let ranges = match stream.dict.get(@objects.PdfName::new(b"Range")) {
    None => default_icc_ranges(component_count)
    Some(value) => parse_icc_ranges(value, component_count, offset)
  }
  let metadata = match stream.dict.get(@objects.PdfName::new(b"Metadata")) {
    None => None
    Some(value) =>
      match value {
        @objects.PdfObject::Stream(_) => Some(value)
        _ =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "ICCBased Metadata must be a stream",
          )
      }
  }
  let info = validate_icc_profile_stream(stream, offset)
  if info.component_count != component_count {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICCBased N does not match ICC profile header colour space",
    )
  }
  IccBasedParams::{
    source: IccProfileSource::DirectProfile(info),
    component_count,
    range: ranges,
    alternate,
    metadata,
  }
}

///|
/// Validates a direct ICCBased profile stream header for PDF colour spaces.
/// The decoded ICC header must be at least 128 bytes, its declared profile
/// size must fit the decoded stream, and its ICC.1:2010 (ISO 15076-1:2010)
/// Table 67 profile type fields must be permitted for graphics source colours.
pub fn validate_icc_profile_stream(
  stream : @objects.PdfStream,
  offset : Int64,
) -> IccProfileInfo raise PdfGraphicsError {
  let decoded = decode_colour_stream(stream, offset)
  let header = parse_icc_profile_header(decoded, offset)
  IccProfileInfo::{
    component_count: header.component_count,
    data_colour_space: header.data_colour_space,
    decoded_length: decoded.length(),
    rendering_intent: header.rendering_intent,
  }
}

///|
fn decode_colour_stream(
  stream : @objects.PdfStream,
  offset : Int64,
) -> Bytes raise PdfGraphicsError {
  try @filters.decode_stream(stream) catch {
    error =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset,
        "failed to decode colour stream: " + filter_error_label(error),
      )
  } noraise {
    bytes => bytes
  }
}

///|
fn filter_error_label(error : @filters.PdfFilterError) -> String {
  match error {
    InvalidFilterSpec(message) => message
    InvalidDecodeParms(name, message) => name + ": " + message
    UnsupportedFilter(name) => "unsupported filter " + name
    DecodeError(name, message) => name + ": " + message
  }
}

///|
fn default_icc_ranges(component_count : Int) -> Array[ColourRange] {
  let ranges : Array[ColourRange] = []
  for _ in 0..<component_count {
    ranges.push(ColourRange::{ min: 0.0, max: 1.0 })
  }
  ranges
}

///|
fn parse_icc_ranges(
  object : @objects.PdfObject,
  component_count : Int,
  offset : Int64,
) -> Array[ColourRange] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => {
      if values.length() != component_count * 2 {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "ICCBased Range length must be twice N",
        )
      }
      let ranges : Array[ColourRange] = []
      let mut index = 0
      while index < values.length() {
        let min = icc_range_number(values[index], offset)
        let max = icc_range_number(values[index + 1], offset)
        if min > max {
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "ICCBased Range lower bound must not exceed upper bound",
          )
        }
        ranges.push(ColourRange::{ min, max })
        index = index + 2
      }
      ranges
    }
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICCBased Range must be an array",
      )
  }
}

///|
fn icc_range_number(
  object : @objects.PdfObject,
  offset : Int64,
) -> Double raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICCBased Range entries must be numbers",
      )
  }
}

///|
fn read_u32_be(data : Bytes, start : Int) -> Int64 {
  (data[start].to_int64() << 24) |
  (data[start + 1].to_int64() << 16) |
  (data[start + 2].to_int64() << 8) |
  data[start + 3].to_int64()
}

///|
fn read_signature(data : Bytes, start : Int) -> Bytes {
  Bytes::from_array([
    data[start],
    data[start + 1],
    data[start + 2],
    data[start + 3],
  ])
}

///|
fn read_u32_be_or(data : Bytes, start : Int, fallback : Int64) -> Int64 {
  if start < 0 || start + 4 > data.length() {
    fallback
  } else {
    read_u32_be(data, start)
  }
}

///|
fn read_signature_or(data : Bytes, start : Int, fallback : Bytes) -> Bytes {
  if start < 0 || start + 4 > data.length() {
    fallback
  } else {
    read_signature(data, start)
  }
}

///|
fn validate_icc_device_class(
  signature : Bytes,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if signature == b"scnr" ||
    signature == b"mntr" ||
    signature == b"prtr" ||
    signature == b"spac" {
    ()
  } else {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICC profile deviceClass is not permitted for PDF graphics",
    )
  }
}

///|
fn icc_signature_component_count_or_zero(signature : Bytes) -> Int {
  if signature == b"GRAY" {
    1
  } else if signature == b"RGB " || signature == b"Lab " {
    3
  } else if signature == b"CMYK" {
    4
  } else {
    0
  }
}

///|
fn icc_signature_component_count(
  signature : Bytes,
  offset : Int64,
) -> Int raise PdfGraphicsError {
  if signature == b"GRAY" {
    1
  } else if signature == b"RGB " || signature == b"Lab " {
    3
  } else if signature == b"CMYK" {
    4
  } else {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICC profile source colour space is not permitted for PDF graphics",
    )
  }
}

///|
fn icc_rendering_intent_or_default(value : Int64) -> RenderingIntent {
  if value == 0L {
    RenderingIntent::Perceptual
  } else if value == 2L {
    RenderingIntent::Saturation
  } else if value == 3L {
    RenderingIntent::AbsoluteColorimetric
  } else {
    RenderingIntent::RelativeColorimetric
  }
}

///|
/// Parsed ICC profile header fields used by ICCBased colour spaces. Offsets
/// follow ICC.1:2010 header layout: profile size at 0, device class at 12,
/// data colour space at 16, profile connection space at 20, signature at 36,
/// and rendering intent at 64.
pub(all) struct IccProfileHeader {
  declared_size : Int64
  device_class : @objects.PdfName
  data_colour_space : @objects.PdfName
  profile_connection_space : @objects.PdfName
  rendering_intent : RenderingIntent
  component_count : Int
} derive(Eq, Debug)

///|
pub fn parse_icc_profile_header(
  decoded : Bytes,
  offset : Int64,
) -> IccProfileHeader raise PdfGraphicsError {
  if decoded.length() < 128 {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICC profile stream must contain at least a 128-byte header",
    )
  }
  let declared_size = read_u32_be(decoded, 0)
  if declared_size <= 0L || declared_size > decoded.length().to_int64() {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICC profile declared size exceeds decoded stream length",
    )
  }
  let device_class = read_signature(decoded, 12)
  validate_icc_device_class(device_class, offset)
  let profile_signature = read_signature(decoded, 36)
  if profile_signature != b"acsp" {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "ICC profile header signature must be acsp",
    )
  }
  let signature = read_signature(decoded, 16)
  let component_count = icc_signature_component_count(signature, offset)
  IccProfileHeader::{
    declared_size,
    device_class: @objects.PdfName::new(device_class),
    data_colour_space: @objects.PdfName::new(signature),
    profile_connection_space: @objects.PdfName::new(read_signature(decoded, 20)),
    rendering_intent: icc_rendering_intent(read_u32_be(decoded, 64), offset),
    component_count,
  }
}

///|
pub fn parse_icc_profile_stream_header(
  stream : @objects.PdfStream,
  offset : Int64,
) -> IccProfileHeader raise PdfGraphicsError {
  parse_icc_profile_header(decode_colour_stream(stream, offset), offset)
}

///|
fn icc_rendering_intent(
  value : Int64,
  offset : Int64,
) -> RenderingIntent raise PdfGraphicsError {
  match value {
    0L => RenderingIntent::Perceptual
    1L => RenderingIntent::RelativeColorimetric
    2L => RenderingIntent::Saturation
    3L => RenderingIntent::AbsoluteColorimetric
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "ICC profile rendering intent must be 0, 1, 2, or 3",
      )
  }
}
