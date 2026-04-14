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
  let signature = read_signature(decoded, 16)
  let component_count = icc_signature_component_count(signature, offset)
  IccProfileInfo::{
    component_count,
    data_colour_space: @objects.PdfName::new(signature),
    decoded_length: decoded.length(),
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
