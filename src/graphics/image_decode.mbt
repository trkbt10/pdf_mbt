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
/// Extracted image data. Supported sample-byte filters are expanded into
/// DeviceRGB pixels; unsupported encoded image codecs such as DCTDecode,
/// JPXDecode, JBIG2Decode, CCITTFaxDecode, and Crypt preserve their original
/// encoded bytes and filter names for a downstream codec.
pub(all) enum ExtractedImageData {
  DeviceRgbRaster(ImageDeviceRgbRaster)
  EncodedImageData(Bytes, Array[@objects.PdfName])
} derive(Eq, Debug)

///|
/// Validated image descriptor paired with extracted byte-level image data.
pub(all) struct ExtractedImage {
  descriptor : ImageDescriptor
  data : ExtractedImageData
} derive(Eq, Debug)

///|
/// Validates and extracts an image XObject stream. This decodes filters already
/// supported by `filters.decode_stream`, interprets the decoded bytes using the
/// image Width, Height, BitsPerComponent, Decode, and row-padding rules, and
/// converts supported colour spaces to DeviceRGB for display-oriented callers.
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
      ExtractedImageData::EncodedImageData(data, descriptor.filters.copy())
    Err(error) =>
      raise PdfGraphicsError::InvalidImage(
        offset,
        "image stream filter decode failed: " + filter_error_label(error),
      )
  }
}

///|
fn decode_sample_bytes_to_rgb(
  descriptor : ImageDescriptor,
  decoded : Bytes,
  offset : Int64,
) -> ExtractedImageData raise PdfGraphicsError {
  if descriptor.image_mask {
    return ExtractedImageData::EncodedImageData(
      decoded,
      descriptor.filters.copy(),
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
  let samples = unpack_image_samples(decoded, descriptor.layout, offset)
  let rgba : Array[Byte] = []
  for pixel in 0..<(descriptor.width * descriptor.height) {
    let (r, g, b) = pixel_to_device_rgb(
      space,
      descriptor.decode,
      descriptor.bits_per_component.unwrap(),
      samples,
      pixel,
      offset,
    )
    rgba.push(unit_to_byte(r))
    rgba.push(unit_to_byte(g))
    rgba.push(unit_to_byte(b))
    rgba.push(b'\xff')
  }
  ExtractedImageData::DeviceRgbRaster(ImageDeviceRgbRaster::{
    width: descriptor.width,
    height: descriptor.height,
    rgba: Bytes::from_array(rgba),
  })
}

///|
fn unpack_image_samples(
  data : Bytes,
  layout : ImageSampleLayout,
  offset : Int64,
) -> Array[Int] raise PdfGraphicsError {
  if layout.bits_per_component <= 0 || layout.component_count <= 0 {
    raise PdfGraphicsError::InvalidImage(
      offset, "image sample layout cannot be decoded",
    )
  }
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
    Device(DeviceGray) | CalGray(_) | Separation(_) =>
      (
        clamp_double(components[0], 0.0, 1.0),
        clamp_double(components[0], 0.0, 1.0),
        clamp_double(components[0], 0.0, 1.0),
      )
    Device(DeviceRGB) | CalRGB(_) =>
      (
        clamp_double(components[0], 0.0, 1.0),
        clamp_double(components[1], 0.0, 1.0),
        clamp_double(components[2], 0.0, 1.0),
      )
    Device(DeviceCMYK) => cmyk_to_rgb(components)
    Lab(_) => {
      let l = clamp_double(components[0] / 100.0, 0.0, 1.0)
      (l, l, l)
    }
    ICCBased(params) =>
      if components.length() == 1 {
        (
          clamp_double(components[0], 0.0, 1.0),
          clamp_double(components[0], 0.0, 1.0),
          clamp_double(components[0], 0.0, 1.0),
        )
      } else if components.length() == 3 {
        (
          clamp_double(components[0], 0.0, 1.0),
          clamp_double(components[1], 0.0, 1.0),
          clamp_double(components[2], 0.0, 1.0),
        )
      } else if components.length() == 4 {
        cmyk_to_rgb(components)
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
fn cmyk_to_rgb(components : Array[Double]) -> (Double, Double, Double) {
  let c = clamp_double(components[0], 0.0, 1.0)
  let m = clamp_double(components[1], 0.0, 1.0)
  let y = clamp_double(components[2], 0.0, 1.0)
  let k = clamp_double(components[3], 0.0, 1.0)
  (
    1.0 - clamp_double(c + k, 0.0, 1.0),
    1.0 - clamp_double(m + k, 0.0, 1.0),
    1.0 - clamp_double(y + k, 0.0, 1.0),
  )
}

///|
fn unit_to_byte(value : Double) -> Byte {
  @math.floor(clamp_double(value, 0.0, 1.0) * 255.0 + 0.5).to_int().to_byte()
}
