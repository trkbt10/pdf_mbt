///|
fn file_spec_test_doc() -> PdfDocument raise PdfDocumentError {
  PdfDocument::open(build_document_structure_single_page_fixture())
}

///|
fn file_spec_test_dict() -> @objects.PdfDictionary {
  Map::new()
}

///|
fn file_spec_test_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
test "file specification dictionaries preserve names and UF precedence" {
  let document = file_spec_test_doc()
  let dict = file_spec_test_dict()
  dict[file_spec_test_name(b"Type")] = @objects.PdfObject::Name(
    file_spec_test_name(b"Filespec"),
  )
  dict[file_spec_test_name(b"F")] = @objects.PdfObject::String(b"fallback.txt")
  dict[file_spec_test_name(b"UF")] = @objects.PdfObject::String(b"unicode.txt")
  dict[file_spec_test_name(b"DOS")] = @objects.PdfObject::String(b"DOS.TXT")
  dict[file_spec_test_name(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"id-a"),
    @objects.PdfObject::String(b"id-b"),
  ])
  dict[file_spec_test_name(b"V")] = @objects.PdfObject::Boolean(true)
  dict[file_spec_test_name(b"AFRelationship")] = @objects.PdfObject::Name(
    file_spec_test_name(b"Data"),
  )

  match document.parse_file_spec(@objects.PdfObject::Dictionary(dict)) {
    Full(full) => {
      assert_eq(full.f.unwrap().raw, b"fallback.txt")
      assert_eq(full.uf.unwrap().raw, b"unicode.txt")
      assert_eq(full.selected_file_name.unwrap().raw, b"unicode.txt")
      assert_eq(full.dos.unwrap().raw, b"DOS.TXT")
      assert_eq(full.file_identifier.unwrap().first, b"id-a")
      assert_eq(full.is_volatile, true)
      assert_eq(
        full.associated_relationship == PdfAssociatedFileRelationship::Data,
        true,
      )
      assert_eq(full.embedded_files.length(), 0)
    }
    _ => fail("expected full file specification")
  }
}

///|
test "file specification dictionaries preserve URL filesystem names" {
  let document = file_spec_test_doc()
  let dict = file_spec_test_dict()
  dict[file_spec_test_name(b"FS")] = @objects.PdfObject::Name(
    file_spec_test_name(b"URL"),
  )
  dict[file_spec_test_name(b"F")] = @objects.PdfObject::String(
    b"ftp://www.beatles.com/Movies/AbbeyRoad.mov",
  )
  match document.parse_file_spec(@objects.PdfObject::Dictionary(dict)) {
    Full(full) => {
      assert_eq(full.file_system == Some(PdfFileSpecFileSystem::URL), true)
      assert_eq(full.f.unwrap().path is None, true)
      assert_eq(
        full.selected_file_name.unwrap().raw,
        b"ftp://www.beatles.com/Movies/AbbeyRoad.mov",
      )
    }
    _ => fail("expected URL file specification")
  }

  let extension = file_spec_test_dict()
  extension[file_spec_test_name(b"FS")] = @objects.PdfObject::Name(
    file_spec_test_name(b"VendorFS"),
  )
  extension[file_spec_test_name(b"F")] = @objects.PdfObject::String(b"file.bin")
  match document.parse_file_spec(@objects.PdfObject::Dictionary(extension)) {
    Full(full) =>
      assert_eq(
        full.file_system ==
        Some(PdfFileSpecFileSystem::Other(file_spec_test_name(b"VendorFS"))),
        true,
      )
    _ => fail("expected extension filesystem name")
  }
}

///|
test "file specification dictionaries reject malformed filename metadata" {
  let document = file_spec_test_doc()
  let missing = file_spec_test_dict()
  let missing_result : Result[PdfFileSpecification, PdfDocumentError] = try? document.parse_file_spec(
    @objects.PdfObject::Dictionary(missing),
  )
  match missing_result {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("file name"), true)
    _ => fail("expected missing filename rejection")
  }

  let bad_id = file_spec_test_dict()
  bad_id[file_spec_test_name(b"F")] = @objects.PdfObject::String(b"file.bin")
  bad_id[file_spec_test_name(b"ID")] = @objects.PdfObject::Array([
    @objects.PdfObject::String(b"only-one"),
  ])
  let bad_id_result : Result[PdfFileSpecification, PdfDocumentError] = try? document.parse_file_spec(
    @objects.PdfObject::Dictionary(bad_id),
  )
  match bad_id_result {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("two strings"), true)
    _ => fail("expected malformed ID rejection")
  }
}
