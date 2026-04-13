///|
test "page pattern and shading helpers load indirect resources" {
  let document = PdfDocument::open(build_pattern_resource_fixture())
  let page = document.page(0)

  match page.pattern_resource(@objects.PdfName::new(b"P1")) {
    @graphics.PatternResource::DirectPattern(
      name,
      @graphics.PatternDefinition::Tiling(pattern)
    ) => {
      assert_eq(name == @objects.PdfName::new(b"P1"), true)
      assert_eq(
        pattern.paint_type == @graphics.PatternPaintType::Coloured,
        true,
      )
      assert_eq(pattern.x_step, 10.0)
    }
    _ => fail("expected loaded tiling pattern")
  }

  match page.shading_resource(@objects.PdfName::new(b"S1")) {
    @graphics.ShadingResource::DirectShading(Some(name), shading) => {
      assert_eq(name == @objects.PdfName::new(b"S1"), true)
      match shading.kind {
        @graphics.ShadingKind::Axial(axial) =>
          assert_eq(axial.domain, [0.0, 1.0])
        _ => fail("expected axial shading")
      }
    }
    _ => fail("expected loaded axial shading")
  }

  assert_eq(page.pattern_resources().length(), 1)
}

///|
fn build_pattern_resource_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Pattern << /P1 5 0 R >> /Shading << /S1 6 0 R >> >> >>",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes,
    header_base,
    4,
    0,
    build_stream_object_body(b"<< /Length 0 >>", b""),
  )
  let (bytes, pattern_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    build_stream_object_body(
      b"<< /Type /Pattern /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 10 10] /XStep 10 /YStep 10 /Resources <<>> /Length 0 >>",
      b"",
    ),
  )
  let (bytes, shading_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /ShadingType 2 /ColorSpace /DeviceRGB /Coords [0 0 1 0] /Function <<>> >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 7\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(content_offset, 0, b'n') +
  xref_entry_line(pattern_offset, 0, b'n') +
  xref_entry_line(shading_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 7 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
