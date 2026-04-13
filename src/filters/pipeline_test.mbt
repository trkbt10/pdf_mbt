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
