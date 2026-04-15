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
