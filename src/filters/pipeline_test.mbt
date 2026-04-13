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
test "decode_stream_bytes treats a null filter entry as decoded bytes" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Null
  let data = Bytes::from_array([b'\x10', b'\x20'])
  let decoded = @filters.decode_stream_bytes(dict, data)
  assert_eq(decoded, data)
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
