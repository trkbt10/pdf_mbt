///|
fn build_annotation_fixture(duplicate_across_pages : Bool) -> Bytes {
  let prefix = b"annotations\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
  )
  let first_annots = b"[5 0 R << /Type /Annot /Subtype /Link /Rect [1 2 3 4] /A << /S /URI /URI (https://example.test) >> >> 6 0 R]"
  let (bytes, first_page_offset) = append_indirect_object(
    bytes,
    header_base,
    3,
    0,
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Tabs /A /Annots " +
    first_annots +
    b" >>",
  )
  let second_annots = if duplicate_across_pages {
    b" /Annots [5 0 R]"
  } else {
    b""
  }
  let (bytes, second_page_offset) = append_indirect_object(
    bytes,
    header_base,
    4,
    0,
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100]" +
    second_annots +
    b" >>",
  )
  let (bytes, text_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    b"<< /Type /Annot /Subtype /Text /Rect [0 0 10 10] /Contents (note)" +
    b" /NM (a1) /F 4 /Name /Comment /Open true /C [1 0 0]" +
    b" /Border [0 0 2 [3]] >>",
  )
  let (bytes, stamp_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Type /Annot /Subtype /Stamp /Rect [10 10 20 20] /IT /StampImage /Name /Approved >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(first_page_offset, 0, b'n') +
  xref_entry_line(second_page_offset, 0, b'n') +
  xref_entry_line(text_offset, 0, b'n') +
  xref_entry_line(stamp_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
test "page annotations preserve source order and parse common fields" {
  let document = PdfDocument::open(build_annotation_fixture(false))
  let page = document.page(0)
  assert_eq(page.annotation_tab_order() == Some(AnnotationArray), true)
  let raw = page.annots()
  assert_eq(raw is Some(_), true)

  let annotations = page.annotations()
  assert_eq(annotations.length(), 3)
  assert_eq(annotations[0].page_index, 0)
  assert_eq(annotations[0].array_index, 0)
  assert_eq(annotations[0].object_id == Some(oid(5)), true)
  assert_eq(annotations[0].common.subtype == PdfAnnotationSubtype::Text, true)
  assert_eq(annotations[0].common.contents == Some(b"note"), true)
  assert_eq(annotations[0].common.flags.print(), true)
  assert_eq(annotations[0].no_zoom(), true)
  assert_eq(annotations[0].common.color, [1.0, 0.0, 0.0])
  assert_eq(annotations[0].common.border.width, 2.0)

  match annotations[0].specific {
    Text(text) => {
      assert_eq(text.open, true)
      assert_eq(text.icon_name == annotation_key(b"Comment"), true)
    }
    _ => fail("expected text annotation")
  }
  match annotations[1].specific {
    Link(link) => {
      assert_eq(link.action is Some(_), true)
      assert_eq(link.highlight_mode == PdfHighlightMode::Invert, true)
    }
    _ => fail("expected link annotation")
  }
  match annotations[2].specific {
    Stamp(stamp) => {
      assert_eq(stamp.intent == annotation_key(b"StampImage"), true)
      assert_eq(stamp.icon_name == annotation_key(b"Approved"), true)
    }
    _ => fail("expected stamp annotation")
  }
}

///|
test "document annotations flatten pages and reject cross-page reused references" {
  let valid = PdfDocument::open(build_annotation_fixture(false))
  assert_eq(valid.annotations().length(), 3)
  assert_eq(valid.page(1).annotations().length(), 0)

  let duplicate = PdfDocument::open(build_annotation_fixture(true))
  let result : Result[Array[PdfAnnotation], PdfDocumentError] = try? duplicate.annotations()
  match result {
    Err(InvalidAnnotation(object_id, reason)) => {
      assert_eq(object_id == Some(oid(5)), true)
      assert_eq(reason.contains("multiple pages"), true)
    }
    _ => fail("expected duplicate annotation reference error")
  }
}

///|
test "malformed present page annotation entries raise annotation errors" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[annotation_key(b"Type")] = @objects.PdfObject::Name(
    annotation_key(b"Annot"),
  )
  dict[annotation_key(b"Rect")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(10L),
  ])
  let document = PdfDocument::open(build_annotation_fixture(false))
  let result : Result[PdfAnnotationCommon, PdfDocumentError] = try? parse_annotation_common(
    document.file,
    document.page(0),
    None,
    dict,
  )
  match result {
    Err(InvalidAnnotation(_, reason)) =>
      assert_eq(reason, "Subtype is required")
    _ => fail("expected missing subtype annotation error")
  }
}
