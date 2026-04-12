///|
fn oid(object_number : Int) -> @objects.ObjectId {
  @objects.ObjectId::{ object_number, generation_number: 0 }
}

///|
test "PdfFile::open reads bundled Simple PDF 2.0 file" {
  let file = PdfFile::open(simple_pdf20_file)
  let trailer = file.trailer()
  let root_ref = oid(1)

  assert_eq(file.version() == PdfVersion::{ major: 2, minor: 0 }, true)
  assert_eq(file.root_ref() == root_ref, true)
  assert_eq(trailer.root == root_ref, true)
  assert_eq(trailer.size, 10)

  match file.load_object(root_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(@objects.PdfObject::Ref(oid(3))),
        true,
      )
    }
    _ => fail("expected Simple PDF 2.0 catalog dictionary")
  }

  for object_number in [1, 2, 3, 4, 5, 6, 7, 8, 9] {
    assert_eq(
      file.load_object(oid(object_number)) == @objects.PdfObject::Null,
      false,
    )
  }
}

///|
test "PdfFile::open follows bundled incremental updates to latest objects" {
  let file = PdfFile::open(incremental_pdf20_file)
  let trailer = file.trailer()
  let root_ref = oid(1)
  let deleted_ref = oid(5)
  let latest_stream_ref = oid(6)
  let font_descriptor_ref = oid(9)

  assert_eq(file.version() == PdfVersion::{ major: 1, minor: 7 }, true)
  assert_eq(file.root_ref() == root_ref, true)
  assert_eq(trailer.root == root_ref, true)
  assert_eq(trailer.size, 10)
  match trailer.prev {
    Some(prev) => assert_eq(prev > 0L, true)
    None =>
      fail("expected incremental trailer to link to a previous xref section")
  }

  for object_number in [1, 2, 3, 4, 5, 6, 7, 8, 9] {
    let object = file.load_object(oid(object_number))
    if object_number == 5 {
      assert_eq(object == @objects.PdfObject::Null, true)
    } else {
      assert_eq(object == @objects.PdfObject::Null, false)
    }
  }

  match file.load_object(root_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Version")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"2.0"))),
        true,
      )
    }
    _ => fail("expected incremental catalog dictionary")
  }

  match file.load_object(latest_stream_ref) {
    @objects.PdfObject::Stream(stream) =>
      match stream.data.find(b"PDF 2.0 Words Have Spacing") {
        Some(_) => ()
        None =>
          fail("expected latest stream text to include the updated phrase")
      }
    _ => fail("expected updated object 6 stream")
  }

  match file.load_object(font_descriptor_ref) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"FontDescriptor"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"MissingWidth")) ==
        Some(@objects.PdfObject::Integer(278L)),
        true,
      )
    }
    _ => fail("expected updated object 9 font descriptor")
  }

  assert_eq(file.load_object(deleted_ref) == @objects.PdfObject::Null, true)
}
