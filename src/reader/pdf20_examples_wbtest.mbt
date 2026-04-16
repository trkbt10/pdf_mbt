///|
fn oid(object_number : Int) -> @objects.ObjectId {
  @objects.ObjectId::{ object_number, generation_number: 0 }
}

///|
/// Validates the bundled PDF 2.0 example file through public APIs.
test "PdfFile::open reads bundled Simple PDF 2.0 file" {
  let file = PdfFile::open(simple_pdf20_file)
  let trailer = file.trailer()
  let root_ref = oid(1)

  assert_eq(file.version() == PdfVersion::{ major: 2, minor: 0 }, true)
  assert_eq(file.root_ref() == root_ref, true)
  assert_eq(trailer.root == Some(root_ref), true)
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
/// Validates the bundled PDF 2.0 example through document-structure APIs.
test "PdfDocument::open reads bundled Simple PDF 2.0 document structure" {
  let document = PdfDocument::open(simple_pdf20_file)
  let catalog = document.catalog()
  assert_eq(catalog.pages_ref == oid(3), true)
  assert_eq(document.page_count(), 1)

  let page = document.page(0)
  assert_eq(page.object_id() == oid(4), true)
  match page.media_box() {
    Some(rect) => assert_pdf20_rectangle(rect, 0.0, 0.0, 612.0, 396.0)
    None => fail("expected Simple PDF 2.0 media box")
  }

  match page.contents() {
    Some(@objects.PdfObject::Array(contents)) => {
      assert_eq(contents.length(), 2)
      assert_eq(contents[0] == @objects.PdfObject::Ref(oid(5)), true)
      assert_eq(contents[1] == @objects.PdfObject::Ref(oid(6)), true)
    }
    _ => fail("expected Simple PDF 2.0 content streams")
  }

  match page.resources() {
    Some(@objects.PdfObject::Dictionary(resources)) =>
      match resources.get(@objects.PdfName::new(b"Font")) {
        Some(@objects.PdfObject::Dictionary(fonts)) =>
          assert_eq(
            fonts.get(@objects.PdfName::new(b"F1")) ==
            Some(@objects.PdfObject::Ref(oid(7))),
            true,
          )
        _ => fail("expected Simple PDF 2.0 font resources")
      }
    _ => fail("expected Simple PDF 2.0 page resources")
  }
}

///|
/// Validates document-level page count and inherited resources on synthetic
/// multi-page structures through public document APIs.
test "PdfDocument validates multi-page count and inherited resources" {
  let nested_document = PdfDocument::open(
    build_document_structure_nested_page_tree_fixture(),
  )
  assert_eq(nested_document.page_count(), 2)
  assert_eq(nested_document.pages().length(), 2)
  assert_eq(nested_document.page(0).object_id() == oid(4), true)
  assert_eq(nested_document.page(1).object_id() == oid(5), true)

  let inherited_document = PdfDocument::open(
    build_document_structure_inherited_resources_fixture(),
  )
  assert_eq(inherited_document.page_count(), 1)
  let inherited_page = inherited_document.page(0)
  assert_eq(
    inherited_page.entry(@objects.PdfName::new(b"Resources")) is None,
    true,
  )
  match inherited_page.resources() {
    Some(@objects.PdfObject::Dictionary(resources)) =>
      assert_eq(
        resources.get(@objects.PdfName::new(b"Font")) ==
        Some(@objects.PdfObject::Ref(oid(4))),
        true,
      )
    _ => fail("expected inherited resources from ancestor Pages node")
  }
}

///|
/// Validates the bundled PDF 2.0 example created by incremental save, ensuring
/// incremental updates resolve to the latest objects.
test "PdfFile::open follows bundled incremental updates to latest objects" {
  let file = PdfFile::open(incremental_pdf20_file)
  let trailer = file.trailer()
  let root_ref = oid(1)
  let deleted_ref = oid(5)
  let latest_stream_ref = oid(6)
  let font_descriptor_ref = oid(9)

  assert_eq(file.version() == PdfVersion::{ major: 1, minor: 7 }, true)
  assert_eq(file.root_ref() == root_ref, true)
  assert_eq(trailer.root == Some(root_ref), true)
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

///|
fn assert_pdf20_rectangle(
  rect : PdfRectangle,
  left : Double,
  bottom : Double,
  right : Double,
  top : Double,
) -> Unit raise {
  assert_eq(rect.left, left)
  assert_eq(rect.bottom, bottom)
  assert_eq(rect.right, right)
  assert_eq(rect.top, top)
}
