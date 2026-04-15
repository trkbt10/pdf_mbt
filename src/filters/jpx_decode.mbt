///|
/// JPXDecode JPEG 2000 image data returned by the filter integration.
/// The image pipeline integration uses these JPEG 2000 dimensions to
/// override PDF dictionary Width and Height, and uses num_components as the
/// component count override when the PDF dictionary colour space differs.
pub(all) struct JpxImageData {
  width : Int
  height : Int
  num_components : Int
  bits_per_component : Int
  is_signed : Bool
  data : Bytes
} derive(Eq, Debug)

///|
/// Decodes raw JPXDecode stream bytes by passing the PDF stream payload
/// directly to the JPEG 2000 decoder. The returned metadata supplies image
/// pipeline integration data: JPEG 2000 Width, Height, BitsPerComponent, and
/// component count override values for JPXDecode JPEG 2000 filter integration
/// decoded sample bytes.
pub fn decode_jpx_image(data : Bytes) -> JpxImageData raise PdfFilterError {
  let decoded = try @jpeg2000.decode(data) catch {
    error => raise PdfFilterError::DecodeError("JPXDecode", error.to_string())
  } noraise {
    image => image
  }
  let image = JpxImageData::{
    width: decoded.width,
    height: decoded.height,
    num_components: decoded.num_components,
    bits_per_component: decoded.bits_per_component,
    is_signed: decoded.is_signed,
    data: decoded.data,
  }
  image.validate_jpx_decode_payload()
  image
}

///|
fn JpxImageData::pixel_count(self : JpxImageData) -> Int {
  if self.width <= 0 || self.height <= 0 {
    0
  } else {
    self.width * self.height
  }
}

///|
fn JpxImageData::expected_sample_bytes(self : JpxImageData) -> Int {
  if self.num_components <= 0 || self.bits_per_component <= 0 {
    0
  } else {
    let total_bits = self.pixel_count() *
      self.num_components *
      self.bits_per_component
    (total_bits + 7) / 8
  }
}

///|
/// Returns the decoded sample byte count expected by PDF image integration
/// after JPXDecode supplies width, height, component count, and bits per
/// component from the JPEG 2000 codestream.
pub fn JpxImageData::pdf_image_sample_bytes(
  self : JpxImageData,
) -> Int raise PdfFilterError {
  if self.pixel_count() == 0 {
    raise PdfFilterError::DecodeError(
      "JPXDecode", "JPEG 2000 image dimensions must be positive",
    )
  }
  if self.num_components <= 0 {
    raise PdfFilterError::DecodeError(
      "JPXDecode", "JPEG 2000 component count must be positive",
    )
  }
  if self.bits_per_component <= 0 {
    raise PdfFilterError::DecodeError(
      "JPXDecode", "JPEG 2000 bits per component must be positive",
    )
  }
  self.expected_sample_bytes()
}

///|
fn JpxImageData::validate_jpx_decode_payload(
  self : JpxImageData,
) -> Unit raise PdfFilterError {
  let expected_sample_bytes = self.pdf_image_sample_bytes()
  if self.data.length() < expected_sample_bytes {
    raise PdfFilterError::DecodeError(
      "JPXDecode", "JPEG 2000 decoded sample data is truncated",
    )
  }
}

///|
fn decode_jpx(data : Bytes) -> Bytes raise PdfFilterError {
  decode_jpx_image(data).data
}
