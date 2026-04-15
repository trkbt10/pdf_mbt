///|
test "IccBasedParams from_profile_header extracts RGB count and intent" {
  let params = IccBasedParams::from_profile_header(
    icc_profile_test_header(b"RGB ", 2L),
  )
  assert_eq(params.component_count(), 3)
  assert_eq(params.range.length(), 3)
  match params.source {
    DirectProfile(info) => {
      assert_eq(info.data_colour_space == @objects.PdfName::new(b"RGB "), true)
      assert_eq(info.rendering_intent == RenderingIntent::Saturation, true)
    }
    IndirectProfile(_) => fail("expected direct profile header info")
  }
}

///|
test "IccBasedParams component count falls back for unresolved profiles" {
  let params = IccBasedParams::{
    source: IccProfileSource::IndirectProfile(@objects.ObjectId::{
      object_number: 10,
      generation_number: 0,
    }),
    component_count: 4,
    range: [
      ColourRange::{ min: 0.0, max: 1.0 },
      ColourRange::{ min: 0.0, max: 1.0 },
      ColourRange::{ min: 0.0, max: 1.0 },
      ColourRange::{ min: 0.0, max: 1.0 },
    ],
    alternate: None,
    metadata: None,
  }
  assert_eq(params.component_count(), 4)
  assert_eq(params.detected_component_count(), 4)
}

///|
test "ICC profile stream validation keeps rendering intent from header" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Integer(1L)
  let stream = @objects.PdfStream::{
    dict,
    data: icc_profile_test_header(b"GRAY", 3L),
  }
  let info = validate_icc_profile_stream(stream, 91L)
  assert_eq(info.component_count, 1)
  assert_eq(
    info.rendering_intent == RenderingIntent::AbsoluteColorimetric,
    true,
  )
}

///|
fn icc_profile_test_header(signature : Bytes, intent : Int64) -> Bytes {
  let data : Array[Byte] = []
  for _ in 0..<128 {
    data.push(b'\x00')
  }
  data[3] = b'\x80'
  data[12] = b'm'
  data[13] = b'n'
  data[14] = b't'
  data[15] = b'r'
  data[16] = signature[0]
  data[17] = signature[1]
  data[18] = signature[2]
  data[19] = signature[3]
  data[20] = b'X'
  data[21] = b'Y'
  data[22] = b'Z'
  data[23] = b' '
  data[36] = b'a'
  data[37] = b'c'
  data[38] = b's'
  data[39] = b'p'
  data[64] = ((intent >> 24) & 0xff).to_byte()
  data[65] = ((intent >> 16) & 0xff).to_byte()
  data[66] = ((intent >> 8) & 0xff).to_byte()
  data[67] = (intent & 0xff).to_byte()
  Bytes::from_array(data)
}
