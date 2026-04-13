///|
test "catalog resolver returns validated catalog from root" {
  let file = PdfFile::open(build_document_structure_single_page_fixture())
  let catalog = load_catalog(file)
  assert_eq(catalog.object_id == oid(1), true)
  assert_eq(
    catalog.pages_ref == oid(2),
    true,
  )
  assert_eq(
    catalog.dict.get(@objects.PdfName::new(b"Type")) ==
    Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
    true,
  )
}

///|
test "catalog resolver exposes raw optional entries" {
  let file = PdfFile::open(build_document_structure_names_fixture())
  let catalog = load_catalog(file)

  assert_eq(catalog.entry(@objects.PdfName::new(b"Names")) is Some(_), true)
  assert_eq(catalog.names_entry() == Some(@objects.PdfObject::Ref(oid(3))), true)

  let root_dict : @objects.PdfDictionary = Map::new()
  root_dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Catalog"),
  )
  root_dict[@objects.PdfName::new(b"Pages")] = @objects.PdfObject::Ref(oid(2))
  root_dict[@objects.PdfName::new(b"Metadata")] = @objects.PdfObject::Ref(oid(4))
  root_dict[@objects.PdfName::new(b"Lang")] = @objects.PdfObject::String(b"en")
  let catalog = PdfCatalog::{ object_id: oid(1), dict: root_dict, pages_ref: oid(2) }
  assert_eq(
    catalog.entry(@objects.PdfName::new(b"Metadata")) ==
    Some(@objects.PdfObject::Ref(oid(4))),
    true,
  )
  assert_eq(
    catalog.entry(@objects.PdfName::new(b"Lang")) ==
    Some(@objects.PdfObject::String(b"en")),
    true,
  )
  assert_eq(catalog.entry(@objects.PdfName::new(b"Outlines")) is None, true)
  assert_eq(catalog.entry(@objects.PdfName::new(b"PageLabels")) is None, true)
  assert_eq(catalog.entry(@objects.PdfName::new(b"StructTreeRoot")) is None, true)
  assert_eq(catalog.entry(@objects.PdfName::new(b"MarkInfo")) is None, true)
  assert_eq(catalog.entry(@objects.PdfName::new(b"Names")) is None, true)
  assert_eq(catalog.pages_ref == oid(2), true)
}

///|
test "catalog resolver rejects malformed catalog objects" {
  let missing_type_file = make_reader_file(
    b"1 0 obj\n<< /Pages 2 0 R >>\nendobj",
    Map::new(),
  )
  missing_type_file.xref_index[oid(1)] = ObjectLocation::Uncompressed(0L, 0)
  let missing_type_result : Result[PdfCatalog, PdfDocumentError] = try? load_catalog(
    missing_type_file,
  )
  match missing_type_result {
    Err(InvalidCatalog(object_id, reason)) => {
      assert_eq(object_id == oid(1), true)
      assert_eq(reason.contains("missing /Type"), true)
    }
    _ => fail("expected invalid catalog for missing type")
  }

  let wrong_type_file = make_reader_file(
    b"1 0 obj\n<< /Type /Page /Pages 2 0 R >>\nendobj",
    Map::new(),
  )
  wrong_type_file.xref_index[oid(1)] = ObjectLocation::Uncompressed(0L, 0)
  let wrong_type_result : Result[PdfCatalog, PdfDocumentError] = try? load_catalog(
    wrong_type_file,
  )
  match wrong_type_result {
    Err(InvalidCatalog(object_id, reason)) => {
      assert_eq(object_id == oid(1), true)
      assert_eq(reason.contains("/Catalog"), true)
    }
    _ => fail("expected invalid catalog for wrong type")
  }

  let missing_pages_file = make_reader_file(
    b"1 0 obj\n<< /Type /Catalog >>\nendobj",
    Map::new(),
  )
  missing_pages_file.xref_index[oid(1)] = ObjectLocation::Uncompressed(0L, 0)
  let missing_pages_result : Result[PdfCatalog, PdfDocumentError] = try? load_catalog(
    missing_pages_file,
  )
  match missing_pages_result {
    Err(InvalidCatalog(object_id, reason)) => {
      assert_eq(object_id == oid(1), true)
      assert_eq(reason.contains("/Pages"), true)
    }
    _ => fail("expected invalid catalog for missing pages")
  }

  let non_dictionary_file = make_reader_file(b"1 0 obj\n(hello)\nendobj", Map::new())
  non_dictionary_file.xref_index[oid(1)] = ObjectLocation::Uncompressed(0L, 0)
  let non_dictionary_result : Result[PdfCatalog, PdfDocumentError] = try? load_catalog(
    non_dictionary_file,
  )
  match non_dictionary_result {
    Err(InvalidCatalog(object_id, reason)) => {
      assert_eq(object_id == oid(1), true)
      assert_eq(reason.contains("dictionary"), true)
    }
    _ => fail("expected invalid catalog for non dictionary root")
  }
}

///|
test "catalog resolver wraps reader failures" {
  let xref_index : XrefIndex = Map::new()
  xref_index[oid(1)] = ObjectLocation::Uncompressed(0L, 0)
  let file = make_reader_file(b"garbage", xref_index)
  let result : Result[PdfCatalog, PdfDocumentError] = try? load_catalog(file)

  match result {
    Err(ReaderError(_)) => ()
    _ => fail("expected reader error wrapper")
  }
}
