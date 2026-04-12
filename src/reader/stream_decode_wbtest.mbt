///|
fn make_structural_stream(
  data : Bytes,
  type_name : Bytes,
  filter : @objects.PdfObject?,
) -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(type_name),
  )
  dict[@objects.PdfName::new(b"Length")] = @objects.PdfObject::Integer(
    data.length().to_int64(),
  )
  match filter {
    Some(value) => dict[@objects.PdfName::new(b"Filter")] = value
    None => ()
  }
  @objects.PdfStream::{ dict, data }
}

///|
fn mark_structural_stream_encrypted(
  stream : @objects.PdfStream,
) -> @objects.PdfStream {
  stream.dict[@objects.PdfName::new(b"Encrypt")] = @objects.PdfObject::Null
  stream
}

///|
fn expect_decoded_structural_stream(
  stream : @objects.PdfStream,
  purpose : StructuralStreamPurpose,
  offset : Int64,
) -> Bytes raise {
  let result : Result[Bytes, PdfReaderError] = try? decode_structural_stream(
    stream,
    purpose,
    offset~,
  )
  match result {
    Ok(decoded) => decoded
    Err(_) => fail("expected decoded structural stream")
  }
}

///|
fn expect_unsupported_structural_stream(
  stream : @objects.PdfStream,
  purpose : StructuralStreamPurpose,
  offset : Int64,
) -> String raise {
  let result : Result[Bytes, PdfReaderError] = try? decode_structural_stream(
    stream,
    purpose,
    offset~,
  )
  match result {
    Err(UnsupportedFilter(actual_offset, reason)) => {
      assert_eq(actual_offset, offset)
      reason
    }
    _ => fail("expected unsupported filter rejection")
  }
}

///|
test "decode_structural_stream passes through unfiltered xref stream bytes unchanged" {
  let stream = make_structural_stream(b"0 1 2", b"XRef", None)
  let decoded = expect_decoded_structural_stream(stream, XrefStream, 17L)
  assert_eq(decoded, b"0 1 2")
}

///|
test "decode_structural_stream passes through unfiltered object stream bytes unchanged" {
  let stream = make_structural_stream(b"12 0 0 1", b"ObjStm", None)
  let decoded = expect_decoded_structural_stream(stream, ObjectStream, 31L)
  assert_eq(decoded, b"12 0 0 1")
}

///|
test "decode_structural_stream rejects crypt-filtered structural streams" {
  let stream = make_structural_stream(
    b"1 0 0 1",
    b"XRef",
    Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Crypt"))),
  )
  let reason = expect_unsupported_structural_stream(stream, XrefStream, 73L)
  assert_eq(reason.contains("Crypt"), true)
}

///|
test "decode_structural_stream rejects encrypted xref streams without filters" {
  let stream = mark_structural_stream_encrypted(
    make_structural_stream(b"0 1 2", b"XRef", None),
  )
  let reason = expect_unsupported_structural_stream(stream, XrefStream, 41L)
  assert_eq(reason.contains("Encrypt"), true)
}

///|
test "decode_structural_stream rejects xref array filters with crypt and unsupported names" {
  let crypt_stream = make_structural_stream(
    b"0 1 2",
    b"XRef",
    Some(
      @objects.PdfObject::Array([
        @objects.PdfObject::Name(@objects.PdfName::new(b"Crypt")),
        @objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode")),
      ]),
    ),
  )
  let crypt_reason = expect_unsupported_structural_stream(
    crypt_stream,
    XrefStream,
    52L,
  )
  assert_eq(crypt_reason.contains("Crypt"), true)

  let unsupported_stream = make_structural_stream(
    b"0 1 2",
    b"XRef",
    Some(
      @objects.PdfObject::Array([
        @objects.PdfObject::Name(@objects.PdfName::new(b"DCTDecode")),
        @objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode")),
      ]),
    ),
  )
  let unsupported_reason = expect_unsupported_structural_stream(
    unsupported_stream,
    XrefStream,
    53L,
  )
  assert_eq(unsupported_reason.contains("DCTDecode"), true)
}

///|
test "decode_structural_stream rejects unsupported structural stream filters before entry parsing" {
  let stream = make_structural_stream(
    b"not a decoded structural stream",
    b"ObjStm",
    Some(@objects.PdfObject::Name(@objects.PdfName::new(b"FlateDecode"))),
  )
  let reason = expect_unsupported_structural_stream(stream, ObjectStream, 99L)
  assert_eq(reason.contains("FlateDecode"), true)
}
