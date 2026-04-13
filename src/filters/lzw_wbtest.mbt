///|
fn pack_lzw_codes(codes : Array[Int]) -> Bytes {
  let output : Array[Byte] = []
  let mut current_byte = 0
  let mut bits_filled = 0

  for code in codes {
    let mut remaining = 9
    while remaining > 0 {
      let shift = remaining - 1
      let bit = (code >> shift) & 1
      current_byte = (current_byte << 1) | bit
      bits_filled = bits_filled + 1
      remaining = remaining - 1

      if bits_filled == 8 {
        output.push(current_byte.to_byte())
        current_byte = 0
        bits_filled = 0
      }
    }
  }

  if bits_filled > 0 {
    current_byte = current_byte << (8 - bits_filled)
    output.push(current_byte.to_byte())
  }

  Bytes::from_array(output)
}

///|
test "decode_lzw requires a clear-table startup and decodes literal bytes" {
  let encoded = pack_lzw_codes([256, 65, 66, 67, 257])
  let params = DecodeParams::{ raw: None }
  let decoded = decode_lzw(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'A', b'B', b'C']))
}

///|
test "decode_lzw resets the table when it sees a clear code" {
  let encoded = pack_lzw_codes([256, 65, 66, 256, 67, 68, 257])
  let params = DecodeParams::{ raw: None }
  let decoded = decode_lzw(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'A', b'B', b'C', b'D']))
}

///|
test "decode_lzw rejects streams that do not start with clear-table" {
  let encoded = pack_lzw_codes([65, 257])
  let params = DecodeParams::{ raw: None }
  let decoded : Result[Bytes, PdfFilterError] = try? decode_lzw(encoded, params)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "LZWDecode")
      assert_eq(reason.contains("clear"), true)
    }
    _ => fail("expected missing clear-table startup to fail")
  }
}

///|
test "decode_lzw rejects streams that end before the EOD code" {
  let encoded = pack_lzw_codes([256, 65, 66])
  let params = DecodeParams::{ raw: None }
  let decoded : Result[Bytes, PdfFilterError] = try? decode_lzw(encoded, params)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "LZWDecode")
      assert_eq(reason.contains("end"), true)
    }
    _ => fail("expected missing EOD to fail")
  }
}
