///|
/// Implements Requirement 10 `PdfImage` public image facade type. `PdfImage`
/// represents an image XObject referenced by page content; each `PdfImage`
/// SHALL expose width, height, bits per component, colour space information,
/// image metadata, and RGBA pixel access.
pub(all) struct PdfImage {
  name : @objects.PdfName?
  stream : @objects.PdfStream
  descriptor : @graphics.ImageDescriptor
  data : @graphics.ExtractedImageData
} derive(Eq, Debug)

///|
/// Enumerates all image XObjects referenced by a page's resources and returns
/// decoded image descriptors where the current library can materialize them.
pub fn page_images(page : PdfPage) -> Array[PdfImage] {
  let resources_result : Result[
    @content.ContentResources,
    @reader.PdfDocumentError,
  ] = try? page.inner.materialized_content_resources()
  match resources_result {
    Ok(resources) => images_from_resources(resources)
    Err(_) => []
  }
}

///|
/// Page-level image extraction API for enumerating image XObjects.
pub fn PdfPage::images(self : PdfPage) -> Array[PdfImage] {
  page_images(self)
}

///|
/// Implements Requirement 3.2 image pixel access:
/// `PdfImage::to_rgba() -> Bytes` SHALL return the image as RGBA pixel data
/// with 4 bytes per pixel in row-major order. DCTDecode JPEG and unsupported
/// filters are surfaced through `PdfPage::images_with_warnings()`.
pub fn PdfImage::to_rgba(self : PdfImage) -> Bytes {
  match self.data {
    DeviceRgbRaster(raster) => raster.rgba
    StencilMaskRaster(mask) => stencil_mask_to_rgba(mask)
    EncodedImageData(_, _) => b""
  }
}

///|
/// Implements Requirement 3.3 image metadata:
/// `PdfImage::width() -> Int` SHALL expose image width without requiring
/// pixel decoding.
pub fn PdfImage::width(self : PdfImage) -> Int {
  self.descriptor.width
}

///|
/// Implements Requirement 3.3 image metadata:
/// `PdfImage::height() -> Int` SHALL expose image height without requiring
/// pixel decoding.
pub fn PdfImage::height(self : PdfImage) -> Int {
  self.descriptor.height
}

///|
/// Implements Requirement 3.3 image metadata:
/// `PdfImage::color_space() -> String` SHALL expose colour space information
/// without requiring pixel decoding.
pub fn PdfImage::color_space(self : PdfImage) -> String {
  match self.descriptor.color_space {
    Some(space) => colour_space_label(space)
    None => ""
  }
}

///|
fn images_from_resources(
  resources : @content.ContentResources,
) -> Array[PdfImage] {
  let result : Result[@objects.PdfObject?, @content.PdfContentError] = try? resources.category_object(
    @content.ResourceCategory::XObject,
  )
  match result {
    Ok(Some(@objects.PdfObject::Dictionary(xobjects))) => {
      let images : Array[PdfImage] = []
      collect_xobject_images(xobjects, resources.dictionary, images)
      images
    }
    _ => []
  }
}

///|
fn collect_xobject_images(
  xobjects : @objects.PdfDictionary,
  resources : @objects.PdfDictionary?,
  images : Array[PdfImage],
) -> Unit {
  for name, object in xobjects {
    match object {
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Image") =>
        collect_one_image(name, prepare_image_stream(stream, resources), images)
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Form") =>
        collect_form_images(stream, images)
      _ => ()
    }
  }
}

///|
fn collect_form_images(
  stream : @objects.PdfStream,
  images : Array[PdfImage],
) -> Unit {
  match stream.dict.get(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(resources)) =>
      match resources.get(@objects.PdfName::new(b"XObject")) {
        Some(@objects.PdfObject::Dictionary(xobjects)) =>
          collect_xobject_images(xobjects, Some(resources), images)
        _ => ()
      }
    _ => ()
  }
}

///|
fn collect_one_image(
  name : @objects.PdfName,
  stream : @objects.PdfStream,
  images : Array[PdfImage],
) -> Unit {
  let result : Result[@graphics.ExtractedImage, @graphics.PdfGraphicsError] = try? @graphics.extract_image_xobject(
    Some(name),
    stream,
    0L,
  )
  match result {
    Ok(extracted) =>
      images.push(PdfImage::{
        name: Some(name),
        stream,
        descriptor: extracted.descriptor,
        data: extracted.data,
      })
    Err(_) => ()
  }
}

///|
fn prepare_image_stream(
  stream : @objects.PdfStream,
  resources : @objects.PdfDictionary?,
) -> @objects.PdfStream {
  let dict = stream.dict.copy()
  materialize_named_resource_entry(dict, resources, b"ColorSpace")
  @objects.PdfStream::{ dict, data: stream.data }
}

///|
fn materialize_named_resource_entry(
  dict : @objects.PdfDictionary,
  resources : @objects.PdfDictionary?,
  key_bytes : Bytes,
) -> Unit {
  let key = @objects.PdfName::new(key_bytes)
  match (dict.get(key), resources) {
    (Some(@objects.PdfObject::Name(name)), Some(resource_dict)) =>
      match resource_dict.get(key) {
        Some(@objects.PdfObject::Dictionary(named_resources)) =>
          match named_resources.get(name) {
            Some(value) => dict[key] = value
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn stream_subtype_is(stream : @objects.PdfStream, expected : Bytes) -> Bool {
  match stream.dict.get(@objects.PdfName::new(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(expected)
    _ => false
  }
}

///|
fn stencil_mask_to_rgba(mask : @graphics.ImageAlphaMaskRaster) -> Bytes {
  let rgba : Array[Byte] = []
  for alpha in mask.alpha {
    rgba.push(0x00)
    rgba.push(0x00)
    rgba.push(0x00)
    rgba.push(alpha)
  }
  Bytes::from_array(rgba)
}

///|
fn colour_space_label(space : @graphics.ColourSpace) -> String {
  match space {
    Device(device) =>
      match device {
        DeviceGray => "DeviceGray"
        DeviceRGB => "DeviceRGB"
        DeviceCMYK => "DeviceCMYK"
      }
    CalGray(_) => "CalGray"
    CalRGB(_) => "CalRGB"
    Lab(_) => "Lab"
    ICCBased(_) => "ICCBased"
    Pattern(_) => "Pattern"
    Indexed(_) => "Indexed"
    Separation(_) => "Separation"
    DeviceN(_) => "DeviceN"
  }
}
