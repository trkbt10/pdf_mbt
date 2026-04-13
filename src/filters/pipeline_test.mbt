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
test "decode_stream_bytes returns raw bytes unchanged when filter is absent" {
  let dict : @objects.PdfDictionary = Map::new()
  let data = Bytes::from_array([b'\x01', b'\x02', b'\xfe', b'\xff'])
  let decoded = @filters.decode_stream_bytes(dict, data)
  assert_eq(decoded, data)
}

///|
test "decode_stream returns raw bytes unchanged when filter is absent" {
  let dict : @objects.PdfDictionary = Map::new()
  let data = Bytes::from_array([b'P', b'D', b'F'])
  let stream = @objects.PdfStream::{ dict, data }
  let decoded = @filters.decode_stream(stream)
  assert_eq(decoded, data)
}

///|
test "decode_stream_bytes decodes ASCII85 streams" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"ASCII85Decode"),
  )
  let data = Bytes::from_array([b'!', b'!', b'!', b'!', b'u', b'~', b'>'])
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) =>
      assert_eq(bytes, Bytes::from_array([b'\x00', b'\x00', b'\x00', b'T']))
    _ => fail("expected ASCII85Decode to be routed through the pipeline")
  }
}

///|
test "decode_stream_bytes decodes RunLength streams" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"RunLengthDecode"),
  )
  let data = Bytes::from_array([b'\x03', b'A', b'B', b'C', b'D', b'\x80'])
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'A', b'B', b'C', b'D']))
    _ => fail("expected RunLengthDecode to be routed through the pipeline")
  }
}

///|
test "decode_stream_bytes decodes LZW streams without predictors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"LZWDecode"),
  )
  let data = pack_lzw_codes([256, 65, 66, 67, 257])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'A', b'B', b'C']))
    _ => fail("expected LZWDecode to be routed through the pipeline")
  }
}

///|
test "decode_stream_bytes applies filters in array order" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"ASCIIHexDecode")),
    @objects.PdfObject::Name(@objects.PdfName::new(b"RunLengthDecode")),
  ])
  let data = Bytes::from_array([
    b'0', b'3', b'4', b'1', b'4', b'2', b'4', b'3', b'4', b'4', b'8', b'0', b'>',
  ])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'A', b'B', b'C', b'D']))
    _ => fail("expected chained filters to return the fully decoded bytes")
  }
}

///|
test "decode_stream_bytes validates the full filter pipeline before decoding" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"ASCIIHexDecode")),
    @objects.PdfObject::Null,
  ])
  let data = Bytes::from_array([
    b'0', b'3', b'4', b'1', b'4', b'2', b'4', b'3', b'4', b'4', b'8', b'0', b'>',
  ])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Err(InvalidFilterSpec(reason)) =>
      assert_eq(reason.contains("Filter array entries"), true)
    _ => fail("expected malformed later filters to fail before decoding begins")
  }
}

///|
test "decode_stream_bytes decodes LZW streams with TIFF predictors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"LZWDecode"),
  )
  let params : @objects.PdfDictionary = Map::new()
  params[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  params[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(4L)
  params[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(1L)
  params[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    8L,
  )
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Dictionary(
    params,
  )
  let data = pack_lzw_codes([256, 10, 20, 30, 40, 257])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) =>
      assert_eq(bytes, Bytes::from_array([b'\n', b'\x1e', b'<', b'd']))
    _ => fail("expected LZWDecode predictor reconstruction to be applied")
  }
}

///|
test "decode_stream_bytes reports LZWDecode predictor failures" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"LZWDecode"),
  )
  let params : @objects.PdfDictionary = Map::new()
  params[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(9L)
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Dictionary(
    params,
  )
  let data = pack_lzw_codes([256, 65, 257])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Err(InvalidDecodeParms(filter_name, reason)) => {
      assert_eq(filter_name, "LZWDecode")
      assert_eq(reason.contains("Predictor"), true)
    }
    _ => fail("expected LZWDecode predictor failure to be surfaced")
  }
}

///|
test "decode_stream_bytes decodes Flate streams without predictors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"FlateDecode"),
  )
  let data = Bytes::from_array([
    b'\x78', b'\xda', b'K', b'L', b'J', b'\x06', b'\x00', b'\x02', b'M', b'\x01',
    b'\x27',
  ])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'a', b'b', b'c']))
    _ => fail("expected FlateDecode to decode stored zlib bytes")
  }
}

///|
test "decode_stream_bytes decodes Flate streams with TIFF predictors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"FlateDecode"),
  )
  let params : @objects.PdfDictionary = Map::new()
  params[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  params[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(4L)
  params[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(1L)
  params[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    8L,
  )
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Dictionary(
    params,
  )
  let data = Bytes::from_array([
    b'\x78', b'\xda', b'\xe3', b'\x12', b'\x91', b'\xd3', b'`', b'\x04', b'\x02',
    b'\x00', b'\x02', b'j', b'\x00', b'i',
  ])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) =>
      assert_eq(
        bytes,
        Bytes::from_array([
          b'\n', b'\x1e', b'<', b'd', b'\x01', b'\x02', b'\x03', b'\x04',
        ]),
      )
    _ => fail("expected TIFF predictor reconstruction to be applied")
  }
}

///|
test "decode_stream_bytes decodes Flate streams with PNG predictors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"FlateDecode"),
  )
  let params : @objects.PdfDictionary = Map::new()
  params[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(15L)
  params[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(3L)
  params[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(1L)
  params[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    8L,
  )
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Dictionary(
    params,
  )
  let data = Bytes::from_array([
    b'\x78', b'\xda', b'c', b'\xe0', b'\xe2', b'\xe6', b'\x61', b'\x62', b'\x60',
    b'd', b'\x02', b'\x00', b'\x00', b'\xd8', b'\x00', b'\x27',
  ])

  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Ok(bytes) =>
      assert_eq(
        bytes,
        Bytes::from_array([b'\n', b'\x0b', b'\x0c', b'\n', b'\x0c', b'\x0e']),
      )
    _ => fail("expected PNG predictor reconstruction to be applied")
  }
}

///|
test "decode_stream_bytes reports FlateDecode on malformed zlib, DEFLATE, and checksum data" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"FlateDecode"),
  )

  let bad_zlib = Bytes::from_array([
    b'\x70', b'\x01', b'\x01', b'\x03', b'\x00', b'\xfc', b'\xff', b'a', b'b', b'c',
    b'\x02', b'M', b'\x01', b'\'',
  ])
  let bad_deflate = Bytes::from_array([
    b'\x78', b'\x01', b'\x03', b'\x02', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let bad_checksum = Bytes::from_array([
    b'\x78', b'\xda', b'K', b'L', b'J', b'\x06', b'\x00', b'\x02', b'M', b'\x01',
    b'\x28',
  ])

  let zlib_result : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, bad_zlib,
  )
  let deflate_result : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, bad_deflate,
  )
  let checksum_result : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, bad_checksum,
  )

  match zlib_result {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("method"), true)
    }
    _ => fail("expected invalid zlib data to be rejected")
  }
  match deflate_result {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("distance"), true)
    }
    _ => fail("expected malformed DEFLATE data to be rejected")
  }
  match checksum_result {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("checksum"), true)
    }
    _ => fail("expected checksum failures to be rejected")
  }
}

///|
test "decode_stream_bytes rejects a null filter entry" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Null
  let data = Bytes::from_array([b'\x10', b'\x20'])
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Err(InvalidFilterSpec(reason)) => assert_eq(reason.contains("Filter"), true)
    _ => fail("expected null filter entry to be rejected")
  }
}

///|
test "decode_stream_bytes rejects mismatched decode parms arrays before filters" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"Crypt")),
    @objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode")),
  ])
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Array([
    @objects.PdfObject::Null,
  ])
  let data = Bytes::from_array([b'X', b'Y'])
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Err(InvalidFilterSpec(reason)) =>
      assert_eq(reason.contains("DecodeParms"), true)
    _ => fail("expected mismatched decode parms to be rejected")
  }
}

///|
test "decode_stream_bytes rejects indirect decode parms before filters" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Crypt"),
  )
  dict[@objects.PdfName::new(b"DecodeParms")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 9,
    generation_number: 0,
  })
  let data = Bytes::from_array([b'A', b'B'])
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream_bytes(
    dict, data,
  )
  match decoded {
    Err(InvalidFilterSpec(reason)) =>
      assert_eq(reason.contains("DecodeParms"), true)
    _ => fail("expected indirect decode parms to be rejected")
  }
}

///|
test "typed filter errors expose category name and reason fields" {
  let invalid_spec = @filters.PdfFilterError::InvalidFilterSpec(
    "bad filter shape",
  )
  let invalid_params = @filters.PdfFilterError::InvalidDecodeParms(
    "FlateDecode", "Predictor must be positive",
  )
  let unsupported = @filters.PdfFilterError::UnsupportedFilter("Crypt")
  let decode_error = @filters.PdfFilterError::DecodeError(
    "ASCIIHexDecode", "invalid digit",
  )

  match invalid_spec {
    InvalidFilterSpec(reason) => assert_eq(reason, "bad filter shape")
    _ => fail("expected InvalidFilterSpec")
  }
  match invalid_params {
    InvalidDecodeParms(filter_name, reason) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason, "Predictor must be positive")
    }
    _ => fail("expected InvalidDecodeParms")
  }
  match unsupported {
    UnsupportedFilter(filter_name) => assert_eq(filter_name, "Crypt")
    _ => fail("expected UnsupportedFilter")
  }
  match decode_error {
    DecodeError(filter_name, reason) => {
      assert_eq(filter_name, "ASCIIHexDecode")
      assert_eq(reason, "invalid digit")
    }
    _ => fail("expected DecodeError")
  }
}
