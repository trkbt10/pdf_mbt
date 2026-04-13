///|
fn pack_lzw_codes(codes : Array[Int]) -> Bytes {
  let widths : Array[Int] = []
  let mut index = 0
  while index < codes.length() {
    widths.push(9)
    index = index + 1
  }
  pack_lzw_codes_with_widths(codes, widths)
}

///|
fn pack_lzw_codes_with_widths(codes : Array[Int], widths : Array[Int]) -> Bytes {
  let output : Array[Byte] = []
  let mut current_byte = 0
  let mut bits_filled = 0

  let mut index = 0
  while index < codes.length() {
    let code = codes[index]
    let mut remaining = widths[index]
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
    index = index + 1
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
test "decode_lzw handles the special current-code case" {
  let encoded = pack_lzw_codes([256, 65, 258, 257])
  let params = DecodeParams::{ raw: None }
  let decoded = decode_lzw(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'A', b'A', b'A']))
}

///|
test "decode_lzw grows to 10-bit codes after enough literals" {
  let codes : Array[Int] = [256]
  let widths : Array[Int] = [9]
  let mut literal_count = 0
  while literal_count < 254 {
    codes.push(65)
    widths.push(9)
    literal_count = literal_count + 1
  }
  codes.push(65)
  widths.push(10)
  codes.push(257)
  widths.push(10)

  let encoded = pack_lzw_codes_with_widths(codes, widths)
  let params = DecodeParams::{ raw: None }
  let decoded = decode_lzw(encoded, params)
  let expected : Array[Byte] = []
  let mut expected_count = 0
  while expected_count < 255 {
    expected.push(b'A')
    expected_count = expected_count + 1
  }
  assert_eq(decoded, Bytes::from_array(expected))
}

///|
test "decode_lzw grows the code width at the early-change threshold" {
  let decoder = LzwDecoder::new(Bytes::from_array([]), 1)
  assert_eq(decoder.code_width, 9)

  decoder.next_code = 511
  decoder.maybe_grow_code_width()
  assert_eq(decoder.code_width, 10)

  decoder.next_code = 1023
  decoder.maybe_grow_code_width()
  assert_eq(decoder.code_width, 11)

  decoder.next_code = 2047
  decoder.maybe_grow_code_width()
  assert_eq(decoder.code_width, 12)

  decoder.next_code = 4095
  decoder.maybe_grow_code_width()
  assert_eq(decoder.code_width, 12)
}

///|
test "decode_lzw delays width growth when EarlyChange is zero" {
  let decoder = LzwDecoder::new(Bytes::from_array([]), 0)
  assert_eq(decoder.code_width, 9)

  decoder.next_code = 511
  decoder.maybe_grow_code_width()
  assert_eq(decoder.code_width, 9)

  decoder.next_code = 512
  decoder.maybe_grow_code_width()
  assert_eq(decoder.code_width, 10)
}

///|
test "decode_lzw rejects unsupported EarlyChange values" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"EarlyChange")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let encoded = pack_lzw_codes([256, 65, 257])
  let decoded : Result[Bytes, PdfFilterError] = try? decode_lzw(encoded, params)
  match decoded {
    Err(InvalidDecodeParms(filter_name, reason)) => {
      assert_eq(filter_name, "LZWDecode")
      assert_eq(reason.contains("EarlyChange"), true)
    }
    _ => fail("expected unsupported EarlyChange to fail")
  }
}

///|
test "decode_lzw stops adding table entries after the 4096-entry cap" {
  let decoder = LzwDecoder::new(Bytes::from_array([]), 1)
  decoder.table = Array::make(lzw_table_capacity, None)
  decoder.next_code = lzw_table_capacity
  decoder.code_width = 12
  decoder.previous_sequence = Some([b'A'])

  let table_length = decoder.table.length()
  decoder.extend_table([b'A'], [b'B'])

  assert_eq(decoder.table.length(), table_length)
  assert_eq(decoder.next_code, lzw_table_capacity)
  assert_eq(decoder.code_width, 12)
}

///|
test "decode_lzw rejects a current-code reference without a previous sequence" {
  let encoded = pack_lzw_codes([256, 258, 257])
  let params = DecodeParams::{ raw: None }
  let decoded : Result[Bytes, PdfFilterError] = try? decode_lzw(encoded, params)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "LZWDecode")
      assert_eq(reason.contains("invalid"), true)
    }
    _ => fail("expected invalid current-code reference to fail")
  }
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
