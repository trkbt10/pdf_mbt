///|
/// DeviceRGB pixel output extracted from an image XObject or inline image.
/// Pixels are interleaved RGBA bytes in image sample order: row-major from the
/// image-space upper-left corner, four bytes per sample.
pub(all) struct ImageDeviceRgbRaster {
  width : Int
  height : Int
  rgba : Bytes
} derive(Eq, Debug)

///|
/// One-byte alpha mask extracted from an ImageMask, explicit Mask image, or
/// SMask image. Values are row-major and already mapped through Decode.
pub(all) struct ImageAlphaMaskRaster {
  width : Int
  height : Int
  alpha : Bytes
} derive(Eq, Debug)

///|
/// Extracted image data. Supported sample-byte filters are expanded into
/// DeviceRGB pixels; unsupported encoded image codecs such as JBIG2Decode,
/// CCITTFaxDecode, and Crypt preserve their original encoded bytes and filter
/// names for a downstream codec.
pub(all) enum ExtractedImageData {
  DeviceRgbRaster(ImageDeviceRgbRaster)
  StencilMaskRaster(ImageAlphaMaskRaster)
  EncodedImageData(Bytes, Array[@objects.PdfName])
} derive(Eq, Debug)

///|
/// Validated image descriptor paired with extracted byte-level image data.
pub(all) struct ExtractedImage {
  descriptor : ImageDescriptor
  data : ExtractedImageData
} derive(Eq, Debug)

///|
/// Decodes PDF image sample bytes into unsigned component values. Bits are
/// consumed most-significant first, rows start on byte boundaries, row padding
/// bits are ignored, and 1, 2, 4, 8, and 16 bit components are supported.
pub fn decode_image_sample_values(
  data : Bytes,
  layout : ImageSampleLayout,
  offset? : Int64 = 0L,
) -> Array[Int] raise PdfGraphicsError {
  unpack_image_samples(data, layout, offset)
}

///|
/// Applies one Decode array component range to a raw sample value by linear
/// interpolation from `[0, 2^BitsPerComponent - 1]` to `[Dmin, Dmax]`.
pub fn apply_image_decode_range(
  sample : Int,
  bits_per_component : Int,
  range : ImageDecodeRange,
  offset? : Int64 = 0L,
) -> Double raise PdfGraphicsError {
  validate_sample_value(sample, bits_per_component, offset)
  decode_sample_value(sample, bits_per_component, range)
}

///|
/// Applies an image Decode array to interleaved raw samples, returning
/// interleaved colour component values in the image colour space.
pub fn apply_image_decode_array(
  samples : Array[Int],
  layout : ImageSampleLayout,
  decode : Array[ImageDecodeRange],
  offset? : Int64 = 0L,
) -> Array[Double] raise PdfGraphicsError {
  if layout.component_count <= 0 {
    raise PdfGraphicsError::InvalidImage(
      offset, "Decode array application requires image components",
    )
  }
  if decode.length() != layout.component_count {
    raise PdfGraphicsError::InvalidImage(
      offset, "Decode array length does not match component count",
    )
  }
  let decoded : Array[Double] = []
  for index in 0..<samples.length() {
    let component = index % layout.component_count
    decoded.push(
      apply_image_decode_range(
        samples[index],
        layout.bits_per_component,
        decode[component],
        offset~,
      ),
    )
  }
  decoded
}

///|
/// Combines a one-byte stencil alpha mask with the current nonstroking paint
/// colour represented in DeviceRGB, producing masked RGBA pixels.
pub fn paint_stencil_mask_with_colour(
  mask : ImageAlphaMaskRaster,
  paint : DeviceRgbColour,
) -> ImageDeviceRgbRaster {
  let rgba : Array[Byte] = []
  let red = unit_to_byte(paint.red)
  let green = unit_to_byte(paint.green)
  let blue = unit_to_byte(paint.blue)
  for alpha in mask.alpha {
    rgba.push(red)
    rgba.push(green)
    rgba.push(blue)
    rgba.push(alpha)
  }
  ImageDeviceRgbRaster::{
    width: mask.width,
    height: mask.height,
    rgba: Bytes::from_array(rgba),
  }
}

///|
/// Decodes an ImageMask stream and paints every unmasked one-bit sample with
/// the supplied DeviceRGB paint colour.
pub fn decode_stencil_mask_to_colour(
  descriptor : ImageDescriptor,
  decoded : Bytes,
  paint : DeviceRgbColour,
  offset? : Int64 = 0L,
) -> ImageDeviceRgbRaster raise PdfGraphicsError {
  if !descriptor.image_mask {
    raise PdfGraphicsError::InvalidImage(
      offset, "stencil mask painting requires ImageMask true",
    )
  }
  paint_stencil_mask_with_colour(
    decode_stencil_alpha_mask(descriptor, decoded, offset),
    paint,
  )
}

///|
/// Validates and extracts an image XObject stream. For JPXDecode, the
/// JPEG 2000 image pipeline integration uses decoded sample data and metadata
/// from the filter layer so JPEG 2000 Width, Height, and component count
/// override PDF dictionary values, including the component count override.
/// Other supported filters use the image Width, Height, BitsPerComponent,
/// Decode, and row-padding rules before conversion to DeviceRGB.
pub fn extract_image_xobject(
  name : @objects.PdfName?,
  stream : @objects.PdfStream,
  offset : Int64,
) -> ExtractedImage raise PdfGraphicsError {
  let descriptor = validate_image_stream(name, stream, offset)
  let data = extract_image_data(descriptor, stream.dict, stream.data, offset)
  ExtractedImage::{ descriptor, data }
}

///|
/// Validates and extracts an inline image parsed from a content stream. Inline
/// dictionary abbreviations are already expanded by `content`; JPXDecode is
/// rejected for inline images, while other supported filters decode into the
/// same extracted image data model used for Image XObjects.
pub fn extract_inline_image(
  image : @content.PdfInlineImage,
) -> ExtractedImage raise PdfGraphicsError {
  let descriptor = validate_inline_image(image)
  let data = extract_image_data(
    descriptor,
    image.dictionary,
    image.data,
    image.start_offset,
  )
  ExtractedImage::{ descriptor, data }
}

///|
fn extract_image_data(
  descriptor : ImageDescriptor,
  dict : @objects.PdfDictionary,
  data : Bytes,
  offset : Int64,
) -> ExtractedImageData raise PdfGraphicsError {
  let decoded_result : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded_result {
    Ok(decoded) => decode_sample_bytes_to_rgb(descriptor, decoded, offset)
    Err(UnsupportedFilter(_)) =>
      match decode_external_image_bytes(data) {
        Some(raster) => ExtractedImageData::DeviceRgbRaster(raster)
        None =>
          ExtractedImageData::EncodedImageData(data, descriptor.filters.copy())
      }
    Err(error) =>
      raise PdfGraphicsError::InvalidImage(
        offset,
        "image stream filter decode failed: " + filter_error_label(error),
      )
  }
}

///|
fn decode_external_image_bytes(data : Bytes) -> ImageDeviceRgbRaster? {
  match decode_png_image_bytes(data) {
    Some(raster) => Some(raster)
    None =>
      match decode_bmp_image_bytes(data) {
        Some(raster) => Some(raster)
        None => decode_jpeg_image_bytes(data)
      }
  }
}

///|
fn decode_png_image_bytes(data : Bytes) -> ImageDeviceRgbRaster? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_png(
    data,
  )
  match result {
    Ok(image) => image_data_to_device_rgb_raster(image)
    Err(_) => None
  }
}

///|
fn decode_bmp_image_bytes(data : Bytes) -> ImageDeviceRgbRaster? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_bmp(
    data,
  )
  match result {
    Ok(image) => image_data_to_device_rgb_raster(image)
    Err(_) => None
  }
}

///|
fn decode_jpeg_image_bytes(data : Bytes) -> ImageDeviceRgbRaster? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_jpeg(
    data,
  )
  match result {
    Ok(image) => image_data_to_device_rgb_raster(image)
    Err(_) => None
  }
}

///|
fn image_data_to_device_rgb_raster(
  image : @image.ImageData,
) -> ImageDeviceRgbRaster? {
  if image.width <= 0 || image.height <= 0 {
    return None
  }
  if image.data.length() != image.width * image.height * 4 {
    return None
  }
  Some(ImageDeviceRgbRaster::{
    width: image.width,
    height: image.height,
    rgba: image.data,
  })
}

///|
fn decode_sample_bytes_to_rgb(
  descriptor : ImageDescriptor,
  decoded : Bytes,
  offset : Int64,
) -> ExtractedImageData raise PdfGraphicsError {
  if descriptor.image_mask {
    return ExtractedImageData::StencilMaskRaster(
      decode_stencil_alpha_mask(descriptor, decoded, offset),
    )
  }
  let space = match descriptor.color_space {
    Some(value) => value
    None =>
      return ExtractedImageData::EncodedImageData(
        decoded,
        descriptor.filters.copy(),
      )
  }
  if space.component_count() != descriptor.layout.component_count {
    return ExtractedImageData::EncodedImageData(
      decoded,
      descriptor.filters.copy(),
    )
  }
  let samples = decode_image_sample_values(decoded, descriptor.layout, offset~)
  let alpha = alpha_for_image_descriptor(descriptor, samples, offset)
  let bits_per_component = require_bits_per_component(descriptor, offset)
  let rgba : Array[Byte] = []
  for pixel in 0..<(descriptor.width * descriptor.height) {
    let (r, g, b) = pixel_to_device_rgb(
      space,
      descriptor.decode,
      bits_per_component,
      samples,
      pixel,
      offset,
    )
    rgba.push(unit_to_byte(r))
    rgba.push(unit_to_byte(g))
    rgba.push(unit_to_byte(b))
    rgba.push(alpha_byte_at(alpha, pixel))
  }
  ExtractedImageData::DeviceRgbRaster(ImageDeviceRgbRaster::{
    width: descriptor.width,
    height: descriptor.height,
    rgba: Bytes::from_array(rgba),
  })
}

///|
fn decode_stencil_alpha_mask(
  descriptor : ImageDescriptor,
  decoded : Bytes,
  offset : Int64,
) -> ImageAlphaMaskRaster raise PdfGraphicsError {
  let samples = decode_image_sample_values(decoded, descriptor.layout, offset~)
  let bits_per_component = require_bits_per_component(descriptor, offset)
  let alpha = alpha_from_single_component_samples(
    samples,
    bits_per_component,
    descriptor.decode[0],
  )
  ImageAlphaMaskRaster::{
    width: descriptor.width,
    height: descriptor.height,
    alpha,
  }
}

///|
fn alpha_for_image_descriptor(
  descriptor : ImageDescriptor,
  samples : Array[Int],
  offset : Int64,
) -> Bytes? raise PdfGraphicsError {
  match descriptor.soft_mask.source {
    ExplicitImageSoftMask(object) =>
      explicit_soft_mask_alpha(
        object,
        descriptor.width,
        descriptor.height,
        offset,
      )
    EmbeddedImageSoftMask(_) => None
    NoImageSoftMask =>
      match descriptor.mask {
        ColourKeyMask(ranges) =>
          Some(
            colour_key_alpha(
              samples,
              ranges,
              descriptor.layout.component_count,
              descriptor.width * descriptor.height,
            ),
          )
        ExplicitMask(object) =>
          explicit_image_mask_alpha(
            object,
            descriptor.width,
            descriptor.height,
            offset,
          )
        _ => None
      }
  }
}

///|
fn explicit_image_mask_alpha(
  object : @objects.PdfObject,
  width : Int,
  height : Int,
  offset : Int64,
) -> Bytes? raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Stream(stream) => {
      let descriptor = validate_image_stream(None, stream, offset)
      let decoded = decode_mask_stream_bytes(stream, offset)
      let mask = decode_stencil_alpha_mask(descriptor, decoded, offset)
      require_alpha_dimensions(mask, width, height, offset)
      Some(mask.alpha)
    }
    @objects.PdfObject::Ref(_) => None
    _ =>
      raise PdfGraphicsError::InvalidImage(
        offset, "explicit Mask must be a direct image stream or reference",
      )
  }
}

///|
fn explicit_soft_mask_alpha(
  object : @objects.PdfObject,
  width : Int,
  height : Int,
  offset : Int64,
) -> Bytes? raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Stream(stream) => {
      let descriptor = validate_image_stream(None, stream, offset)
      let decoded = decode_mask_stream_bytes(stream, offset)
      let mask = decode_gray_alpha_mask(descriptor, decoded, offset)
      require_alpha_dimensions(mask, width, height, offset)
      Some(mask.alpha)
    }
    @objects.PdfObject::Ref(_) => None
    _ =>
      raise PdfGraphicsError::InvalidImage(
        offset, "SMask must be a direct image stream or reference",
      )
  }
}

///|
fn decode_mask_stream_bytes(
  stream : @objects.PdfStream,
  offset : Int64,
) -> Bytes raise PdfGraphicsError {
  try @filters.decode_stream(stream) catch {
    error =>
      raise PdfGraphicsError::InvalidImage(
        offset,
        "image mask filter decode failed: " + filter_error_label(error),
      )
  } noraise {
    bytes => bytes
  }
}

///|
fn decode_gray_alpha_mask(
  descriptor : ImageDescriptor,
  decoded : Bytes,
  offset : Int64,
) -> ImageAlphaMaskRaster raise PdfGraphicsError {
  if descriptor.layout.component_count != 1 {
    raise PdfGraphicsError::InvalidImage(
      offset, "soft mask image must decode to one component",
    )
  }
  let samples = decode_image_sample_values(decoded, descriptor.layout, offset~)
  let bits_per_component = require_bits_per_component(descriptor, offset)
  let alpha = alpha_from_single_component_samples(
    samples,
    bits_per_component,
    descriptor.decode[0],
  )
  ImageAlphaMaskRaster::{
    width: descriptor.width,
    height: descriptor.height,
    alpha,
  }
}

///|
fn alpha_from_single_component_samples(
  samples : Array[Int],
  bits_per_component : Int,
  range : ImageDecodeRange,
) -> Bytes {
  let alpha : Array[Byte] = []
  for sample in samples {
    alpha.push(
      unit_to_byte(decode_sample_value(sample, bits_per_component, range)),
    )
  }
  Bytes::from_array(alpha)
}

///|
fn colour_key_alpha(
  samples : Array[Int],
  ranges : Array[Int64],
  component_count : Int,
  pixel_count : Int,
) -> Bytes {
  let alpha : Array[Byte] = []
  for pixel in 0..<pixel_count {
    let mut masked = true
    for component in 0..<component_count {
      let sample = samples[pixel * component_count + component].to_int64()
      let min = ranges[component * 2]
      let max = ranges[component * 2 + 1]
      if sample < min || sample > max {
        masked = false
      }
    }
    alpha.push(if masked { b'\x00' } else { b'\xff' })
  }
  Bytes::from_array(alpha)
}

///|
fn require_bits_per_component(
  descriptor : ImageDescriptor,
  offset : Int64,
) -> Int raise PdfGraphicsError {
  match descriptor.bits_per_component {
    Some(value) => value
    None =>
      raise PdfGraphicsError::InvalidImage(
        offset, "image decoding requires BitsPerComponent",
      )
  }
}

///|
fn require_alpha_dimensions(
  mask : ImageAlphaMaskRaster,
  width : Int,
  height : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if mask.width != width || mask.height != height {
    raise PdfGraphicsError::InvalidImage(
      offset, "image mask dimensions must match the base image",
    )
  }
}

///|
fn alpha_byte_at(alpha : Bytes?, pixel : Int) -> Byte {
  match alpha {
    Some(bytes) => bytes[pixel]
    None => b'\xff'
  }
}

///|
fn unpack_image_samples(
  data : Bytes,
  layout : ImageSampleLayout,
  offset : Int64,
) -> Array[Int] raise PdfGraphicsError {
  validate_image_sample_layout(layout, offset)
  if data.length() < layout.expected_decoded_length {
    raise PdfGraphicsError::InvalidImage(
      offset, "decoded image data is shorter than sample layout",
    )
  }
  let samples : Array[Int] = []
  for row in 0..<layout.height {
    let row_bit_start = row * layout.bytes_per_row * 8
    let row_sample_count = layout.width * layout.component_count
    for sample in 0..<row_sample_count {
      samples.push(
        read_msb_bits(
          data,
          row_bit_start + sample * layout.bits_per_component,
          layout.bits_per_component,
          offset,
        ),
      )
    }
  }
  samples
}

///|
fn validate_sample_value(
  sample : Int,
  bits_per_component : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if sample < 0 || sample.to_int64() > max_sample_value(bits_per_component) {
    raise PdfGraphicsError::InvalidImage(
      offset, "image sample value is outside BitsPerComponent domain",
    )
  }
}

///|
fn read_msb_bits(
  data : Bytes,
  bit_position : Int,
  bit_count : Int,
  offset : Int64,
) -> Int raise PdfGraphicsError {
  if bit_position + bit_count > data.length() * 8 {
    raise PdfGraphicsError::InvalidImage(offset, "truncated image sample row")
  }
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
fn pixel_to_device_rgb(
  space : ColourSpace,
  decode : Array[ImageDecodeRange],
  bits_per_component : Int,
  samples : Array[Int],
  pixel : Int,
  offset : Int64,
) -> (Double, Double, Double) raise PdfGraphicsError {
  match space {
    Indexed(params) =>
      indexed_pixel_to_device_rgb(
        params,
        decode,
        bits_per_component,
        samples[pixel],
        offset,
      )
    _ => {
      let count = space.component_count()
      let components : Array[Double] = []
      for component in 0..<count {
        components.push(
          decode_sample_value(
            samples[pixel * count + component],
            bits_per_component,
            decode[component],
          ),
        )
      }
      components_to_device_rgb(space, components, offset)
    }
  }
}

///|
fn indexed_pixel_to_device_rgb(
  params : IndexedParams,
  decode : Array[ImageDecodeRange],
  bits_per_component : Int,
  raw_sample : Int,
  offset : Int64,
) -> (Double, Double, Double) raise PdfGraphicsError {
  let decoded_index = decode_sample_value(
    raw_sample,
    bits_per_component,
    decode[0],
  )
  let index = clamp_double(
    @math.floor(decoded_index + 0.5),
    0.0,
    params.hival.to_double(),
  ).to_int()
  let lookup = indexed_lookup_bytes(params.lookup, offset)
  let base_count = params.base.component_count()
  let start = index * base_count
  if start + base_count > lookup.length() {
    raise PdfGraphicsError::InvalidImage(
      offset, "Indexed lookup table is shorter than selected image sample",
    )
  }
  let components : Array[Double] = []
  for component in 0..<base_count {
    components.push(lookup[start + component].to_int().to_double() / 255.0)
  }
  components_to_device_rgb(params.base, components, offset)
}

///|
fn indexed_lookup_bytes(
  object : @objects.PdfObject,
  offset : Int64,
) -> Bytes raise PdfGraphicsError {
  match object {
    @objects.PdfObject::String(bytes) => bytes
    @objects.PdfObject::Stream(stream) => decode_colour_stream(stream, offset)
    _ =>
      raise PdfGraphicsError::InvalidImage(
        offset, "Indexed lookup must be a direct string or stream to decode pixels",
      )
  }
}

///|
fn decode_sample_value(
  sample : Int,
  bits_per_component : Int,
  range : ImageDecodeRange,
) -> Double {
  let max_value = max_sample_value(bits_per_component).to_double()
  if max_value <= 0.0 {
    range.min
  } else {
    range.min + sample.to_double() / max_value * (range.max - range.min)
  }
}

///|
fn components_to_device_rgb(
  space : ColourSpace,
  components : Array[Double],
  offset : Int64,
) -> (Double, Double, Double) raise PdfGraphicsError {
  match space {
    Device(DeviceGray) => rgb_colour_tuple(device_gray_to_rgb(components[0]))
    Device(DeviceRGB) =>
      (
        clamp_double(components[0], 0.0, 1.0),
        clamp_double(components[1], 0.0, 1.0),
        clamp_double(components[2], 0.0, 1.0),
      )
    Device(DeviceCMYK) =>
      rgb_colour_tuple(
        device_cmyk_to_rgb(DeviceCmykColour::{
          cyan: components[0],
          magenta: components[1],
          yellow: components[2],
          black: components[3],
        }),
      )
    CalGray(params) =>
      rgb_colour_tuple(cie_xyz_d65_to_srgb(params.to_xyz(components[0])))
    CalRGB(params) =>
      rgb_colour_tuple(cie_xyz_d65_to_srgb(params.to_xyz(components, offset~)))
    Lab(params) => rgb_colour_tuple(params.to_srgb(components, offset~))
    Separation(_) => rgb_colour_tuple(device_gray_to_rgb(components[0]))
    ICCBased(params) =>
      if components.length() == 1 {
        rgb_colour_tuple(device_gray_to_rgb(components[0]))
      } else if components.length() == 3 {
        (
          clamp_double(components[0], 0.0, 1.0),
          clamp_double(components[1], 0.0, 1.0),
          clamp_double(components[2], 0.0, 1.0),
        )
      } else if components.length() == 4 {
        rgb_colour_tuple(
          device_cmyk_to_rgb(DeviceCmykColour::{
            cyan: components[0],
            magenta: components[1],
            yellow: components[2],
            black: components[3],
          }),
        )
      } else {
        match params.alternate {
          Some(alternate) =>
            components_to_device_rgb(alternate, components, offset)
          None =>
            raise PdfGraphicsError::InvalidImage(
              offset, "ICCBased image colour space cannot be converted to DeviceRGB",
            )
        }
      }
    DeviceN(_) => {
      let mut lightness = 1.0
      for value in components {
        lightness = lightness * clamp_double(value, 0.0, 1.0)
      }
      (lightness, lightness, lightness)
    }
    Pattern(_) | Indexed(_) =>
      raise PdfGraphicsError::InvalidImage(
        offset, "image colour space cannot be converted directly to DeviceRGB",
      )
  }
}

///|
fn rgb_colour_tuple(rgb : DeviceRgbColour) -> (Double, Double, Double) {
  (rgb.red, rgb.green, rgb.blue)
}

///|
fn unit_to_byte(value : Double) -> Byte {
  @math.floor(clamp_double(value, 0.0, 1.0) * 255.0 + 0.5).to_int().to_byte()
}
