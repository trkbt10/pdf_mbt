///|
fn pack_ccitt_test_bits(pattern : String) -> Bytes {
  let output : Array[Byte] = []
  let mut current_byte = 0
  let mut bits_filled = 0
  let mut index = 0
  while index < pattern.length() {
    let bit = if pattern.code_unit_at(index) == '1' { 1 } else { 0 }
    current_byte = (current_byte << 1) | bit
    bits_filled += 1
    if bits_filled == 8 {
      output.push(current_byte.to_byte())
      current_byte = 0
      bits_filled = 0
    }
    index += 1
  }
  if bits_filled > 0 {
    output.push((current_byte << (8 - bits_filled)).to_byte())
  }
  Bytes::from_array(output)
}

///|
fn ccitt_test_params(k : Int64, columns : Int64, rows : Int64) -> DecodeParams {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"K")] = @objects.PdfObject::Integer(k)
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(columns)
  raw[@objects.PdfName::new(b"Rows")] = @objects.PdfObject::Integer(rows)
  DecodeParams::{ raw: Some(raw) }
}

///|
test "decode_ccitt_fax decodes Group 3 one-dimensional runs" {
  let params = ccitt_test_params(0L, 8L, 1L)
  let encoded = pack_ccitt_test_bits("1000111000")
  let decoded = decode_ccitt_fax(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'\xe7']))
}

///|
test "decode_ccitt_fax applies BlackIs1 output polarity" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"K")] = @objects.PdfObject::Integer(0L)
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(8L)
  raw[@objects.PdfName::new(b"Rows")] = @objects.PdfObject::Integer(1L)
  raw[@objects.PdfName::new(b"BlackIs1")] = @objects.PdfObject::Boolean(true)
  let params = DecodeParams::{ raw: Some(raw) }
  let encoded = pack_ccitt_test_bits("1000111000")
  let decoded = decode_ccitt_fax(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'\x18']))
}

///|
test "decode_ccitt_fax combines Group 3 make-up and terminating codes" {
  let params = ccitt_test_params(0L, 70L, 1L)
  let encoded = pack_ccitt_test_bits("11011001101010010")
  let decoded = decode_ccitt_fax(encoded, params)
  assert_eq(
    decoded,
    Bytes::from_array([
      b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\x00',
    ]),
  )
}

///|
test "decode_ccitt_fax decodes Group 4 horizontal pass and vertical modes" {
  let params = ccitt_test_params(-1L, 8L, 2L)
  let encoded = pack_ccitt_test_bits(
    "0010011010111100011000000000001000000000001",
  )
  let decoded = decode_ccitt_fax(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'\x3f', b'\xff']))
}

///|
test "decode_ccitt_fax decodes mixed Group 3 one-dimensional and two-dimensional lines" {
  let params = ccitt_test_params(2L, 8L, 2L)
  let encoded = pack_ccitt_test_bits("0011010111111000011")
  let decoded = decode_ccitt_fax(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'\x3f', b'\xff']))
}

///|
test "decode_ccitt_fax accepts EOL-prefixed Group 3 lines" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"K")] = @objects.PdfObject::Integer(0L)
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(8L)
  raw[@objects.PdfName::new(b"Rows")] = @objects.PdfObject::Integer(1L)
  raw[@objects.PdfName::new(b"EndOfLine")] = @objects.PdfObject::Boolean(true)
  let params = DecodeParams::{ raw: Some(raw) }
  let encoded = pack_ccitt_test_bits("0000000000011000111000")
  let decoded = decode_ccitt_fax(encoded, params)
  assert_eq(decoded, Bytes::from_array([b'\xe7']))
}

///|
test "decode_ccitt_fax rejects malformed boolean DecodeParms" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"BlackIs1")] = @objects.PdfObject::Integer(1L)
  let params = DecodeParams::{ raw: Some(raw) }
  let decoded : Result[Bytes, PdfFilterError] = try? decode_ccitt_fax(
    Bytes::from_array([]),
    params,
  )
  match decoded {
    Err(InvalidDecodeParms(filter_name, reason)) => {
      assert_eq(filter_name, "CCITTFaxDecode")
      assert_eq(reason.contains("BlackIs1"), true)
    }
    _ => fail("expected malformed BlackIs1 to fail")
  }
}
