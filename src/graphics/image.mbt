///|
pub(all) enum ImageSource {
  XObjectImage(@objects.PdfName?)
  InlineImageSource
} derive(Eq, Debug)

///|
pub(all) enum ImageByteStatus {
  EncodedBytes(Int)
  DecodedBytes(Int)
  UnsupportedEncodedBytes(Int, Array[@objects.PdfName])
} derive(Eq, Debug)

///|
pub(all) struct ImageDecodeRange {
  min : Double
  max : Double
} derive(Eq, Debug)

///|
pub(all) struct ImageSampleLayout {
  width : Int
  height : Int
  component_count : Int
  bits_per_component : Int
  bits_per_row : Int
  bytes_per_row : Int
  expected_decoded_length : Int
} derive(Eq, Debug)

///|
pub(all) enum ImageMaskInfo {
  NoImageMask
  StencilImageMask
  ExplicitMask(@objects.PdfObject)
  ColourKeyMask(Array[Int64])
} derive(Eq, Debug)

///|
pub(all) struct SoftMaskInfo {
  smask : @objects.PdfObject?
  smask_in_data : Int?
} derive(Eq, Debug)

///|
pub(all) struct AlternateImageInfo {
  image : @objects.PdfObject
  default_for_printing : Bool
  optional_content : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct ImageStructuralMetadata {
  intent : @objects.PdfName?
  alternates : Array[AlternateImageInfo]
  name : @objects.PdfName?
  struct_parent : Int?
  struct_parents : Int?
  id : Bytes?
  metadata : @objects.PdfObject?
  associated_files : @objects.PdfObject?
  measure : @objects.PdfObject?
  point_data : @objects.PdfObject?
  opi : @objects.PdfObject?
  oc : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct ImageDescriptor {
  source : ImageSource
  width : Int
  height : Int
  image_mask : Bool
  color_space : ColourSpace?
  bits_per_component : Int?
  layout : ImageSampleLayout
  decode : Array[ImageDecodeRange]
  interpolate : Bool
  filters : Array[@objects.PdfName]
  byte_status : ImageByteStatus
  mask : ImageMaskInfo
  soft_mask : SoftMaskInfo
  metadata : ImageStructuralMetadata
} derive(Eq, Debug)

///|
pub fn validate_image_stream(
  name : @objects.PdfName?,
  stream : @objects.PdfStream,
  offset : Int64,
) -> ImageDescriptor raise PdfGraphicsError {
  validate_image_dictionary(
    ImageSource::XObjectImage(name),
    stream.dict,
    stream.data,
    false,
    offset,
  )
}

///|
pub fn validate_inline_image(
  image : @content.PdfInlineImage,
) -> ImageDescriptor raise PdfGraphicsError {
  validate_image_dictionary(
    ImageSource::InlineImageSource,
    image.dictionary,
    image.data,
    true,
    image.start_offset,
  )
}

///|
pub fn validate_image_dictionary(
  source : ImageSource,
  dict : @objects.PdfDictionary,
  data : Bytes,
  inline_image : Bool,
  offset : Int64,
) -> ImageDescriptor raise PdfGraphicsError {
  if !inline_image {
    require_type_marker(dict, b"XObject", offset, "Image XObject")
    require_name_entry_value(
      dict, b"Subtype", b"Image", offset, "Image Subtype",
    )
  }
  let filters = image_filter_names(dict, offset)
  if inline_image {
    validate_inline_image_filters(filters, offset)
    match optional_entry(dict, b"Length") {
      Some(value) => {
        let length = require_integer_value(value, offset, "inline image Length")
        if length < 0L {
          raise invalid_image(offset, "inline image Length must be nonnegative")
        }
        if length.to_int() != data.length() {
          raise invalid_image(
            offset, "inline image Length must match captured data",
          )
        }
      }
      None =>
        raise invalid_image(offset, "inline image dictionary requires Length")
    }
  }
  let width = required_positive_int(dict, b"Width", offset, "Width")
  let height = required_positive_int(dict, b"Height", offset, "Height")
  let image_mask = image_optional_bool(
    dict, b"ImageMask", false, offset, "ImageMask",
  )
  let is_jpx = has_filter(filters, b"JPXDecode")
  let color_space = parse_image_colour_space(dict, image_mask, is_jpx, offset)
  let bits = parse_bits_per_component(dict, image_mask, is_jpx, offset)
  let component_count = if image_mask {
    1
  } else {
    match color_space {
      Some(space) => space.component_count()
      None => 0
    }
  }
  let bits_value = match bits {
    Some(value) => value
    None => 0
  }
  let layout = ImageSampleLayout::from_values(
    width, height, component_count, bits_value,
  )
  let decode = parse_decode_ranges(dict, color_space, image_mask, offset)
  let mask = parse_image_mask(
    dict, image_mask, component_count, bits_value, offset,
  )
  let soft_mask = parse_soft_mask(dict, offset)
  validate_mask_exclusions(mask, soft_mask, offset)
  let byte_status = classify_image_bytes(dict, data, filters)
  validate_decoded_length(layout, byte_status, offset)
  ImageDescriptor::{
    source,
    width,
    height,
    image_mask,
    color_space,
    bits_per_component: bits,
    layout,
    decode,
    interpolate: image_optional_bool(
      dict, b"Interpolate", false, offset, "Interpolate",
    ),
    filters,
    byte_status,
    mask,
    soft_mask,
    metadata: image_structural_metadata(dict, offset),
  }
}

///|
pub fn ImageSampleLayout::from_values(
  width : Int,
  height : Int,
  component_count : Int,
  bits_per_component : Int,
) -> ImageSampleLayout {
  let bits_per_row = width * component_count * bits_per_component
  let bytes_per_row = (bits_per_row + 7) / 8
  ImageSampleLayout::{
    width,
    height,
    component_count,
    bits_per_component,
    bits_per_row,
    bytes_per_row,
    expected_decoded_length: bytes_per_row * height,
  }
}

///|
fn parse_image_colour_space(
  dict : @objects.PdfDictionary,
  image_mask : Bool,
  is_jpx : Bool,
  offset : Int64,
) -> ColourSpace? raise PdfGraphicsError {
  match optional_entry(dict, b"ColorSpace") {
    Some(_) if image_mask =>
      raise invalid_image(offset, "ImageMask true forbids ColorSpace")
    Some(object) => {
      let space = parse_colour_space_object(
        object,
        ColourDefaults::empty(),
        offset,
      )
      match space {
        Pattern(_) =>
          raise invalid_image(offset, "image ColorSpace cannot be Pattern")
        _ => Some(space)
      }
    }
    None if image_mask => None
    None if is_jpx => None
    None => raise invalid_image(offset, "image dictionary requires ColorSpace")
  }
}

///|
fn parse_bits_per_component(
  dict : @objects.PdfDictionary,
  image_mask : Bool,
  is_jpx : Bool,
  offset : Int64,
) -> Int? raise PdfGraphicsError {
  match optional_entry(dict, b"BitsPerComponent") {
    Some(object) => {
      let value = require_integer_value(object, offset, "BitsPerComponent")
      if image_mask && value != 1L {
        raise invalid_image(offset, "ImageMask BitsPerComponent must be 1")
      }
      if !is_jpx && !is_valid_bits_per_component(value) {
        raise invalid_image(
          offset, "BitsPerComponent must be 1, 2, 4, 8, or 16",
        )
      }
      Some(value.to_int())
    }
    None if image_mask => Some(1)
    None if is_jpx => None
    None =>
      raise invalid_image(offset, "image dictionary requires BitsPerComponent")
  }
}

///|
fn is_valid_bits_per_component(value : Int64) -> Bool {
  value == 1L || value == 2L || value == 4L || value == 8L || value == 16L
}

///|
fn parse_decode_ranges(
  dict : @objects.PdfDictionary,
  color_space : ColourSpace?,
  image_mask : Bool,
  offset : Int64,
) -> Array[ImageDecodeRange] raise PdfGraphicsError {
  match optional_entry(dict, b"Decode") {
    Some(object) => {
      let values = require_array_value(object, offset, "Decode")
      let expected = if image_mask {
        2
      } else {
        match color_space {
          Some(space) => space.component_count() * 2
          None => 0
        }
      }
      if expected > 0 && values.length() != expected {
        raise invalid_image(
          offset, "Decode array length does not match component count",
        )
      }
      numbers_to_decode_ranges(values, offset)
    }
    None if image_mask => [ImageDecodeRange::{ min: 0.0, max: 1.0 }]
    None =>
      match color_space {
        Some(space) => colour_ranges_to_decode_ranges(space.component_ranges())
        None => []
      }
  }
}

///|
fn numbers_to_decode_ranges(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> Array[ImageDecodeRange] raise PdfGraphicsError {
  let ranges : Array[ImageDecodeRange] = []
  if values.length() % 2 != 0 {
    raise invalid_image(offset, "Decode array must contain min/max pairs")
  }
  for index in 0..<(values.length() / 2) {
    ranges.push(ImageDecodeRange::{
      min: require_number_value(values[index * 2], offset, "Decode"),
      max: require_number_value(values[index * 2 + 1], offset, "Decode"),
    })
  }
  ranges
}

///|
fn colour_ranges_to_decode_ranges(
  values : Array[ColourRange],
) -> Array[ImageDecodeRange] {
  let ranges : Array[ImageDecodeRange] = []
  for value in values {
    ranges.push(ImageDecodeRange::{ min: value.min, max: value.max })
  }
  ranges
}

///|
fn parse_image_mask(
  dict : @objects.PdfDictionary,
  image_mask : Bool,
  component_count : Int,
  bits_per_component : Int,
  offset : Int64,
) -> ImageMaskInfo raise PdfGraphicsError {
  match optional_entry(dict, b"Mask") {
    Some(_) if image_mask =>
      raise invalid_image(offset, "ImageMask true forbids Mask")
    Some(@objects.PdfObject::Array(values)) => {
      let expected = component_count * 2
      if values.length() != expected {
        raise invalid_image(
          offset, "colour-key Mask length does not match component count",
        )
      }
      let max_component = max_sample_value(bits_per_component)
      let key : Array[Int64] = []
      for value in values {
        let n = require_integer_value(value, offset, "colour-key Mask")
        if n < 0L || n > max_component {
          raise invalid_image(
            offset, "colour-key Mask value is out of sample range",
          )
        }
        key.push(n)
      }
      ImageMaskInfo::ColourKeyMask(key)
    }
    Some(object) => ImageMaskInfo::ExplicitMask(object)
    None if image_mask => ImageMaskInfo::StencilImageMask
    None => ImageMaskInfo::NoImageMask
  }
}

///|
fn parse_soft_mask(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> SoftMaskInfo raise PdfGraphicsError {
  let smask_in_data = match optional_entry(dict, b"SMaskInData") {
    Some(value) => {
      let n = require_integer_value(value, offset, "SMaskInData")
      if n < 0L || n > 2L {
        raise invalid_image(offset, "SMaskInData must be 0, 1, or 2")
      }
      Some(n.to_int())
    }
    None => None
  }
  SoftMaskInfo::{ smask: optional_entry(dict, b"SMask"), smask_in_data }
}

///|
fn validate_mask_exclusions(
  mask : ImageMaskInfo,
  soft_mask : SoftMaskInfo,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if soft_mask.smask is Some(_) {
    match soft_mask.smask_in_data {
      Some(value) if value != 0 =>
        raise invalid_image(
          offset, "SMask and nonzero SMaskInData cannot both be present",
        )
      _ => ()
    }
  }
  match mask {
    ExplicitMask(_) | ColourKeyMask(_) =>
      if soft_mask.smask is Some(_) {
        ()
      } else {
        ()
      }
    _ => ()
  }
}

///|
fn image_structural_metadata(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> ImageStructuralMetadata raise PdfGraphicsError {
  ImageStructuralMetadata::{
    intent: image_optional_name(dict, b"Intent", offset, "Intent"),
    alternates: parse_alternates(dict, offset),
    name: image_optional_name(dict, b"Name", offset, "Name"),
    struct_parent: image_optional_int(
      dict, b"StructParent", offset, "StructParent",
    ),
    struct_parents: image_optional_int(
      dict, b"StructParents", offset, "StructParents",
    ),
    id: image_optional_string(dict, b"ID", offset, "ID"),
    metadata: optional_entry(dict, b"Metadata"),
    associated_files: optional_entry(dict, b"AF"),
    measure: optional_entry(dict, b"Measure"),
    point_data: optional_entry(dict, b"PtData"),
    opi: optional_entry(dict, b"OPI"),
    oc: optional_entry(dict, b"OC"),
  }
}

///|
fn parse_alternates(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Array[AlternateImageInfo] raise PdfGraphicsError {
  match optional_entry(dict, b"Alternates") {
    None => []
    Some(object) => {
      let values = require_array_value(object, offset, "Alternates")
      let alternates : Array[AlternateImageInfo] = []
      for value in values {
        match value {
          @objects.PdfObject::Dictionary(alt_dict) => {
            if optional_entry(alt_dict, b"Alternates") is Some(_) {
              raise invalid_image(
                offset, "alternate image cannot contain Alternates",
              )
            }
            alternates.push(AlternateImageInfo::{
              image: value,
              default_for_printing: image_optional_bool(
                alt_dict, b"DefaultForPrinting", false, offset, "DefaultForPrinting",
              ),
              optional_content: optional_entry(alt_dict, b"OC"),
            })
          }
          @objects.PdfObject::Stream(stream) => {
            if optional_entry(stream.dict, b"Alternates") is Some(_) {
              raise invalid_image(
                offset, "alternate image cannot contain Alternates",
              )
            }
            alternates.push(AlternateImageInfo::{
              image: value,
              default_for_printing: image_optional_bool(
                stream.dict,
                b"DefaultForPrinting",
                false,
                offset,
                "DefaultForPrinting",
              ),
              optional_content: optional_entry(stream.dict, b"OC"),
            })
          }
          _ =>
            raise invalid_image(
              offset, "Alternates entries must be image dictionaries",
            )
        }
      }
      alternates
    }
  }
}

///|
fn classify_image_bytes(
  dict : @objects.PdfDictionary,
  data : Bytes,
  filters : Array[@objects.PdfName],
) -> ImageByteStatus {
  if filters.length() == 0 ||
    all_filters_supported_for_structural_decode(filters) {
    let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
      dict, data,
    )
    match decoded {
      Ok(bytes) => ImageByteStatus::DecodedBytes(bytes.length())
      Err(_) => ImageByteStatus::EncodedBytes(data.length())
    }
  } else {
    ImageByteStatus::UnsupportedEncodedBytes(data.length(), filters.copy())
  }
}

///|
fn validate_decoded_length(
  layout : ImageSampleLayout,
  status : ImageByteStatus,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match status {
    DecodedBytes(length) =>
      if layout.expected_decoded_length > 0 &&
        length < layout.expected_decoded_length {
        raise invalid_image(
          offset, "decoded image data is shorter than sample layout",
        )
      }
    _ => ()
  }
}

///|
fn image_filter_names(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Array[@objects.PdfName] raise PdfGraphicsError {
  match optional_entry(dict, b"Filter") {
    None => []
    Some(@objects.PdfObject::Name(name)) => [name]
    Some(@objects.PdfObject::Array(values)) => {
      let names : Array[@objects.PdfName] = []
      for value in values {
        names.push(require_name_value(value, offset, "Filter"))
      }
      names
    }
    Some(_) =>
      raise invalid_image(offset, "Filter must be a name or array of names")
  }
}

///|
fn validate_inline_image_filters(
  filters : Array[@objects.PdfName],
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  for filter in filters {
    if filter == pdf_name(b"Crypt") || filter == pdf_name(b"JBIG2Decode") {
      raise invalid_image(offset, "inline image filter is not permitted")
    }
  }
}

///|
fn all_filters_supported_for_structural_decode(
  filters : Array[@objects.PdfName],
) -> Bool {
  for filter in filters {
    if !(filter == pdf_name(b"ASCIIHexDecode") ||
      filter == pdf_name(b"ASCII85Decode") ||
      filter == pdf_name(b"FlateDecode") ||
      filter == pdf_name(b"LZWDecode") ||
      filter == pdf_name(b"RunLengthDecode")) {
      return false
    }
  }
  true
}

///|
fn has_filter(filters : Array[@objects.PdfName], name : Bytes) -> Bool {
  let expected = pdf_name(name)
  for filter in filters {
    if filter == expected {
      return true
    }
  }
  false
}

///|
fn max_sample_value(bits_per_component : Int) -> Int64 {
  let mut value = 1L
  for _ in 0..<bits_per_component {
    value *= 2L
  }
  value - 1L
}

///|
fn required_positive_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> Int raise PdfGraphicsError {
  let value = require_integer_value(
    required_entry(dict, key, offset),
    offset,
    label,
  )
  if value <= 0L {
    raise invalid_image(offset, label + " must be positive")
  }
  value.to_int()
}

///|
fn image_optional_bool(
  dict : @objects.PdfDictionary,
  key : Bytes,
  default : Bool,
  offset : Int64,
  label : String,
) -> Bool raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => require_bool_value(value, offset, label)
    None => default
  }
}

///|
fn image_optional_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> Int? raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => Some(require_integer_value(value, offset, label).to_int())
    None => None
  }
}

///|
fn image_optional_name(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> @objects.PdfName? raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => Some(require_name_value(value, offset, label))
    None => None
  }
}

///|
fn image_optional_string(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> Bytes? raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(@objects.PdfObject::String(value)) => Some(value)
    Some(_) => raise invalid_image(offset, label + " must be a string")
    None => None
  }
}

///|
fn require_name_entry_value(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected : Bytes,
  offset : Int64,
  label : String,
) -> Unit raise PdfGraphicsError {
  let name = require_name_value(
    required_entry(dict, key, offset),
    offset,
    label,
  )
  if name != pdf_name(expected) {
    raise invalid_image(offset, label + " marker mismatch")
  }
}

///|
fn invalid_image(offset : Int64, reason : String) -> PdfGraphicsError {
  PdfGraphicsError::InvalidImage(offset, reason)
}
