///|
test "file specification accessors dispatch raw operands and embedded name tree" {
  let document = PdfDocument::open(build_file_spec_embedded_fixture())
  let entries = document.embedded_files()
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].name, b"attach-a")
  assert_eq(entries[1].name, b"attach-b")
  match entries[0].file_specification {
    Full(full) => {
      assert_eq(full.source_object_id == Some(oid(6)), true)
      assert_eq(full.selected_file_name.unwrap().raw, b"selected.bin")
      assert_eq(full.description, Some(b"desc"))
      assert_eq(
        full.associated_relationship == PdfAssociatedFileRelationship::Data,
        true,
      )
    }
    _ => fail("expected full embedded file entry")
  }
  match entries[1].file_specification {
    Simple(simple) => {
      assert_eq(simple.source_object_id == Some(oid(10)), true)
      assert_eq(simple.path.components[0], b"simple")
      assert_eq(simple.path.components[1], b"path.bin")
    }
    _ => fail("expected simple embedded file entry")
  }

  let raw_invalid : Result[PdfFileSpecification, PdfDocumentError] = try? document.parse_file_spec(
    @objects.PdfObject::Integer(1L),
  )
  match raw_invalid {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("string or dictionary"), true)
    _ => fail("expected invalid raw file specification rejection")
  }
}

///|
test "file specification parsing remains opt-in for adjacent raw action fields" {
  let document = file_spec_test_doc()
  let action_dict = action_test_dict(b"GoToR")
  action_dict[action_key(b"F")] = @objects.PdfObject::String(b"remote.pdf")
  action_dict[action_key(b"D")] = @objects.PdfObject::String(b"chapter")
  match
    document.parse_action(@objects.PdfObject::Dictionary(action_dict)).kind {
    PdfActionKind::GoToR(action) => {
      assert_eq(
        action.file_specification == @objects.PdfObject::String(b"remote.pdf"),
        true,
      )
      match document.parse_file_spec(action.file_specification) {
        Simple(simple) => assert_eq(simple.path.components[0], b"remote.pdf")
        _ => fail("expected opt-in simple file specification")
      }
    }
    _ => fail("expected GoToR action")
  }
}

///|
test "file specification dictionaries reject direct embedded mappings" {
  let document = file_spec_test_doc()
  let dict = file_spec_test_dict()
  dict[file_spec_test_name(b"Type")] = @objects.PdfObject::Name(
    file_spec_test_name(b"Filespec"),
  )
  dict[file_spec_test_name(b"F")] = @objects.PdfObject::String(b"file.bin")
  dict[file_spec_test_name(b"EF")] = @objects.PdfObject::Dictionary(Map::new())
  let result : Result[PdfFileSpecification, PdfDocumentError] = try? document.parse_file_spec(
    @objects.PdfObject::Dictionary(dict),
  )
  match result {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("indirect"), true)
    _ => fail("expected direct EF file specification rejection")
  }
}
