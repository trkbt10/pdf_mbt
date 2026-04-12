///|
fn make_full_trailer_dict() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  dict[@objects.PdfName::new(b"Root")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  })
  dict[@objects.PdfName::new(b"Prev")] = @objects.PdfObject::Integer(1024L)
  dict[@objects.PdfName::new(b"Encrypt")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 9,
    generation_number: 0,
  })
  dict[@objects.PdfName::new(b"Info")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 10,
    generation_number: 0,
  })
  dict[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  dict[@objects.PdfName::new(b"XRefStm")] = @objects.PdfObject::Integer(4096L)
  dict[@objects.PdfName::new(b"Custom")] = @objects.PdfObject::Boolean(true)
  dict
}

///|
fn expect_invalid_trailer(
  input : @objects.PdfDictionary,
  version : PdfVersion,
  offset : Int64,
  reason : String,
) -> Unit raise {
  let result : Result[TrailerInfo, PdfReaderError] = try? parse_trailer_info(
    input,
    version,
    offset~,
  )
  match result {
    Err(InvalidTrailer(actual_offset, actual_reason)) => {
      assert_eq(actual_offset, offset)
      assert_eq(actual_reason, reason)
    }
    _ => fail("expected invalid trailer error")
  }
}

///|
test "parse_trailer_info validates required and optional trailer entries" {
  let dict = make_full_trailer_dict()
  let offset = 77L
  let trailer = parse_trailer_info(
    dict,
    PdfVersion::{ major: 2, minor: 0 },
    offset~,
  )

  assert_eq(trailer.size, 8)
  assert_eq(
    trailer.root ==
    @objects.ObjectId::{ object_number: 1, generation_number: 0 },
    true,
  )
  match trailer.prev {
    Some(prev) => assert_eq(prev, 1024L)
    None => fail("expected prev entry")
  }
  match trailer.encrypt {
    Some(encrypt) =>
      assert_eq(
        encrypt == @objects.ObjectId::{ object_number: 9, generation_number: 0 },
        true,
      )
    None => fail("expected encrypt entry")
  }
  match trailer.info {
    Some(info) =>
      assert_eq(
        info == @objects.ObjectId::{ object_number: 10, generation_number: 0 },
        true,
      )
    None => fail("expected info entry")
  }
  match trailer.id {
    Some(actual_id) =>
      assert_eq(
        actual_id == PdfFileId::{ first: b"doc-a-0001", second: b"doc-a-0002" },
        true,
      )
    None => fail("expected file identifier")
  }
  match trailer.xref_stm {
    Some(xref_stm) => assert_eq(xref_stm, 4096L)
    None => fail("expected xref stm entry")
  }
  assert_eq(trailer.raw_dict == dict, true)
  assert_eq(
    trailer.raw_dict[@objects.PdfName::new(b"Custom")] ==
    @objects.PdfObject::Boolean(true),
    true,
  )
}

///|
test "parse_trailer_info requires pdf 2.0 file identifiers" {
  let dict : @objects.PdfDictionary = Map::new()
  let offset = 88L
  dict[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  dict[@objects.PdfName::new(b"Root")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  })

  expect_invalid_trailer(
    dict,
    PdfVersion::{ major: 2, minor: 0 },
    offset,
    "missing ID entry for PDF 2.0 trailer",
  )

  let offset = 89L
  let legacy_trailer = parse_trailer_info(
    dict,
    PdfVersion::{ major: 1, minor: 7 },
    offset~,
  )
  match legacy_trailer.id {
    None => ()
    Some(_) => fail("expected missing file identifier")
  }
}

///|
test "parse_trailer_info rejects malformed trailer field types" {
  let root = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  })

  let bad_size : @objects.PdfDictionary = Map::new()
  bad_size[@objects.PdfName::new(b"Size")] = @objects.PdfObject::String(b"8")
  bad_size[@objects.PdfName::new(b"Root")] = root
  bad_size[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  expect_invalid_trailer(
    bad_size,
    PdfVersion::{ major: 2, minor: 0 },
    91L,
    "Size entry must be a direct integer",
  )

  let bad_root : @objects.PdfDictionary = Map::new()
  bad_root[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  bad_root[@objects.PdfName::new(b"Root")] = @objects.PdfObject::Integer(1L)
  bad_root[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  expect_invalid_trailer(
    bad_root,
    PdfVersion::{ major: 2, minor: 0 },
    92L,
    "Root entry must be an indirect reference",
  )

  let bad_prev : @objects.PdfDictionary = Map::new()
  bad_prev[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  bad_prev[@objects.PdfName::new(b"Root")] = root
  bad_prev[@objects.PdfName::new(b"Prev")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 2,
    generation_number: 0,
  })
  bad_prev[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  expect_invalid_trailer(
    bad_prev,
    PdfVersion::{ major: 2, minor: 0 },
    93L,
    "Prev entry must be a direct integer",
  )

  let bad_encrypt : @objects.PdfDictionary = Map::new()
  bad_encrypt[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  bad_encrypt[@objects.PdfName::new(b"Root")] = root
  bad_encrypt[@objects.PdfName::new(b"Encrypt")] = @objects.PdfObject::Integer(
    9L,
  )
  bad_encrypt[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  expect_invalid_trailer(
    bad_encrypt,
    PdfVersion::{ major: 2, minor: 0 },
    94L,
    "Encrypt entry must be an indirect reference",
  )

  let bad_info : @objects.PdfDictionary = Map::new()
  bad_info[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  bad_info[@objects.PdfName::new(b"Root")] = root
  bad_info[@objects.PdfName::new(b"Info")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Info"),
  )
  bad_info[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  expect_invalid_trailer(
    bad_info,
    PdfVersion::{ major: 2, minor: 0 },
    95L,
    "Info entry must be an indirect reference",
  )

  let bad_xref_stm : @objects.PdfDictionary = Map::new()
  bad_xref_stm[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  bad_xref_stm[@objects.PdfName::new(b"Root")] = root
  bad_xref_stm[@objects.PdfName::new(b"XRefStm")] = @objects.PdfObject::String(
    b"4096",
  )
  bad_xref_stm[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  expect_invalid_trailer(
    bad_xref_stm,
    PdfVersion::{ major: 2, minor: 0 },
    96L,
    "XRefStm entry must be a direct integer",
  )

  let bad_id : @objects.PdfDictionary = Map::new()
  bad_id[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  bad_id[@objects.PdfName::new(b"Root")] = root
  bad_id[@objects.PdfName::new(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::Integer(2L),
  ])
  expect_invalid_trailer(
    bad_id,
    PdfVersion::{ major: 2, minor: 0 },
    97L,
    "ID entry must be an array of two byte strings",
  )
}

///|
test "parse_trailer_info rejects missing required trailer entries" {
  let root = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  })
  let id = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])

  let missing_size : @objects.PdfDictionary = Map::new()
  missing_size[@objects.PdfName::new(b"Root")] = root
  missing_size[@objects.PdfName::new(b"ID")] = id
  expect_invalid_trailer(
    missing_size,
    PdfVersion::{ major: 2, minor: 0 },
    98L,
    "missing Size entry",
  )

  let missing_root : @objects.PdfDictionary = Map::new()
  missing_root[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(8L)
  missing_root[@objects.PdfName::new(b"ID")] = id
  expect_invalid_trailer(
    missing_root,
    PdfVersion::{ major: 2, minor: 0 },
    99L,
    "missing Root entry",
  )
}

///|
test "parse_trailer_info rejects oversized size entries" {
  let root = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  })
  let id = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"doc-a-0001"),
    @objects.PdfObject::String(b"doc-a-0002"),
  ])
  let oversized_size : @objects.PdfDictionary = Map::new()
  oversized_size[@objects.PdfName::new(b"Size")] = @objects.PdfObject::Integer(
    2147483648L,
  )
  oversized_size[@objects.PdfName::new(b"Root")] = root
  oversized_size[@objects.PdfName::new(b"ID")] = id

  expect_invalid_trailer(
    oversized_size,
    PdfVersion::{ major: 2, minor: 0 },
    100L,
    "Size entry is too large for TrailerInfo.size",
  )
}
