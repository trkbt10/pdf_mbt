///|
/// Native target raster encoder: keep the existing platform-dispatched PNG
/// path for DeviceRGB PDF image XObject data.
fn encode_raster_image_entry(
  width : Int,
  height : Int,
  rgba : Bytes,
) -> SvgImageEntry? {
  match image_data_from_rgba(width, height, rgba) {
    Some(image) =>
      match encode_png_bytes(image) {
        Some(bytes) =>
          Some(SvgImageEntry::{
            mime_type: "image/png",
            data: bytes,
            width: None,
            height: None,
          })
        None => None
      }
    None => None
  }
}

///|
/// Native deferred SVG keeps encoded image bytes in the render result so file
/// and CLI consumers continue to receive image/png entries directly.
fn deferred_image_entry(
  entry : PageImageEntry,
  state : @graphics.GraphicsState,
) -> SvgImageEntry? {
  page_image_entry_data(entry, state)
}
