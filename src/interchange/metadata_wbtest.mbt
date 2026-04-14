///|
test "metadata stream validates names and preserves decoded XML bytes" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"Metadata"))
  dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"XML"))
  let stream = @objects.PdfStream::{ dict, data: b"<xmp/>" }

  let metadata = validate_metadata_stream_value(stream)
  assert_eq(metadata.xml, b"<xmp/>")
  assert_eq(metadata.raw_stream == stream, true)
}

///|
test "metadata stream rejects wrong subtype and wraps filter errors" {
  let wrong : @objects.PdfDictionary = Map::new()
  wrong[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"Metadata"))
  wrong[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"Text"))
  let wrong_result : Result[PdfMetadataStream, PdfInterchangeError] = try? validate_metadata_stream_value(@objects.PdfStream::{
      dict: wrong,
      data: b"",
    },
  )
  match wrong_result {
    Err(InvalidMetadata(_, reason)) =>
      assert_eq(reason.contains("Subtype"), true)
    _ => fail("expected invalid metadata subtype")
  }

  let filtered : @objects.PdfDictionary = Map::new()
  filtered[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"Metadata"))
  filtered[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"XML"))
  filtered[pdf_name(b"Filter")] = @objects.PdfObject::Name(pdf_name(b"Unknown"))
  let filter_result : Result[PdfMetadataStream, PdfInterchangeError] = try? validate_metadata_stream_value(@objects.PdfStream::{
      dict: filtered,
      data: b"",
    },
  )
  match filter_result {
    Err(FilterError(_)) => ()
    _ => fail("expected wrapped filter error")
  }
}

///|
test "object metadata helper returns absence or validates present stream" {
  let owner : @objects.PdfDictionary = Map::new()
  assert_eq(
    validate_object_metadata(@objects.PdfObject::Dictionary(owner)) is None,
    true,
  )

  let metadata_dict : @objects.PdfDictionary = Map::new()
  metadata_dict[pdf_name(b"Type")] = @objects.PdfObject::Name(
    pdf_name(b"Metadata"),
  )
  metadata_dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(
    pdf_name(b"XML"),
  )
  owner[pdf_name(b"Metadata")] = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: metadata_dict,
    data: b"<m/>",
  })
  match validate_object_metadata(@objects.PdfObject::Dictionary(owner)) {
    Some(metadata) => assert_eq(metadata.xml, b"<m/>")
    None => fail("expected object metadata")
  }
}
