///|
test "native DeviceRGB raster produces image/png entry" {
  let rgba = Bytes::from_array([255, 0, 0, 255])
  match raster_image_entry(1, 1, rgba) {
    Some(entry) => {
      assert_eq(entry.mime_type, "image/png")
      assert_true(entry.data.length() >= 4)
      assert_eq(entry.data[0].to_int(), 0x89)
      assert_eq(entry.data[1].to_int(), 0x50)
      assert_eq(entry.data[2].to_int(), 0x4e)
      assert_eq(entry.data[3].to_int(), 0x47)
      assert_eq(entry.width, None)
      assert_eq(entry.height, None)
    }
    None => assert_true(false)
  }
}
