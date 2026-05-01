///|
priv struct ImageExtractionStats {
  mut image_count : Int
  mut decoded_count : Int
  mut device_rgb_count : Int
  mut valid_device_rgb_count : Int
}

///|
test "E2E: extract CalRGB and DeviceRGB image XObjects from PDF 2.0 BPC example" {
  let bytes = @fs.read_file_to_bytes(
    "spec/pdf20examples/PDF 2.0 image with BPC.pdf",
  )
  let document = PdfDocument::open(bytes)
  let stats = document_image_extraction_stats(document)

  assert_true(stats.image_count >= 2)
  assert_true(stats.device_rgb_count >= 1)
  assert_true(stats.valid_device_rgb_count >= 1)
}

///|
test "E2E: Simple PDF 2.0 has no image XObjects" {
  let document = PdfDocument::open(simple_pdf20_file)
  let stats = document_image_extraction_stats(document)

  assert_eq(stats.image_count, 0)
}

///|
test "E2E: page-level output intent PDF image XObjects decode per page" {
  let bytes = @fs.read_file_to_bytes(
    "spec/pdf20examples/PDF 2.0 with page level output intent.pdf",
  )
  let document = PdfDocument::open(bytes)
  assert_eq(document.page_count(), 2)

  for page in document.pages() {
    let stats = page_image_extraction_stats(page)
    assert_true(stats.image_count > 0)
    assert_eq(stats.decoded_count, stats.image_count)
    assert_eq(stats.valid_device_rgb_count, stats.image_count)
  }
}

///|
fn document_image_extraction_stats(
  document : PdfDocument,
) -> ImageExtractionStats raise {
  let stats = empty_image_extraction_stats()
  for page in document.pages() {
    merge_image_extraction_stats(stats, page_image_extraction_stats(page))
  }
  stats
}

///|
fn page_image_extraction_stats(page : PdfPage) -> ImageExtractionStats raise {
  let stats = empty_image_extraction_stats()
  match resolve_optional_image_resource_object(page.file, page.resources()) {
    Some(@objects.PdfObject::Dictionary(resources)) =>
      collect_xobject_image_stats(page.file, resources, stats)
    Some(@objects.PdfObject::Null) | None => ()
    Some(_) => fail("page Resources must resolve to a dictionary or be absent")
  }
  stats
}

///|
fn collect_xobject_image_stats(
  file : PdfFile,
  resources : @objects.PdfDictionary,
  stats : ImageExtractionStats,
) -> Unit raise {
  match resources.get(@objects.PdfName::new(b"XObject")) {
    Some(object) =>
      match resolve_image_resource_object(file, object) {
        @objects.PdfObject::Dictionary(xobjects) =>
          for name, object in xobjects {
            match resolve_image_resource_object(file, object) {
              @objects.PdfObject::Stream(stream) if image_stream_subtype_is_image(
                  stream,
                ) => collect_one_image_xobject_stat(file, name, stream, stats)
              _ => ()
            }
          }
        @objects.PdfObject::Null => ()
        _ => fail("XObject resources must resolve to a dictionary")
      }
    None => ()
  }
}

///|
fn collect_one_image_xobject_stat(
  file : PdfFile,
  name : @objects.PdfName,
  stream : @objects.PdfStream,
  stats : ImageExtractionStats,
) -> Unit raise {
  stats.image_count += 1
  let extracted = @graphics.extract_image_xobject(
    Some(name),
    materialize_image_xobject_stream(file, stream),
    0L,
  )
  match extracted.data {
    DeviceRgbRaster(raster) => {
      stats.decoded_count += 1
      stats.device_rgb_count += 1
      assert_device_rgb_raster_is_valid(raster)
      stats.valid_device_rgb_count += 1
    }
    StencilMaskRaster(_) => stats.decoded_count += 1
    EncodedImageData(_, _) => ()
  }
}

///|
fn assert_device_rgb_raster_is_valid(
  raster : @graphics.ImageDeviceRgbRaster,
) -> Unit raise {
  assert_true(raster.width > 0)
  assert_true(raster.height > 0)
  assert_eq(raster.rgba.length(), raster.width * raster.height * 4)
  assert_true(raster.rgba.length() >= 4)
  assert_true(
    raster.rgba[0] != 0 ||
    raster.rgba[1] != 0 ||
    raster.rgba[2] != 0 ||
    raster.rgba[3] != 0,
  )
  assert_eq(raster.rgba[3], 0xff)
}

///|
fn materialize_image_xobject_stream(
  file : PdfFile,
  stream : @objects.PdfStream,
) -> @objects.PdfStream raise {
  let dict = stream.dict.copy()
  materialize_image_xobject_entry(file, dict, b"ColorSpace")
  materialize_image_xobject_entry(file, dict, b"Mask")
  materialize_image_xobject_entry(file, dict, b"SMask")
  @objects.PdfStream::{ dict, data: stream.data }
}

///|
fn materialize_image_xobject_entry(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key_bytes : Bytes,
) -> Unit raise {
  let key = @objects.PdfName::new(key_bytes)
  match dict.get(key) {
    Some(object) =>
      dict[key] = resolve_nested_image_resource_object(file, object)
    None => ()
  }
}

///|
fn resolve_nested_image_resource_object(
  file : PdfFile,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise {
  match object {
    @objects.PdfObject::Ref(id) =>
      resolve_nested_image_resource_object(
        file,
        resolve_indirect(file, @objects.PdfObject::Ref(id)),
      )
    @objects.PdfObject::Array(values) => {
      let resolved : Array[@objects.PdfObject] = []
      for value in values {
        resolved.push(resolve_nested_image_resource_object(file, value))
      }
      @objects.PdfObject::Array(resolved)
    }
    @objects.PdfObject::Dictionary(dict) => {
      let resolved : @objects.PdfDictionary = Map::new()
      for key, value in dict {
        resolved[key] = resolve_nested_image_resource_object(file, value)
      }
      @objects.PdfObject::Dictionary(resolved)
    }
    @objects.PdfObject::Stream(stream) =>
      @objects.PdfObject::Stream(materialize_image_xobject_stream(file, stream))
    _ => object
  }
}

///|
fn image_stream_subtype_is_image(stream : @objects.PdfStream) -> Bool {
  match stream.dict.get(@objects.PdfName::new(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(b"Image")
    _ => false
  }
}

///|
fn resolve_optional_image_resource_object(
  file : PdfFile,
  object : @objects.PdfObject?,
) -> @objects.PdfObject? raise {
  match object {
    Some(value) => Some(resolve_image_resource_object(file, value))
    None => None
  }
}

///|
fn resolve_image_resource_object(
  file : PdfFile,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise {
  match object {
    @objects.PdfObject::Ref(_) => resolve_indirect(file, object)
    _ => object
  }
}

///|
fn empty_image_extraction_stats() -> ImageExtractionStats {
  ImageExtractionStats::{
    image_count: 0,
    decoded_count: 0,
    device_rgb_count: 0,
    valid_device_rgb_count: 0,
  }
}

///|
fn merge_image_extraction_stats(
  target : ImageExtractionStats,
  source : ImageExtractionStats,
) -> Unit {
  target.image_count += source.image_count
  target.decoded_count += source.decoded_count
  target.device_rgb_count += source.device_rgb_count
  target.valid_device_rgb_count += source.valid_device_rgb_count
}
