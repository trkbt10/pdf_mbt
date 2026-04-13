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
