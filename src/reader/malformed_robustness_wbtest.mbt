///|
fn expect_malformed_invalid_xref_section(
  input : Bytes,
  offset : Int64,
  reason_fragment : String,
) -> Unit raise {
  let source = ByteSource::new(input, 0L)
  let result : Result[XrefSection, PdfReaderError] = try? parse_xref_table_section(
    source, 0L,
  )
  match result {
    Err(InvalidXref(actual_offset, reason)) => {
      assert_eq(actual_offset, offset)
      assert_eq(reason.contains(reason_fragment), true)
    }
    _ => fail("expected invalid xref section")
  }
}

///|
fn expect_malformed_invalid_trailer(
  dict : @objects.PdfDictionary,
  version : PdfVersion,
  offset : Int64,
  reason_fragment : String,
) -> Unit raise {
  let result : Result[TrailerInfo, PdfReaderError] = try? parse_trailer_info(
    dict,
    version,
    offset~,
  )
  match result {
    Err(InvalidTrailer(actual_offset, reason)) => {
      assert_eq(actual_offset, offset)
      assert_eq(reason.contains(reason_fragment), true)
    }
    _ => fail("expected invalid trailer")
  }
}

fn expect_malformed_invalid_object_stream(
  stream : @objects.PdfStream,
  offset : Int64,
  reason_fragment : String,
) -> Unit raise {
  let result : Result[ObjectStreamTable, PdfReaderError] = try? parse_object_stream(
    stream,
    offset~,
  )
  match result {
    Err(InvalidObjectStream(actual_offset, reason)) => {
      assert_eq(actual_offset, offset)
      assert_eq(reason.contains(reason_fragment), true)
    }
    _ => fail("expected invalid object stream")
  }
}

///|
test "reader rejects malformed headers and missing tail markers through PdfFile::open" {
  let invalid_header : Result[PdfFile, PdfReaderError] = try? PdfFile::open(
    b"not a pdf",
  )
  match invalid_header {
    Err(InvalidHeader(offset, reason)) => {
      assert_eq(offset, 0L)
      assert_eq(reason.contains("%PDF-"), true)
    }
    _ => fail("expected invalid header rejection")
  }

  let missing_tail : Result[PdfFile, PdfReaderError] = try? PdfFile::open(
    b"%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n",
  )
  match missing_tail {
    Err(MissingTailMarker(reason)) => assert_eq(reason.contains("%%EOF"), true)
    _ => fail("expected missing tail marker rejection")
  }
}

///|
test "reader rejects malformed xref rows and invalid trailer typing" {
  expect_malformed_invalid_xref_section(
    b"xref\n0 1\n0000000000 65535 f\ntrailer\n<< /Size 1 /Root 1 0 R >>", 9L, "row endings",
  )

  let trailer_dict : @objects.PdfDictionary = Map::new()
  trailer_dict[@objects.PdfName::new(b"Size")] = @objects.PdfObject::String(
    b"eight",
  )
  trailer_dict[@objects.PdfName::new(b"Root")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 1,
    generation_number: 0,
  })
  expect_malformed_invalid_trailer(
    trailer_dict,
    PdfVersion::{ major: 2, minor: 0 },
    44L,
    "direct integer",
  )
}

///|
test "reader rejects unsupported structural stream filters and malformed object stream headers" {
  let xref_stream_dict : @objects.PdfDictionary = Map::new()
  xref_stream_dict[@objects.PdfName::new(b"Filter")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"FlateDecode"),
  )
  let xref_stream = @objects.PdfStream::{
    dict: xref_stream_dict,
    data: Bytes::from_array([
      b'\x70', b'\x01', b'\x01', b'\x03', b'\x00', b'\xfc', b'\xff', b'a', b'b',
      b'c', b'\x02', b'M', b'\x01', b'\'',
    ]),
  }
  let xref_result : Result[Bytes, PdfReaderError] = try? decode_structural_stream(
    xref_stream,
    XrefStream,
    offset=88L,
  )
  match xref_result {
    Err(DecodeStreamError(actual_offset, @filters.PdfFilterError::DecodeError(filter_name, reason))) => {
      assert_eq(actual_offset, 88L)
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("method"), true)
    }
    _ => fail("expected wrapped structural stream decode failure")
  }

  let obj_stream_dict : @objects.PdfDictionary = Map::new()
  obj_stream_dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"ObjStm"),
  )
  obj_stream_dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Integer(2L)
  obj_stream_dict[@objects.PdfName::new(b"First")] = @objects.PdfObject::Integer(
    7L,
  )
  obj_stream_dict[@objects.PdfName::new(b"Length")] = @objects.PdfObject::Integer(
    8L,
  )
  let obj_stream = @objects.PdfStream::{
    dict: obj_stream_dict,
    data: b"10 0 201",
  }
  expect_malformed_invalid_object_stream(obj_stream, 72L, "header")
}

///|
test "reader reports out-of-bounds object offsets and parser wrapping" {
  let oob_index : XrefIndex = Map::new()
  let object_id = @objects.ObjectId::{ object_number: 1, generation_number: 0 }
  oob_index[object_id] = ObjectLocation::Uncompressed(9999L, 0)
  let out_of_bounds_file = make_reader_file(b"%PDF-1.7\n", oob_index)

  let oob_result : Result[@objects.PdfObject, PdfReaderError] = try? out_of_bounds_file.load_object(
    object_id,
  )
  match oob_result {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 9999L)
      assert_eq(reason.contains("buffer"), true)
    }
    _ => fail("expected out-of-bounds object offset rejection")
  }

  let parse_index : XrefIndex = Map::new()
  parse_index[object_id] = ObjectLocation::Uncompressed(0L, 0)
  let parse_error_file = make_reader_file(
    b"1 0 obj << /Length 2 >> stream\nX", parse_index,
  )

  let parse_result : Result[@objects.PdfObject, PdfReaderError] = try? parse_error_file.load_object(
    object_id,
  )
  match parse_result {
    Err(ParseObjectError(offset, parse_error)) => {
      assert_eq(offset, 0L)
      match parse_error {
        @objects.PdfParseError::UnexpectedEof(_, context) =>
          assert_eq(context, "raw bytes")
        _ => fail("expected wrapped parser eof error")
      }
    }
    _ => fail("expected parser error wrapping")
  }
}
