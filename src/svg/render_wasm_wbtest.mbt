///|
test "wasm DeviceRGB raster produces image/x-rgba8 entry" {
  let rgba = Bytes::from_array([255, 0, 0, 255, 0, 255, 0, 255])
  match raster_image_entry(2, 1, rgba) {
    Some(entry) => {
      assert_eq(entry.mime_type, raw_rgba_image_mime)
      assert_eq(entry.mime_type, "image/x-rgba8")
      assert_eq(entry.data, rgba)
      assert_eq(entry.data.length(), 2 * 1 * 4)
      assert_eq(entry.width, Some(2))
      assert_eq(entry.height, Some(1))
    }
    None => assert_true(false)
  }
}
