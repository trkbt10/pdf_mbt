///|
fn make_reader_file(bytes : Bytes, xref_index : XrefIndex) -> PdfFile {
  PdfFile::{
    bytes,
    header: PdfHeader::{
      version: PdfVersion::{ major: 1, minor: 7 },
      base_offset: 0L,
      has_binary_indicator: false,
    },
    trailer: TrailerInfo::{
      size: 32,
      root: @objects.ObjectId::{ object_number: 1, generation_number: 0 },
      prev: None,
      encrypt: None,
      info: None,
      id: None,
      xref_stm: None,
      raw_dict: Map::new(),
    },
    sections: [],
    xref_index,
    cache: Map::new(),
    object_stream_tables: Map::new(),
  }
}

///|
fn make_uncompressed_object_file() -> PdfFile {
  let xref_index : XrefIndex = Map::new()
  xref_index[@objects.ObjectId::{ object_number: 1, generation_number: 0 }] = ObjectLocation::Uncompressed(
    0L, 0,
  )
  make_reader_file(b"1 0 obj\n(Brillig)\nendobj", xref_index)
}

///|
fn make_object_stream_file() -> PdfFile {
  let xref_index : XrefIndex = Map::new()
  xref_index[@objects.ObjectId::{ object_number: 1, generation_number: 0 }] = ObjectLocation::Uncompressed(
    0L, 0,
  )
  xref_index[@objects.ObjectId::{ object_number: 10, generation_number: 0 }] = ObjectLocation::Compressed(
    1, 0,
  )
  xref_index[@objects.ObjectId::{ object_number: 20, generation_number: 0 }] = ObjectLocation::Compressed(
    1, 1,
  )
  make_reader_file(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 10 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    xref_index,
  )
}

///|
test "load_object returns null for missing and generation-mismatched references" {
  let file = make_uncompressed_object_file()
  assert_eq(
    file.load_object(@objects.ObjectId::{
      object_number: 2,
      generation_number: 0,
    }) ==
    @objects.PdfObject::Null,
    true,
  )
  assert_eq(
    file.load_object(@objects.ObjectId::{
      object_number: 1,
      generation_number: 1,
    }) ==
    @objects.PdfObject::Null,
    true,
  )
}

///|
test "load_object parses and caches uncompressed objects" {
  let file = make_uncompressed_object_file()
  let object_id = @objects.ObjectId::{ object_number: 1, generation_number: 0 }

  let first = file.load_object(object_id)
  let second = file.load_object(object_id)

  assert_eq(first == @objects.PdfObject::String(b"Brillig"), true)
  assert_eq(second == first, true)
  assert_eq(file.cache.length(), 1)
  assert_eq(file.cache.get(object_id) == Some(first), true)
}

///|
test "load_object rejects parsed indirect object id mismatches" {
  let xref_index : XrefIndex = Map::new()
  let requested_id = @objects.ObjectId::{
    object_number: 2,
    generation_number: 0,
  }
  xref_index[requested_id] = ObjectLocation::Uncompressed(0L, 0)
  let file = make_reader_file(b"1 0 obj\n(Brillig)\nendobj", xref_index)

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    requested_id,
  )
  match result {
    Err(InvalidObjectLocation(actual_id, reason)) => {
      assert_eq(actual_id == requested_id, true)
      assert_eq(reason.contains("mismatch"), true)
    }
    _ => fail("expected parsed object id mismatch")
  }
}

///|
test "load_object resolves compressed objects and caches object stream tables" {
  let file = make_object_stream_file()
  let first_id = @objects.ObjectId::{ object_number: 10, generation_number: 0 }
  let second_id = @objects.ObjectId::{ object_number: 20, generation_number: 0 }
  let object_stream_id = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }

  let first = file.load_object(first_id)
  match first {
    @objects.PdfObject::Integer(value) => assert_eq(value, 1L)
    _ => fail("expected first compressed object")
  }
  assert_eq(file.object_stream_tables.length(), 1)
  assert_eq(file.cache.get(object_stream_id) is Some(_), true)

  let second = file.load_object(second_id)
  match second {
    @objects.PdfObject::Dictionary(dict) =>
      assert_eq(
        dict.get(@objects.PdfName::new(b"A")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    _ => fail("expected second compressed object")
  }

  assert_eq(file.object_stream_tables.length(), 1)
  assert_eq(file.cache.get(first_id) == Some(first), true)
  assert_eq(file.cache.get(second_id) == Some(second), true)
  assert_eq(file.cache.length(), 3)
}

///|
test "load_object rejects cached compressed member identity mismatches" {
  let file = make_object_stream_file()
  let first_id = @objects.ObjectId::{ object_number: 10, generation_number: 0 }
  let conflicting_id = @objects.ObjectId::{
    object_number: 99,
    generation_number: 0,
  }

  let _ = file.load_object(first_id)
  file.xref_index[conflicting_id] = ObjectLocation::Compressed(1, 0)

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    conflicting_id,
  )
  match result {
    Err(InvalidObjectLocation(actual_id, reason)) => {
      assert_eq(actual_id == conflicting_id, true)
      assert_eq(reason.contains("mismatch"), true)
    }
    _ => fail("expected cached compressed member identity mismatch")
  }
}

///|
test "load_object rejects non-zero-generation compressed lookups" {
  let file = make_object_stream_file()
  let valid_id = @objects.ObjectId::{ object_number: 10, generation_number: 0 }
  let invalid_id = @objects.ObjectId::{
    object_number: 10,
    generation_number: 1,
  }

  let _ = file.load_object(valid_id)
  file.xref_index[invalid_id] = ObjectLocation::Compressed(1, 0)

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    invalid_id,
  )
  match result {
    Err(InvalidObjectStream(_, reason)) =>
      assert_eq(reason.contains("generation"), true)
    _ => fail("expected non-zero-generation compressed lookup rejection")
  }
}

///|
test "load_object propagates invalid compressed indexes" {
  let xref_index : XrefIndex = Map::new()
  let object_stream_id = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let invalid_member_id = @objects.ObjectId::{
    object_number: 10,
    generation_number: 0,
  }
  xref_index[object_stream_id] = ObjectLocation::Uncompressed(0L, 0)
  xref_index[invalid_member_id] = ObjectLocation::Compressed(1, 2)
  let file = make_reader_file(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 10 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    xref_index,
  )

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    invalid_member_id,
  )
  match result {
    Err(InvalidObjectStream(_, reason)) =>
      assert_eq(reason.contains("index"), true)
    _ => fail("expected invalid compressed index")
  }
  assert_eq(file.object_stream_tables.length(), 1)
}

///|
test "load_object rejects negative compressed indexes" {
  let xref_index : XrefIndex = Map::new()
  let object_stream_id = @objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  }
  let invalid_member_id = @objects.ObjectId::{
    object_number: 10,
    generation_number: 0,
  }
  xref_index[object_stream_id] = ObjectLocation::Uncompressed(0L, 0)
  xref_index[invalid_member_id] = ObjectLocation::Compressed(1, -1)
  let file = make_reader_file(
    b"1 0 obj\r\n" +
    b"<< /Type /ObjStm /N 2 /First 10 /Length 22 >>\r\n" +
    b"stream\r\n" +
    b"10 0 20 2 1 << /A 1 >>" +
    b"\r\nendstream endobj",
    xref_index,
  )

  let result : Result[@objects.PdfObject, PdfReaderError] = try? file.load_object(
    invalid_member_id,
  )
  match result {
    Err(InvalidObjectStream(_, reason)) =>
      assert_eq(reason.contains("index"), true)
    _ => fail("expected negative compressed index rejection")
  }
  assert_eq(file.object_stream_tables.length(), 1)
}
