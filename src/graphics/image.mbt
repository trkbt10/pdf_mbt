///|
/// ISO 32000-2 8.8 and 8.9 image source: an image XObject painted by the
/// `Do` operator from the XObject resource subdictionary, or an inline image
/// delimited by `BI`, `ID`, and `EI` in a content stream.
///
/// Source excerpt:
/// `spec/extracted/8.8-8.11-xobjects-images-optional.spec.txt`.
pub(all) enum ImageSource {
  XObjectImage(@objects.PdfName?)
  InlineImageSource
} derive(Eq, Debug)

///|
/// Availability of image sample data after structural filter handling.
/// Encoded bytes remain for filters such as JBIG2Decode, CCITTFaxDecode, or
/// Crypt; decoded bytes are checked against the image sample layout when
/// supported filters produce sample bytes.
pub(all) enum ImageByteStatus {
  EncodedBytes(Int)
  DecodedBytes(Int)
  UnsupportedEncodedBytes(Int, Array[@objects.PdfName])
} derive(Eq, Debug)

///|
/// One pair from an image Decode array. Each range maps the pre-decode sample
/// domain `0` to `2^BitsPerComponent - 1` into colour component values, and
/// may express inverted Decode arrays such as `[1 0]` for stencil masks.
pub(all) struct ImageDecodeRange {
  min : Double
  max : Double
} derive(Eq, Debug)

///|
/// Image coordinate system and sample representation. Width and height are in
/// samples, rows are byte-aligned, padding bits at row ends are ignored, and
/// the image space rectangle maps to the user-space unit square before the
/// invocation CTM places the image on the page.
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
/// Lightweight image sample parameters used by requirements checks and callers
/// that need sample-byte arithmetic without a full image dictionary.
pub(all) struct ImageParams {
  width : Int
  height : Int
  bits_per_component : Int
  component_count : Int
  image_mask : Bool
} derive(Eq, Debug)

///|
/// Validation summary for an image dictionary's sample stream. The expected
/// stream length is the decoded byte count implied by Width, Height,
/// ColorSpace component count, BitsPerComponent, and per-row byte padding.
pub(all) struct ImageDictionaryValidation {
  width : Int
  height : Int
  component_count : Int
  bits_per_component : Int
  expected_stream_length : Int
  actual_stream_length : Int
} derive(Eq, Debug)

///|
/// Masked image model from ISO 32000-2 8.9.6: no mask, stencil ImageMask,
/// explicit image mask XObject, or colour key masking with pre-decode sample
/// ranges. Colour-key masks are arrays of min/max component integers.
pub(all) enum ImageMaskInfo {
  NoImageMask
  StencilImageMask
  ExplicitMask(@objects.PdfObject)
  ColourKeyMask(Array[Int64])
} derive(Eq, Debug)

///|
/// Transparent imaging model soft-mask source for image dictionaries: no
/// associated soft mask, explicit SMask image XObject, or embedded
/// SMaskInData values from JPXDecode image samples.
pub(all) enum ImageSoftMaskSource {
  NoImageSoftMask
  ExplicitImageSoftMask(@objects.PdfObject)
  EmbeddedImageSoftMask(Int)
} derive(Eq, Debug)

///|
/// Parsed SMask and SMaskInData information, including Matte values for
/// premultiplied colour channels and soft-mask image validation.
pub(all) struct SoftMaskInfo {
  source : ImageSoftMaskSource
  smask_in_data : Int?
  matte : Array[Double]
} derive(Eq, Debug)

///|
/// Alternate image dictionary metadata from ISO 32000-2 8.9.5.4. The Image
/// entry identifies the alternate image XObject, DefaultForPrinting records
/// print selection, and OC stores optional content selection input.
pub(all) struct AlternateImageInfo {
  image : @objects.PdfObject
  default_for_printing : Bool
  optional_content : @objects.PdfObject?
} derive(Eq, Debug)

///|
/// Structural entries specific to image dictionaries: rendering Intent,
/// Interpolate-adjacent alternate image data, Name, StructParent,
/// StructParents, ID, Metadata, OPI, OC optional content, associated files
/// (AF), Measure, and PtData. These are preserved without rendering.
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
/// Validated image dictionary descriptor for image XObjects and inline images.
/// It records image parameters, sample representation, Decode arrays,
/// Interpolate hints, image masks, colour key masks, explicit masks, soft
/// masks, alternate images, optional content, and the image coordinate system
/// needed by the `Do` operator or inline image painting event.
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
/// Validates an image XObject stream from the XObject resource dictionary.
/// `/Type /XObject` and `/Subtype /Image` are required for painted image
/// XObjects. When JPXDecode is present, JPEG 2000 dimensions and component
/// count override PDF dictionary values for image pipeline integration.
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
/// Validates an ISO 32000-2 8.9.7 inline image parsed from `BI`, `ID`, and
/// `EI`. The inline image dictionary must provide Length, Length must match
/// the captured data, Length must not exceed 4096 bytes, and inline filters
/// must not include JPXDecode, JBIG2Decode, or Crypt.
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
/// Shared image dictionary validator for image XObjects and inline images.
/// It validates Width, Height, ColorSpace, BitsPerComponent, Decode arrays,
/// ImageMask, Mask, SMask, SMaskInData, Interpolate, Alternates, and PDF 2.0
/// associated metadata. For JPXDecode, JPEG 2000 metadata supplies the image
/// pipeline integration override for Width, Height, and component count.
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
        if length > 4096L {
          raise invalid_image(
            offset, "inline image Length must not exceed 4096 bytes",
          )
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
  let dict_width = required_positive_int(dict, b"Width", offset, "Width")
  let dict_height = required_positive_int(dict, b"Height", offset, "Height")
  let image_mask = image_optional_bool(
    dict, b"ImageMask", false, offset, "ImageMask",
  )
  let is_jpx = has_filter(filters, b"JPXDecode")
  let jpx_image = decode_jpx_image_for_descriptor(data, filters, offset)
  let width = match jpx_image {
    Some(image) => image.width
    None => dict_width
  }
  let height = match jpx_image {
    Some(image) => image.height
    None => dict_height
  }
  let color_space = parse_image_colour_space(dict, image_mask, is_jpx, offset)
  let bits = match jpx_image {
    Some(image) => Some(image.bits_per_component)
    None => parse_bits_per_component(dict, image_mask, is_jpx, offset)
  }
  let component_count = if image_mask {
    1
  } else {
    match jpx_image {
      Some(image) => image.num_components
      None =>
        match color_space {
          Some(space) => space.component_count()
          None => 0
        }
    }
  }
  let bits_value = match bits {
    Some(value) => value
    None => 0
  }
  let layout = ImageSampleLayout::from_values(
    width, height, component_count, bits_value,
  )
  let decode = parse_decode_ranges(
    dict, color_space, image_mask, component_count, offset,
  )
  let mask = parse_image_mask(
    dict, image_mask, component_count, bits_value, offset,
  )
  let soft_mask = parse_image_soft_mask(
    dict, image_mask, component_count, offset,
  )
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
/// Computes row bit layout for image space: samples are interleaved
/// component-by-component, each row begins on a byte boundary, and row-end
/// padding bits are excluded from the next row.
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
/// Verifies Width, Height, component count, BitsPerComponent, and decoded
/// stream length consistency for an image sample layout.
pub fn ImageSampleLayout::validate_stream_length(
  self : ImageSampleLayout,
  stream_length : Int,
  offset? : Int64 = 0L,
) -> ImageDictionaryValidation raise PdfGraphicsError {
  validate_image_sample_layout(self, offset)
  if stream_length < self.expected_decoded_length {
    raise invalid_image(
      offset, "decoded image data is shorter than expected stream length",
    )
  }
  ImageDictionaryValidation::{
    width: self.width,
    height: self.height,
    component_count: self.component_count,
    bits_per_component: self.bits_per_component,
    expected_stream_length: self.expected_decoded_length,
    actual_stream_length: stream_length,
  }
}

///|
/// Computes the decoded sample byte count implied by Width, Height,
/// BitsPerComponent, and component count. Each PDF image row is byte-aligned,
/// so partial row bytes are rounded up before multiplying by Height.
pub fn ImageParams::expected_data_length(self : ImageParams) -> Int {
  if self.width <= 0 || self.height <= 0 || self.component_count <= 0 {
    return 0
  }
  if !is_valid_bits_per_component(self.bits_per_component.to_int64()) {
    return 0
  }
  let bits_per_row = self.width * self.component_count * self.bits_per_component
  let bytes_per_row = (bits_per_row + 7) / 8
  bytes_per_row * self.height
}

///|
/// Unpacks interleaved image sample values from decoded bytes. Bits are read
/// most-significant first, rows begin on byte boundaries, and padding bits at
/// the end of each row are skipped.
pub fn ImageParams::unpack_samples(
  self : ImageParams,
  data : Bytes,
) -> Array[Int] {
  let expected = self.expected_data_length()
  if expected == 0 || data.length() < expected {
    return []
  }
  let samples : Array[Int] = []
  let row_sample_count = self.width * self.component_count
  let row_bits = row_sample_count * self.bits_per_component
  let row_stride_bits = (row_bits + 7) / 8 * 8
  for row in 0..<self.height {
    let row_bit_start = row * row_stride_bits
    for sample in 0..<row_sample_count {
      samples.push(
        read_image_param_sample(
          data,
          row_bit_start + sample * self.bits_per_component,
          self.bits_per_component,
        ),
      )
    }
  }
  samples
}

///|
/// Applies a raw Decode array to interleaved sample values. Each component
/// consumes one `[Dmin, Dmax]` pair and linearly maps the sample domain
/// `[0, 2^BitsPerComponent - 1]` into that range.
pub fn ImageParams::apply_decode_array(
  self : ImageParams,
  samples : Array[Int],
  decode : Array[Double],
) -> Array[Double] {
  if self.component_count <= 0 || decode.length() != self.component_count * 2 {
    return []
  }
  if !is_valid_bits_per_component(self.bits_per_component.to_int64()) {
    return []
  }
  let max_value = max_sample_value(self.bits_per_component).to_double()
  let decoded : Array[Double] = []
  for index in 0..<samples.length() {
    let component = index % self.component_count
    let min = decode[component * 2]
    let max = decode[component * 2 + 1]
    let sample = clamp_image_param_sample(
      samples[index],
      self.bits_per_component,
    )
    decoded.push(min + sample.to_double() / max_value * (max - min))
  }
  decoded
}

///|
/// Reports whether these parameters describe an ImageMask stencil: a one-bit,
/// single-component image whose colour is supplied by the current graphics
/// state instead of an image colour space.
pub fn ImageParams::is_stencil_mask(self : ImageParams) -> Bool {
  if !self.image_mask {
    return false
  }
  if self.component_count != 1 {
    return false
  }
  self.bits_per_component == 1
}

///|
fn validate_image_sample_layout(
  layout : ImageSampleLayout,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if layout.width <= 0 {
    raise invalid_image(offset, "Width must be positive")
  }
  if layout.height <= 0 {
    raise invalid_image(offset, "Height must be positive")
  }
  if layout.component_count <= 0 {
    raise invalid_image(offset, "image sample layout requires components")
  }
  if !is_valid_bits_per_component(layout.bits_per_component.to_int64()) {
    raise invalid_image(offset, "BitsPerComponent must be 1, 2, 4, 8, or 16")
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
  component_count : Int,
  offset : Int64,
) -> Array[ImageDecodeRange] raise PdfGraphicsError {
  match optional_entry(dict, b"Decode") {
    Some(object) => {
      let values = require_array_value(object, offset, "Decode")
      let expected = if image_mask { 2 } else { component_count * 2 }
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
        None => default_decode_ranges(component_count)
      }
  }
}

///|
fn default_decode_ranges(component_count : Int) -> Array[ImageDecodeRange] {
  let ranges : Array[ImageDecodeRange] = []
  for _ in 0..<component_count {
    ranges.push(ImageDecodeRange::{ min: 0.0, max: 1.0 })
  }
  ranges
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
    Some(object) => {
      validate_explicit_image_mask(object, offset)
      ImageMaskInfo::ExplicitMask(object)
    }
    None if image_mask => ImageMaskInfo::StencilImageMask
    None => ImageMaskInfo::NoImageMask
  }
}

///|
fn validate_explicit_image_mask(
  object : @objects.PdfObject,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(_) => ()
    @objects.PdfObject::Stream(stream) => {
      require_type_marker(stream.dict, b"XObject", offset, "explicit mask")
      require_name_entry_value(
        stream.dict,
        b"Subtype",
        b"Image",
        offset,
        "explicit mask Subtype",
      )
      if !image_optional_bool(
          stream.dict,
          b"ImageMask",
          false,
          offset,
          "explicit mask ImageMask",
        ) {
        raise invalid_image(offset, "explicit Mask stream must be an ImageMask")
      }
      if optional_entry(stream.dict, b"ColorSpace") is Some(_) {
        raise invalid_image(
          offset, "explicit Mask ImageMask forbids ColorSpace",
        )
      }
      match optional_entry(stream.dict, b"BitsPerComponent") {
        Some(value) => {
          let bits = require_integer_value(
            value, offset, "explicit mask BitsPerComponent",
          )
          if bits != 1L {
            raise invalid_image(
              offset, "explicit Mask BitsPerComponent must be 1",
            )
          }
        }
        None => ()
      }
    }
    _ =>
      raise invalid_image(
        offset, "Mask must be an image stream, reference, or colour key array",
      )
  }
}

///|
fn parse_image_soft_mask(
  dict : @objects.PdfDictionary,
  image_mask : Bool,
  component_count : Int,
  offset : Int64,
) -> SoftMaskInfo raise PdfGraphicsError {
  if image_mask && optional_entry(dict, b"SMask") is Some(_) {
    raise invalid_image(offset, "ImageMask true forbids SMask")
  }
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
  let explicit = optional_entry(dict, b"SMask")
  match explicit {
    Some(object) => {
      let explicit_matte = validate_explicit_soft_mask_image(
        object, component_count, offset,
      )
      SoftMaskInfo::{
        source: ImageSoftMaskSource::ExplicitImageSoftMask(object),
        smask_in_data,
        matte: explicit_matte,
      }
    }
    None => {
      let matte = parse_image_matte(dict, component_count, offset)
      let source = match smask_in_data {
        Some(value) if value != 0 =>
          ImageSoftMaskSource::EmbeddedImageSoftMask(value)
        _ => ImageSoftMaskSource::NoImageSoftMask
      }
      SoftMaskInfo::{ source, smask_in_data, matte }
    }
  }
}

///|
fn validate_mask_exclusions(
  mask : ImageMaskInfo,
  soft_mask : SoftMaskInfo,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match soft_mask.source {
    ExplicitImageSoftMask(_) =>
      match soft_mask.smask_in_data {
        Some(value) if value != 0 =>
          raise invalid_image(
            offset, "SMask and nonzero SMaskInData cannot both be present",
          )
        _ => ()
      }
    _ => ()
  }
  if soft_mask.smask_in_data is Some(value) {
    if value != 0 {
      match mask {
        ExplicitMask(_) | ColourKeyMask(_) =>
          raise invalid_image(
            offset, "Mask and nonzero SMaskInData cannot both be present",
          )
        _ => ()
      }
    }
  }
}

///|
fn parse_image_matte(
  dict : @objects.PdfDictionary,
  component_count : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  match optional_entry(dict, b"Matte") {
    None => []
    Some(object) => {
      let values = require_array_value(object, offset, "Matte")
      if values.length() != component_count {
        raise invalid_image(offset, "Matte length must match image components")
      }
      let matte : Array[Double] = []
      for value in values {
        matte.push(require_number_value(value, offset, "Matte"))
      }
      matte
    }
  }
}

///|
fn validate_explicit_soft_mask_image(
  object : @objects.PdfObject,
  parent_component_count : Int,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(_) => []
    @objects.PdfObject::Stream(stream) => {
      require_type_marker(stream.dict, b"XObject", offset, "SMask image")
      require_name_entry_value(
        stream.dict,
        b"Subtype",
        b"Image",
        offset,
        "SMask image Subtype",
      )
      if image_optional_bool(
          stream.dict,
          b"ImageMask",
          false,
          offset,
          "SMask ImageMask",
        ) {
        raise invalid_image(offset, "SMask image cannot be an ImageMask")
      }
      match optional_entry(stream.dict, b"ColorSpace") {
        Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"DeviceGray") =>
          ()
        Some(@objects.PdfObject::Array(values)) =>
          if values.length() == 1 &&
            values[0] == @objects.PdfObject::Name(pdf_name(b"DeviceGray")) {
            ()
          } else {
            raise invalid_image(
              offset, "SMask image ColorSpace must be DeviceGray",
            )
          }
        _ =>
          raise invalid_image(
            offset, "SMask image requires DeviceGray ColorSpace",
          )
      }
      if optional_entry(stream.dict, b"Mask") is Some(_) ||
        optional_entry(stream.dict, b"SMask") is Some(_) ||
        optional_entry(stream.dict, b"SMaskInData") is Some(_) {
        raise invalid_image(offset, "SMask image cannot contain nested masks")
      }
      parse_image_matte(stream.dict, parent_component_count, offset)
    }
    _ =>
      raise invalid_image(offset, "SMask must be an image stream or reference")
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
            let image = required_entry(alt_dict, b"Image", offset)
            alternates.push(AlternateImageInfo::{
              image,
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
fn decode_jpx_image_for_descriptor(
  data : Bytes,
  filters : Array[@objects.PdfName],
  offset : Int64,
) -> @filters.JpxImageData? raise PdfGraphicsError {
  if !has_filter(filters, b"JPXDecode") {
    return None
  }
  try @filters.decode_jpx_image(data) catch {
    error =>
      raise invalid_image(
        offset,
        "JPXDecode image decode failed: " + filter_error_label(error),
      )
  } noraise {
    image => Some(image)
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
      if layout.expected_decoded_length > 0 {
        layout.validate_stream_length(length, offset~) |> ignore
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
    if filter == pdf_name(b"Crypt") ||
      filter == pdf_name(b"JBIG2Decode") ||
      filter == pdf_name(b"JPXDecode") {
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
      filter == pdf_name(b"RunLengthDecode") ||
      filter == pdf_name(b"JPXDecode")) {
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
fn read_image_param_sample(
  data : Bytes,
  bit_position : Int,
  bit_count : Int,
) -> Int {
  let mut value = 0
  for bit in 0..<bit_count {
    let absolute = bit_position + bit
    let byte_index = absolute / 8
    let shift = 7 - absolute % 8
    let next_bit = (data[byte_index].to_int() >> shift) & 1
    value = (value << 1) | next_bit
  }
  value
}

///|
fn clamp_image_param_sample(sample : Int, bits_per_component : Int) -> Int {
  let max_value = max_sample_value(bits_per_component).to_int()
  if sample < 0 {
    return 0
  }
  if sample > max_value {
    return max_value
  }
  sample
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
