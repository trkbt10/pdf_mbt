///|
fn build_document_structure_fixture_prefix() -> (Bytes, Int64) {
  let prefix = b"garbage\n"
  let header = b"%PDF-1.7\r\n"
  (prefix + header, prefix.length().to_int64())
}

///|
test "document structure fixtures open through the reader" {
  let single = PdfFile::open(build_document_structure_single_page_fixture())
  assert_eq(single.root_ref() == oid(1), true)

  let nested = PdfFile::open(
    build_document_structure_nested_page_tree_fixture(),
  )
  assert_eq(nested.root_ref() == oid(1), true)

  let inherited = PdfFile::open(
    build_document_structure_inherited_resources_fixture(),
  )
  assert_eq(inherited.root_ref() == oid(1), true)

  let names = PdfFile::open(build_document_structure_names_fixture())
  assert_eq(names.root_ref() == oid(1), true)
}

///|
test "document structure fixtures expose raw catalog and page tree shapes" {
  let single = PdfFile::open(build_document_structure_single_page_fixture())
  match single.load_object(oid(1)) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(@objects.PdfObject::Ref(oid(2))),
        true,
      )
    }
    _ => fail("expected catalog dictionary")
  }

  match single.load_object(oid(2)) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Pages"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Count")) ==
        Some(@objects.PdfObject::Integer(1L)),
        true,
      )
    }
    _ => fail("expected pages dictionary")
  }

  let nested = PdfFile::open(
    build_document_structure_nested_page_tree_fixture(),
  )
  match nested.load_object(oid(2)) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Kids")) ==
        Some(
          @objects.PdfObject::Array([
            @objects.PdfObject::Ref(oid(3)),
            @objects.PdfObject::Ref(oid(5)),
          ]),
        ),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Count")) ==
        Some(@objects.PdfObject::Integer(2L)),
        true,
      )
    }
    _ => fail("expected nested pages dictionary")
  }

  let inherited = PdfFile::open(
    build_document_structure_inherited_resources_fixture(),
  )
  match inherited.load_object(oid(2)) {
    @objects.PdfObject::Dictionary(dict) =>
      match dict.get(@objects.PdfName::new(b"Resources")) {
        Some(@objects.PdfObject::Dictionary(resources)) =>
          match resources.get(@objects.PdfName::new(b"Font")) {
            Some(@objects.PdfObject::Ref(font_ref)) =>
              assert_eq(font_ref == oid(4), true)
            _ => fail("expected inherited font reference")
          }
        _ => fail("expected inherited resources dictionary")
      }
    _ => fail("expected inherited resources pages dictionary")
  }

  let names = PdfFile::open(build_document_structure_names_fixture())
  match names.load_object(oid(3)) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Dests")) ==
        Some(@objects.PdfObject::Ref(oid(5))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"AP")) ==
        Some(@objects.PdfObject::Ref(oid(6))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"EmbeddedFiles")) ==
        Some(@objects.PdfObject::Ref(oid(10))),
        true,
      )
    }
    _ => fail("expected names dictionary")
  }

  match names.load_object(oid(5)) {
    @objects.PdfObject::Dictionary(dict) =>
      match dict.get(@objects.PdfName::new(b"Names")) {
        Some(@objects.PdfObject::Array(values)) => {
          assert_eq(values.length(), 4)
          assert_eq(values[0] == @objects.PdfObject::String(b"chapter-1"), true)
          assert_eq(values[1] == @objects.PdfObject::Ref(oid(12)), true)
        }
        _ => fail("expected leaf name array")
      }
    _ => fail("expected dests tree leaf")
  }

  match names.load_object(oid(6)) {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(dict.get(@objects.PdfName::new(b"Kids")) is Some(_), true)
      assert_eq(dict.get(@objects.PdfName::new(b"Limits")) is Some(_), true)
    }
    _ => fail("expected intermediate name tree node")
  }
}

///|
fn build_document_structure_single_page_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(b"<< /Length 5 >>", b"BT\nET")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(content_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_document_structure_nested_page_tree_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, root_pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>",
  )
  let (bytes, child_pages_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 /Parent 2 0 R >>",
  )
  let (bytes, first_page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 3 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, second_page_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 6\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(root_pages_offset, 0, b'n') +
  xref_entry_line(child_pages_offset, 0, b'n') +
  xref_entry_line(first_page_offset, 0, b'n') +
  xref_entry_line(second_page_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 6 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_document_structure_inherited_resources_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources <</Font 4 0 R>> >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
  )
  let (bytes, font_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(font_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_document_structure_names_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 3 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Dests 5 0 R /AP 6 0 R /JavaScript 7 0 R /Pages 8 0 R /Templates 9 0 R /EmbeddedFiles 10 0 R /AlternatePresentations 11 0 R >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, dests_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [(chapter-1) 12 0 R (chapter-2) 13 0 R] >>",
  )
  let (bytes, ap_kids_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Kids [14 0 R] /Limits [(appearance-a) (appearance-z)] >>",
  )
  let (bytes, javascript_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /Names [(init) 15 0 R] >>",
  )
  let (bytes, pages_names_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"<< /Names [(page-1) 16 0 R] >>",
  )
  let (bytes, templates_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"<< /Names [(template-a) 17 0 R] >>",
  )
  let (bytes, embedded_files_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"<< /Kids [18 0 R] >>",
  )
  let (bytes, alternate_presentations_offset) = append_indirect_object(
    bytes, header_base, 11, 0, b"<< /Names [(presentation-a) 19 0 R] >>",
  )
  let (bytes, chapter_one_offset) = append_indirect_object(
    bytes, header_base, 12, 0, b"(destination-one)",
  )
  let (bytes, chapter_two_offset) = append_indirect_object(
    bytes, header_base, 13, 0, b"<< /Label /Two >>",
  )
  let (bytes, appearance_leaf_offset) = append_indirect_object(
    bytes, header_base, 14, 0, b"<< /Names [(appearance-a) 20 0 R] >>",
  )
  let (bytes, javascript_value_offset) = append_indirect_object(
    bytes, header_base, 15, 0, b"/JavaScript",
  )
  let (bytes, pages_value_offset) = append_indirect_object(
    bytes, header_base, 16, 0, b"(page-value)",
  )
  let (bytes, templates_value_offset) = append_indirect_object(
    bytes, header_base, 17, 0, b"[ /Template ]",
  )
  let (bytes, embedded_file_leaf_offset) = append_indirect_object(
    bytes, header_base, 18, 0, b"<< /Names [(file-a) 21 0 R] >>",
  )
  let (bytes, alternate_presentations_value_offset) = append_indirect_object(
    bytes, header_base, 19, 0, b"<</Flag true>>",
  )
  let (bytes, appearance_value_offset) = append_indirect_object(
    bytes, header_base, 20, 0, b"(appearance-value)",
  )
  let (bytes, file_value_offset) = append_indirect_object(
    bytes, header_base, 21, 0, b"(file-value)",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 22\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(dests_offset, 0, b'n') +
  xref_entry_line(ap_kids_offset, 0, b'n') +
  xref_entry_line(javascript_offset, 0, b'n') +
  xref_entry_line(pages_names_offset, 0, b'n') +
  xref_entry_line(templates_offset, 0, b'n') +
  xref_entry_line(embedded_files_offset, 0, b'n') +
  xref_entry_line(alternate_presentations_offset, 0, b'n') +
  xref_entry_line(chapter_one_offset, 0, b'n') +
  xref_entry_line(chapter_two_offset, 0, b'n') +
  xref_entry_line(appearance_leaf_offset, 0, b'n') +
  xref_entry_line(javascript_value_offset, 0, b'n') +
  xref_entry_line(pages_value_offset, 0, b'n') +
  xref_entry_line(templates_value_offset, 0, b'n') +
  xref_entry_line(embedded_file_leaf_offset, 0, b'n') +
  xref_entry_line(alternate_presentations_value_offset, 0, b'n') +
  xref_entry_line(appearance_value_offset, 0, b'n') +
  xref_entry_line(file_value_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 22 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
