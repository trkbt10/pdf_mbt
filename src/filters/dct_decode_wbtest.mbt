///|
fn dct_test_jpeg(component_count : Int, entropy : Bytes) -> Bytes {
  let out : Array[Byte] = []
  dct_test_append_marker(out, 0xd8)
  dct_test_append_segment(out, 0xdb, dct_test_dqt_payload())
  dct_test_append_segment(out, 0xc0, dct_test_sof0_payload(component_count))
  dct_test_append_segment(out, 0xc4, dct_test_dht_payload())
  dct_test_append_segment(out, 0xda, dct_test_sos_payload(component_count))
  for byte in entropy {
    out.push(byte)
  }
  dct_test_append_marker(out, 0xd9)
  Bytes::from_array(out)
}

///|
fn dct_test_append_marker(out : Array[Byte], marker : Int) -> Unit {
  out.push(jpeg_byte(0xff))
  out.push(marker.to_byte())
}

///|
fn dct_test_append_segment(
  out : Array[Byte],
  marker : Int,
  payload : Array[Byte],
) -> Unit {
  dct_test_append_marker(out, marker)
  let length = payload.length() + 2
  out.push((length / 256).to_byte())
  out.push((length % 256).to_byte())
  out.append(payload)
}

///|
fn dct_test_dqt_payload() -> Array[Byte] {
  let payload : Array[Byte] = [jpeg_byte(0)]
  for _ in 0..<64 {
    payload.push(jpeg_byte(1))
  }
  payload
}

///|
fn dct_test_sof0_payload(component_count : Int) -> Array[Byte] {
  let payload : Array[Byte] = [
    jpeg_byte(8),
    jpeg_byte(0),
    jpeg_byte(8),
    jpeg_byte(0),
    jpeg_byte(8),
    component_count.to_byte(),
  ]
  for id in 1..<=component_count {
    payload.push(id.to_byte())
    payload.push(jpeg_byte(0x11))
    payload.push(jpeg_byte(0))
  }
  payload
}

///|
fn dct_test_dht_payload() -> Array[Byte] {
  let payload : Array[Byte] = []
  payload.push(jpeg_byte(0))
  for length in 1..<=16 {
    payload.push(if length == 2 { jpeg_byte(3) } else { jpeg_byte(0) })
  }
  payload.push(jpeg_byte(0))
  payload.push(jpeg_byte(9))
  payload.push(jpeg_byte(10))

  payload.push(jpeg_byte(0x10))
  for length in 1..<=16 {
    payload.push(if length == 1 { jpeg_byte(1) } else { jpeg_byte(0) })
  }
  payload.push(jpeg_byte(0))
  payload
}

///|
fn dct_test_sos_payload(component_count : Int) -> Array[Byte] {
  let payload : Array[Byte] = [component_count.to_byte()]
  for id in 1..<=component_count {
    payload.push(id.to_byte())
    payload.push(jpeg_byte(0))
  }
  payload.push(jpeg_byte(0))
  payload.push(jpeg_byte(63))
  payload.push(jpeg_byte(0))
  payload
}

///|
fn dct_test_pack_bits(bits : Array[Int]) -> Bytes {
  let output : Array[Byte] = []
  let mut current = 0
  let mut count = 0
  for bit in bits {
    current = (current << 1) | bit
    count += 1
    if count == 8 {
      dct_test_push_entropy_byte(output, current)
      current = 0
      count = 0
    }
  }
  if count > 0 {
    while count < 8 {
      current = (current << 1) | 1
      count += 1
    }
    dct_test_push_entropy_byte(output, current)
  }
  Bytes::from_array(output)
}

///|
fn dct_test_push_entropy_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
  if value == 0xff {
    output.push(jpeg_byte(0))
  }
}

///|
fn dct_test_append_bits(bits : Array[Int], value : Int, width : Int) -> Unit {
  let mut shift = width - 1
  while shift >= 0 {
    bits.push((value >> shift) & 1)
    shift -= 1
  }
}

///|
fn dct_test_red_ycbcr_entropy() -> Bytes {
  let bits : Array[Int] = []
  // DC table codes: category 0 => 00, category 9 => 01, category 10 => 10.
  // AC EOB table code: 0. DC values target Y=76, Cb=85, Cr=255.
  dct_test_append_bits(bits, 0b01, 2)
  dct_test_append_bits(bits, 95, 9)
  bits.push(0)
  dct_test_append_bits(bits, 0b01, 2)
  dct_test_append_bits(bits, 167, 9)
  bits.push(0)
  dct_test_append_bits(bits, 0b10, 2)
  dct_test_append_bits(bits, 1016, 10)
  bits.push(0)
  dct_test_pack_bits(bits)
}

///|
fn dct_test_zero_entropy(component_count : Int) -> Bytes {
  let bits : Array[Int] = []
  for _ in 0..<component_count {
    dct_test_append_bits(bits, 0b00, 2)
    bits.push(0)
  }
  dct_test_pack_bits(bits)
}

///|
fn dct_test_dct_dict(
  params : @objects.PdfDictionary?,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"DCTDecode"),
  )
  match params {
    Some(value) =>
      dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Dictionary(
        value,
      )
    None => ()
  }
  dict
}

///|
test "decode_dct decodes a minimal grayscale baseline JPEG" {
  let jpeg = dct_test_jpeg(1, dct_test_zero_entropy(1))
  let decoded = decode_dct(jpeg, DecodeParams::{ raw: None })
  assert_eq(decoded.length(), 64)
  for byte in decoded {
    assert_eq(byte, jpeg_byte(128))
  }
}

///|
test "decode_stream_bytes decodes DCTDecode YCbCr samples to RGB" {
  let jpeg = dct_test_jpeg(3, dct_test_red_ycbcr_entropy())
  let decoded = decode_stream_bytes(dct_test_dct_dict(None), jpeg)
  assert_eq(decoded.length(), 64 * 3)
  assert_eq(decoded[0], jpeg_byte(254))
  assert_eq(decoded[1], jpeg_byte(0))
  assert_eq(decoded[2], jpeg_byte(0))
}

///|
test "decode_dct respects DecodeParms ColorTransform zero" {
  let params : @objects.PdfDictionary = Map::new()
  params[@objects.PdfName::new(b"ColorTransform")] = @objects.PdfObject::Integer(
    0L,
  )
  let jpeg = dct_test_jpeg(3, dct_test_red_ycbcr_entropy())
  let decoded = decode_stream_bytes(dct_test_dct_dict(Some(params)), jpeg)
  assert_eq(decoded.length(), 64 * 3)
  assert_eq(decoded[0], jpeg_byte(76))
  assert_eq(decoded[1], jpeg_byte(85))
  assert_eq(decoded[2], jpeg_byte(255))
}
