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
test "page graphics can materialize indirect image XObjects" {
  let document = PdfDocument::open(
    build_page_graphics_image_xobject_fixture(false),
  )
  let page = document.page(0)
  let unresolved = page.graphics_program(GraphicsPageOptions::default())
  match unresolved.events[0] {
    @graphics.GraphicsEvent::ExternalObjectInvoked(_, name) =>
      assert_eq(name == @objects.PdfName::new(b"Im1"), true)
    _ => fail("expected unresolved legacy XObject event")
  }
  let program = page.graphics_program(
    GraphicsPageOptions::with_materialized_xobjects(None),
  )
  match program.events[0] {
    @graphics.GraphicsEvent::ImagePainted(_, descriptor, _) =>
      assert_eq(descriptor.layout.expected_decoded_length, 3)
    _ => fail("expected materialized image event")
  }
}

///|
test "page graphics applies Catalog optional-content state to XObjects" {
  let document = PdfDocument::open(
    build_page_graphics_image_xobject_fixture(true),
  )
  let page = document.page(0)
  let program = page.graphics_program(
    GraphicsPageOptions::with_materialized_xobjects(None),
  )
  match program.events[0] {
    @graphics.GraphicsEvent::XObjectSkipped(
      _,
      name,
      @graphics.OptionalContentDecision::Hidden
    ) => assert_eq(name == @objects.PdfName::new(b"Im1"), true)
    _ => fail("expected hidden optional-content XObject skip")
  }
}

///|
test "page graphics materialization rejects recursive form XObjects" {
  let document = PdfDocument::open(build_page_graphics_recursive_form_fixture())
  let page = document.page(0)
  let result : Result[@graphics.GraphicsProgram, PdfDocumentError] = try? page.graphics_program(
    GraphicsPageOptions::with_materialized_xobjects(None),
  )
  match result {
    Err(CycleDetected(id, reason)) => {
      assert_eq(
        id == @objects.ObjectId::{ object_number: 5, generation_number: 0 },
        true,
      )
      assert_eq(reason.contains("recursive"), true)
    }
    _ => fail("expected recursive form materialization failure")
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
fn build_page_graphics_recursive_form_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Fm1 5 0 R >> >> /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(b"<< /Length 7 >>", b"/Fm1 Do")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let form_stream = build_stream_object_body(
    b"<< /Type /XObject /Subtype /Form /BBox [0 0 10 10] /Resources << /XObject << /Self 5 0 R >> >> /Length 8 >>",
    b"/Self Do",
  )
  let (bytes, form_offset) = append_indirect_object(
    bytes, header_base, 5, 0, form_stream,
  )
  finish_page_content_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, content_offset, form_offset,
  ])
}

///|
fn build_page_graphics_image_xobject_fixture(hidden : Bool) -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let catalog_body = if hidden {
    b"<< /Type /Catalog /Pages 2 0 R /OCProperties << /OCGs [6 0 R] /D << /OFF [6 0 R] >> >> >>"
  } else {
    b"<< /Type /Catalog /Pages 2 0 R >>"
  }
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, catalog_body,
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
  )
  let content_stream = build_stream_object_body(b"<< /Length 7 >>", b"/Im1 Do")
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let image_dict = if hidden {
    b"<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /OC 6 0 R /Length 3 >>"
  } else {
    b"<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 3 >>"
  }
  let image_stream = build_stream_object_body(image_dict, b"abc")
  let (bytes, image_offset) = append_indirect_object(
    bytes, header_base, 5, 0, image_stream,
  )
  if hidden {
    let (bytes, ocg_offset) = append_indirect_object(
      bytes, header_base, 6, 0, b"<< /Type /OCG /Name (Hidden) >>",
    )
    finish_page_content_fixture(bytes, header_base, [
      catalog_offset, pages_offset, page_offset, content_offset, image_offset, ocg_offset,
    ])
  } else {
    finish_page_content_fixture(bytes, header_base, [
      catalog_offset, pages_offset, page_offset, content_offset, image_offset,
    ])
  }
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
