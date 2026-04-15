///|
test "image extraction decodes one-bit rows with byte padding to DeviceRGB" {
  let stream = decode_test_image_stream(
    2,
    2,
    @objects.PdfName::new(b"DeviceGray"),
    1,
    Bytes::from_array([0b10000000, 0b01000000]),
  )
  let extracted = extract_image_xobject(
    Some(@objects.PdfName::new(b"Im1")),
    stream,
    1L,
  )
  match extracted.data {
    DeviceRgbRaster(raster) => {
      assert_eq(raster.width, 2)
      assert_eq(raster.height, 2)
      assert_eq(
        raster.rgba,
        Bytes::from_array([
          255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255, 255,
        ]),
      )
    }
    _ => fail("expected decoded DeviceRGB raster")
  }
}

///|
test "sample value decoding unpacks 2 4 and 16 bit components" {
  let two_bit = ImageSampleLayout::from_values(4, 1, 1, 2)
  assert_eq(
    decode_image_sample_values(Bytes::from_array([0b00011011]), two_bit),
    [0, 1, 2, 3],
  )

  let four_bit = ImageSampleLayout::from_values(2, 1, 3, 4)
  assert_eq(
    decode_image_sample_values(Bytes::from_array([0x12, 0x34, 0x56]), four_bit),
    [1, 2, 3, 4, 5, 6],
  )

  let sixteen_bit = ImageSampleLayout::from_values(2, 1, 1, 16)
  assert_eq(
    decode_image_sample_values(
      Bytes::from_array([0x12, 0x34, 0xab, 0xcd]),
      sixteen_bit,
    ),
    [4660, 43981],
  )
}

///|
test "image dictionary validation reports expected decoded stream length" {
  let layout = ImageSampleLayout::from_values(3, 2, 3, 8)
  let validation = layout.validate_stream_length(18)

  assert_eq(validation.width, 3)
  assert_eq(validation.height, 2)
  assert_eq(validation.component_count, 3)
  assert_eq(validation.bits_per_component, 8)
  assert_eq(validation.expected_stream_length, 18)
  assert_eq(validation.actual_stream_length, 18)
}

///|
test "Decode array application maps raw samples into component ranges" {
  let layout = ImageSampleLayout::from_values(2, 1, 3, 8)
  let decoded = apply_image_decode_array([0, 255, 255, 255, 0, 0], layout, [
    ImageDecodeRange::{ min: 0.0, max: 1.0 },
    ImageDecodeRange::{ min: 1.0, max: 0.0 },
    ImageDecodeRange::{ min: 0.0, max: 2.0 },
  ])

  assert_eq(decoded, [0.0, 0.0, 2.0, 1.0, 1.0, 0.0])
}

///|
test "stencil mask painting combines one-bit mask with paint colour" {
  let mask = ImageAlphaMaskRaster::{
    width: 2,
    height: 1,
    alpha: Bytes::from_array([255, 0]),
  }
  let raster = paint_stencil_mask_with_colour(mask, DeviceRgbColour::{
    red: 1.0,
    green: 0.5,
    blue: 0.0,
  })

  assert_eq(raster.rgba, Bytes::from_array([255, 128, 0, 255, 255, 128, 0, 0]))
}

///|
test "image extraction preserves unsupported encoded image codecs" {
  let stream = decode_test_image_stream(
    1,
    1,
    @objects.PdfName::new(b"DeviceRGB"),
    8,
    b"jpx",
  )
  stream.dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"JPXDecode"),
  )
  let extracted = extract_image_xobject(None, stream, 2L)
  match extracted.data {
    EncodedImageData(bytes, filters) => {
      assert_eq(bytes, b"jpx")
      assert_eq(filters[0] == @objects.PdfName::new(b"JPXDecode"), true)
    }
    _ => fail("expected encoded image data for JPXDecode")
  }
}

///|
test "image extraction returns ImageMask data as stencil alpha" {
  let stream = decode_test_image_mask_stream(
    2,
    1,
    Bytes::from_array([0b10000000]),
  )
  let extracted = extract_image_xobject(None, stream, 3L)
  match extracted.data {
    StencilMaskRaster(mask) => {
      assert_eq(mask.width, 2)
      assert_eq(mask.height, 1)
      assert_eq(mask.alpha, Bytes::from_array([255, 0]))
    }
    _ => fail("expected stencil alpha mask")
  }
}

///|
test "image extraction applies colour-key mask as RGBA alpha" {
  let stream = decode_test_image_stream(
    2,
    1,
    @objects.PdfName::new(b"DeviceRGB"),
    8,
    Bytes::from_array([255, 0, 0, 0, 0, 255]),
  )
  stream.dict[@objects.PdfName::new(b"Mask")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(255L),
    @objects.PdfObject::Integer(255L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
  ])
  let extracted = extract_image_xobject(None, stream, 4L)
  match extracted.data {
    DeviceRgbRaster(raster) =>
      assert_eq(raster.rgba, Bytes::from_array([255, 0, 0, 0, 0, 0, 255, 255]))
    _ => fail("expected colour-key RGBA raster")
  }
}

///|
test "image extraction applies direct soft mask alpha" {
  let stream = decode_test_image_stream(
    2,
    1,
    @objects.PdfName::new(b"DeviceRGB"),
    8,
    Bytes::from_array([10, 20, 30, 40, 50, 60]),
  )
  stream.dict[@objects.PdfName::new(b"SMask")] = @objects.PdfObject::Stream(
    decode_test_image_stream(
      2,
      1,
      @objects.PdfName::new(b"DeviceGray"),
      8,
      Bytes::from_array([0, 128]),
    ),
  )
  let extracted = extract_image_xobject(None, stream, 5L)
  match extracted.data {
    DeviceRgbRaster(raster) =>
      assert_eq(
        raster.rgba,
        Bytes::from_array([10, 20, 30, 0, 40, 50, 60, 128]),
      )
    _ => fail("expected soft-mask RGBA raster")
  }
}

///|
test "inline image extraction decodes abbreviated dictionary data" {
  let content = @content.parse_decoded_content(
    Bytes::from_array([
      b'B', b'I', b' ', b'/', b'W', b' ', b'1', b' ', b'/', b'H', b' ', b'1', b' ',
      b'/', b'C', b'S', b' ', b'/', b'R', b'G', b'B', b' ', b'/', b'B', b'P', b'C',
      b' ', b'8', b' ', b'/', b'L', b' ', b'3', b' ', b'I', b'D', b' ', 1, 2, 3,
      b' ', b'E', b'I',
    ]),
    @content.ContentResources::empty(),
  )
  match content.instructions[0] {
    @content.ContentInstruction::InlineImage(image) => {
      let extracted = extract_inline_image(image)
      match extracted.data {
        DeviceRgbRaster(raster) =>
          assert_eq(raster.rgba, Bytes::from_array([1, 2, 3, 255]))
        _ => fail("expected inline image RGB raster")
      }
    }
    _ => fail("expected inline image instruction")
  }
}

///|
fn decode_test_image_stream(
  width : Int,
  height : Int,
  color_space : @objects.PdfName,
  bits_per_component : Int,
  data : Bytes,
) -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"XObject"),
  )
  dict[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Image"),
  )
  dict[@objects.PdfName::new(b"Width")] = @objects.PdfObject::Integer(
    width.to_int64(),
  )
  dict[@objects.PdfName::new(b"Height")] = @objects.PdfObject::Integer(
    height.to_int64(),
  )
  dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Name(
    color_space,
  )
  dict[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    bits_per_component.to_int64(),
  )
  @objects.PdfStream::{ dict, data }
}

///|
fn decode_test_image_mask_stream(
  width : Int,
  height : Int,
  data : Bytes,
) -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"XObject"),
  )
  dict[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Image"),
  )
  dict[@objects.PdfName::new(b"Width")] = @objects.PdfObject::Integer(
    width.to_int64(),
  )
  dict[@objects.PdfName::new(b"Height")] = @objects.PdfObject::Integer(
    height.to_int64(),
  )
  dict[@objects.PdfName::new(b"ImageMask")] = @objects.PdfObject::Boolean(true)
  dict[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    1L,
  )
  @objects.PdfStream::{ dict, data }
}
