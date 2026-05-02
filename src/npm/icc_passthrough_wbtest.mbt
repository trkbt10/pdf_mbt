///|
/// Confirms `is_browser_compatible_color_space` accepts a 1- or 3-component
/// `[/ICCBased <stream>]` colour space so the wasm-gc deferred-image pipeline
/// can hand the encoded JPEG bytes directly to the browser instead of
/// decoding them in wasm. This is the colour-space form used by every
/// recent design-tool slide exporter; without it, image-heavy pages
/// freeze the demo for tens of seconds per megapixel while the wasm-gc
/// JPEG decoder runs.
test "is_browser_compatible_color_space accepts ICCBased N=3" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
    @objects.PdfObject::Stream(@objects.PdfStream::{
      dict: icc_profile_dict(3L),
      data: b"",
    }),
  ])
  assert_eq(is_browser_compatible_color_space(dict), true)
  assert_eq(has_grayscale_color_space(dict), false)
}

///|
test "is_browser_compatible_color_space accepts ICCBased N=1 as grayscale" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
    @objects.PdfObject::Stream(@objects.PdfStream::{
      dict: icc_profile_dict(1L),
      data: b"",
    }),
  ])
  assert_eq(is_browser_compatible_color_space(dict), true)
  assert_eq(has_grayscale_color_space(dict), true)
}

///|
test "is_browser_compatible_color_space rejects ICCBased N=4 (CMYK)" {
  // Browsers can't faithfully present an ICC-tagged CMYK JPEG without the
  // wasm decoder's colour conversion, so the passthrough fast path must
  // bail out and let the slow path produce RGBA.
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
    @objects.PdfObject::Stream(@objects.PdfStream::{
      dict: icc_profile_dict(4L),
      data: b"",
    }),
  ])
  assert_eq(is_browser_compatible_color_space(dict), false)
}

///|
test "is_browser_compatible_color_space rejects ICCBased without N" {
  // A malformed ICC profile with no `/N` cannot be passthrough'd because we
  // don't know the component count.
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"ColorSpace")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"ICCBased")),
    @objects.PdfObject::Stream(@objects.PdfStream::{
      dict: Map::new(),
      data: b"",
    }),
  ])
  assert_eq(is_browser_compatible_color_space(dict), false)
}

///|
fn icc_profile_dict(n : Int64) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Integer(n)
  dict
}
