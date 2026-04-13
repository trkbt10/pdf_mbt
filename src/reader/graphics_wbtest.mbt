///|
test "page graphics initial state derives crop box user unit and rotate" {
  let document = PdfDocument::open(build_page_graphics_metadata_fixture())
  let page = document.page(0)
  let initial = page.graphics_initial_state(GraphicsPageOptions::default())
  assert_eq(initial.user_unit, 2.0)
  assert_eq(initial.page_rotate, 90)
  match initial.initial_clip {
    Some(path) => {
      assert_eq(path.subpaths.length(), 1)
      assert_eq(
        path.subpaths[0].start == @graphics.GraphicsPoint::new(10.0, 20.0),
        true,
      )
    }
    None => fail("expected initial clipping path")
  }
}

///|
test "page graphics program interprets parsed page content" {
  let document = PdfDocument::open(build_page_graphics_metadata_fixture())
  let page = document.page(0)
  let program = page.graphics_program(GraphicsPageOptions::default())
  assert_eq(program.events.length(), 1)
  match program.events[0] {
    @graphics.GraphicsEvent::PathPainted(
      _,
      @graphics.PathPaintOperation::StrokePath,
      path,
      state
    ) => {
      assert_eq(path.subpaths.length(), 1)
      assert_eq(state.user_unit, 2.0)
    }
    _ => fail("expected page path paint event")
  }
}

///|
test "page graphics wraps graphics errors at document boundary" {
  let document = PdfDocument::open(build_page_graphics_bad_path_fixture())
  let page = document.page(0)
  let result : Result[@graphics.GraphicsProgram, PdfDocumentError] = try? page.graphics_program(
    GraphicsPageOptions::default(),
  )
  match result {
    Err(GraphicsError(@graphics.PdfGraphicsError::InvalidPathState(_, _))) => ()
    _ => fail("expected wrapped graphics error")
  }
}

///|
fn build_page_graphics_metadata_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /CropBox [10 20 300 400] /Rotate 90 /UserUnit 2 /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(
    b"<< /Length 14 >>", b"0 0 m 10 0 l S",
  )
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}

///|
fn build_page_graphics_bad_path_fixture() -> Bytes {
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
  let content_stream = build_stream_object_body(b"<< /Length 1 >>", b"S")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )

  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset,
  ])
}
