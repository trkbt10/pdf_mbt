///|
pub fn decode_jpx_image(data : Bytes) -> JpxImageData raise PdfFilterError {
  let decoded = try @jpeg2000.decode(data) catch {
    error => raise PdfFilterError::DecodeError("JPXDecode", error.to_string())
  } noraise {
    image => image
  }
  JpxImageData::{
    width: decoded.width,
    height: decoded.height,
    num_components: decoded.num_components,
    bits_per_component: decoded.bits_per_component,
    is_signed: decoded.is_signed,
    data: decoded.data,
  }
}

///|
fn decode_jpx(data : Bytes) -> Bytes raise PdfFilterError {
  decode_jpx_image(data).data
}
