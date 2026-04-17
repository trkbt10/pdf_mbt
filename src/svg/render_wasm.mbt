///|
/// wasm-gc target raster encoder: return raw RGBA bytes with the image/x-rgba8
/// MIME sentinel so the browser can use async canvas decoding.
fn encode_raster_image_entry(
  width : Int,
  height : Int,
  rgba : Bytes,
) -> SvgImageEntry? {
  Some(SvgImageEntry::{
    mime_type: raw_rgba_image_mime,
    data: rgba,
    width: Some(width),
    height: Some(height),
  })
}

///|
/// wasm-gc deferred SVG records only an image slot during rendering. The wasm
/// API surface lazily materializes raw RGBA image/x-rgba8 data when the JS
/// consumer asks for image data, keeping pageToSvgDeferred fast.
fn deferred_image_entry(
  _entry : PageImageEntry,
  _state : @graphics.GraphicsState,
) -> SvgImageEntry? {
  Some(SvgImageEntry::{ mime_type: "", data: b"", width: None, height: None })
}
