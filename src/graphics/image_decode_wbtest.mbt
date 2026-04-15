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
test "image extraction preserves unsupported encoded image codecs" {
  let stream = decode_test_image_stream(
    1,
    1,
    @objects.PdfName::new(b"DeviceRGB"),
    8,
    b"jpeg",
  )
  stream.dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"DCTDecode"),
  )
  let extracted = extract_image_xobject(None, stream, 2L)
  match extracted.data {
    EncodedImageData(bytes, filters) => {
      assert_eq(bytes, b"jpeg")
      assert_eq(filters[0] == @objects.PdfName::new(b"DCTDecode"), true)
    }
    _ => fail("expected encoded image data for DCTDecode")
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
