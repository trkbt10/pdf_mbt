///|
fn action_test_doc() -> PdfDocument raise PdfDocumentError {
  PdfDocument::open(build_document_structure_single_page_fixture())
}

///|
fn action_test_dict(action_type : Bytes) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[action_key(b"S")] = @objects.PdfObject::Name(action_key(action_type))
  dict
}

///|
fn action_test_object(action_type : Bytes) -> @objects.PdfObject {
  @objects.PdfObject::Dictionary(action_test_dict(action_type))
}

///|
fn action_stream(data : Bytes) -> @objects.PdfObject {
  @objects.PdfObject::Stream(@objects.PdfStream::{ dict: Map::new(), data })
}

///|
test "common action parser validates Type S Next and unknown action names" {
  let document = action_test_doc()
  let unknown_dict = action_test_dict(b"VendorAction")
  let unknown = document.parse_action(
    @objects.PdfObject::Dictionary(unknown_dict),
  )
  match unknown.kind {
    PdfActionKind::Unknown(name, raw) => {
      assert_eq(name == action_key(b"VendorAction"), true)
      assert_eq(raw.get(action_key(b"S")) is Some(_), true)
    }
    _ => fail("expected unknown action")
  }

  let typed_dict = action_test_dict(b"Named")
  typed_dict[action_key(b"Type")] = @objects.PdfObject::Name(
    action_key(b"Action"),
  )
  typed_dict[action_key(b"N")] = @objects.PdfObject::Name(
    action_key(b"NextPage"),
  )
  let typed = document.parse_action(@objects.PdfObject::Dictionary(typed_dict))
  match typed.kind {
    PdfActionKind::Named(named) =>
      assert_eq(named.name == action_key(b"NextPage"), true)
    _ => fail("expected named action")
  }

  let missing_s : @objects.PdfDictionary = Map::new()
  let missing_result : Result[PdfAction, PdfDocumentError] = try? document.parse_action(
    @objects.PdfObject::Dictionary(missing_s),
  )
  match missing_result {
    Err(InvalidAction(_, None, reason)) =>
      assert_eq(reason, "action dictionary is missing /S")
    _ => fail("expected missing S action error")
  }

  let bad_next = action_test_dict(b"Named")
  bad_next[action_key(b"N")] = @objects.PdfObject::Name(action_key(b"NextPage"))
  bad_next[action_key(b"Next")] = @objects.PdfObject::Integer(1L)
  let bad_next_result : Result[PdfAction, PdfDocumentError] = try? document.parse_action(
    @objects.PdfObject::Dictionary(bad_next),
  )
  match bad_next_result {
    Err(InvalidAction(_, Some(name), reason)) => {
      assert_eq(name == action_key(b"Named"), true)
      assert_eq(reason.contains("Next"), true)
    }
    _ => fail("expected malformed Next action error")
  }

  let root = action_test_dict(b"URI")
  root[action_key(b"URI")] = @objects.PdfObject::String(b"https://root.test")
  root[action_key(b"Next")] = @objects.PdfObject::Array([
    action_test_object(b"VendorAction"),
    {
      let named = action_test_dict(b"Named")
      named[action_key(b"N")] = @objects.PdfObject::Name(
        action_key(b"LastPage"),
      )
      @objects.PdfObject::Dictionary(named)
    },
  ])
  let parsed = document.parse_action(@objects.PdfObject::Dictionary(root))
  assert_eq(parsed.next.length(), 2)
  match parsed.next[0].kind {
    PdfActionKind::Unknown(name, _) =>
      assert_eq(name == action_key(b"VendorAction"), true)
    _ => fail("expected unknown first Next action")
  }
  match parsed.next[1].kind {
    PdfActionKind::Named(named) =>
      assert_eq(named.name == action_key(b"LastPage"), true)
    _ => fail("expected named second Next action")
  }
}

///|
test "indirect Next action cycles are rejected with object identity" {
  let document = PdfDocument::open(build_action_cycle_fixture())
  let result : Result[PdfAction, PdfDocumentError] = try? document.parse_action(
    @objects.PdfObject::Ref(oid(4)),
  )
  match result {
    Err(CycleDetected(object_id, reason)) => {
      assert_eq(object_id == oid(4), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected action cycle error")
  }
}

///|
test "standard action kinds parse as structural metadata only" {
  let document = action_test_doc()

  let go_to = action_test_dict(b"GoTo")
  go_to[action_key(b"D")] = @objects.PdfObject::Array([
    @objects.PdfObject::Ref(oid(3)),
    @objects.PdfObject::Name(action_key(b"Fit")),
  ])
  match document.parse_action(@objects.PdfObject::Dictionary(go_to)).kind {
    PdfActionKind::GoTo(action) =>
      match action.destination.target {
        PdfDestinationTarget::LocalPage(object_id) =>
          assert_eq(object_id == oid(3), true)
        _ => fail("expected local page destination")
      }
    _ => fail("expected GoTo action")
  }

  let go_to_r = action_test_dict(b"GoToR")
  go_to_r[action_key(b"F")] = @objects.PdfObject::String(b"remote.pdf")
  go_to_r[action_key(b"D")] = @objects.PdfObject::String(b"chapter")
  match document.parse_action(@objects.PdfObject::Dictionary(go_to_r)).kind {
    PdfActionKind::GoToR(action) =>
      assert_eq(
        action.file_specification == @objects.PdfObject::String(b"remote.pdf"),
        true,
      )
    _ => fail("expected GoToR action")
  }

  let go_to_e = action_test_dict(b"GoToE")
  go_to_e[action_key(b"F")] = @objects.PdfObject::String(b"container.pdf")
  go_to_e[action_key(b"D")] = @objects.PdfObject::String(b"chapter")
  match document.parse_action(@objects.PdfObject::Dictionary(go_to_e)).kind {
    PdfActionKind::GoToE(action) =>
      assert_eq(
        action.destination == @objects.PdfObject::String(b"chapter"),
        true,
      )
    _ => fail("expected GoToE action")
  }

  let go_to_dp = action_test_dict(b"GoToDp")
  go_to_dp[action_key(b"Dp")] = @objects.PdfObject::Ref(oid(8))
  match document.parse_action(@objects.PdfObject::Dictionary(go_to_dp)).kind {
    PdfActionKind::GoToDp(action) => assert_eq(action.dpart == oid(8), true)
    _ => fail("expected GoToDp action")
  }

  let launch = action_test_dict(b"Launch")
  launch[action_key(b"F")] = @objects.PdfObject::String(b"file.pdf")
  match document.parse_action(@objects.PdfObject::Dictionary(launch)).kind {
    PdfActionKind::Launch(action) =>
      assert_eq(
        action.file_specification ==
        Some(@objects.PdfObject::String(b"file.pdf")),
        true,
      )
    _ => fail("expected Launch action")
  }

  let thread = action_test_dict(b"Thread")
  thread[action_key(b"D")] = @objects.PdfObject::Integer(0L)
  match document.parse_action(@objects.PdfObject::Dictionary(thread)).kind {
    PdfActionKind::Thread(action) =>
      assert_eq(action.thread == Some(@objects.PdfObject::Integer(0L)), true)
    _ => fail("expected Thread action")
  }

  let uri = action_test_dict(b"URI")
  uri[action_key(b"URI")] = @objects.PdfObject::String(b"https://example.test")
  match document.parse_action(@objects.PdfObject::Dictionary(uri)).kind {
    PdfActionKind::URI(action) => {
      assert_eq(action.uri == b"https://example.test", true)
      assert_eq(action.is_map, false)
    }
    _ => fail("expected URI action")
  }

  let sound = action_test_dict(b"Sound")
  sound[action_key(b"Sound")] = action_stream(b"sound")
  match document.parse_action(@objects.PdfObject::Dictionary(sound)).kind {
    PdfActionKind::Sound(action) => assert_eq(action.volume, 1.0)
    _ => fail("expected Sound action")
  }

  let movie = action_test_dict(b"Movie")
  movie[action_key(b"T")] = @objects.PdfObject::String(b"intro")
  match document.parse_action(@objects.PdfObject::Dictionary(movie)).kind {
    PdfActionKind::Movie(action) =>
      assert_eq(action.operation == PdfMovieOperation::Play, true)
    _ => fail("expected Movie action")
  }

  let hide = action_test_dict(b"Hide")
  hide[action_key(b"T")] = @objects.PdfObject::String(b"field.name")
  match document.parse_action(@objects.PdfObject::Dictionary(hide)).kind {
    PdfActionKind::Hide(action) => assert_eq(action.hide, true)
    _ => fail("expected Hide action")
  }

  let named = action_test_dict(b"Named")
  named[action_key(b"N")] = @objects.PdfObject::Name(action_key(b"FirstPage"))
  match document.parse_action(@objects.PdfObject::Dictionary(named)).kind {
    PdfActionKind::Named(action) =>
      assert_eq(action.name == action_key(b"FirstPage"), true)
    _ => fail("expected Named action")
  }

  let submit = action_test_dict(b"SubmitForm")
  submit[action_key(b"F")] = @objects.PdfObject::String(b"https://submit.test")
  match document.parse_action(@objects.PdfObject::Dictionary(submit)).kind {
    PdfActionKind::SubmitForm(action) =>
      assert_eq(action.file_specification is Some(_), true)
    _ => fail("expected SubmitForm action")
  }

  let ocg = action_test_dict(b"SetOCGState")
  ocg[action_key(b"State")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(action_key(b"OFF")),
    @objects.PdfObject::Ref(oid(8)),
    @objects.PdfObject::Name(action_key(b"Toggle")),
    @objects.PdfObject::Dictionary(Map::new()),
  ])
  match document.parse_action(@objects.PdfObject::Dictionary(ocg)).kind {
    PdfActionKind::SetOCGState(action) => {
      assert_eq(action.preserve_rb, true)
      assert_eq(action.operations.length(), 2)
    }
    _ => fail("expected SetOCGState action")
  }

  let rendition = action_test_dict(b"Rendition")
  rendition[action_key(b"OP")] = @objects.PdfObject::Integer(1L)
  rendition[action_key(b"AN")] = @objects.PdfObject::Ref(oid(6))
  match document.parse_action(@objects.PdfObject::Dictionary(rendition)).kind {
    PdfActionKind::Rendition(action) =>
      assert_eq(action.operation == Some(1), true)
    _ => fail("expected Rendition action")
  }

  let trans = action_test_dict(b"Trans")
  let trans_dict : @objects.PdfDictionary = Map::new()
  trans_dict[action_key(b"S")] = @objects.PdfObject::Name(action_key(b"Fade"))
  trans[action_key(b"Trans")] = @objects.PdfObject::Dictionary(trans_dict)
  match document.parse_action(@objects.PdfObject::Dictionary(trans)).kind {
    PdfActionKind::Trans(action) =>
      assert_eq(action.transition.style == PdfTransitionStyle::Fade, true)
    _ => fail("expected Trans action")
  }

  let go_to_3d = action_test_dict(b"GoTo3DView")
  go_to_3d[action_key(b"TA")] = @objects.PdfObject::Ref(oid(6))
  go_to_3d[action_key(b"V")] = @objects.PdfObject::Name(action_key(b"F"))
  match document.parse_action(@objects.PdfObject::Dictionary(go_to_3d)).kind {
    PdfActionKind::GoTo3DView(action) =>
      assert_eq(
        action.view == Some(@objects.PdfObject::Name(action_key(b"F"))),
        true,
      )
    _ => fail("expected GoTo3DView action")
  }

  let js = action_test_dict(b"JavaScript")
  js[action_key(b"JS")] = @objects.PdfObject::String(b"app.alert('x')")
  match document.parse_action(@objects.PdfObject::Dictionary(js)).kind {
    PdfActionKind::JavaScript(action) =>
      assert_eq(
        action.script == @objects.PdfObject::String(b"app.alert('x')"),
        true,
      )
    _ => fail("expected JavaScript action")
  }

  let rich = action_test_dict(b"RichMediaExecute")
  rich[action_key(b"TA")] = @objects.PdfObject::Ref(oid(6))
  rich[action_key(b"CMD")] = @objects.PdfObject::Dictionary(Map::new())
  match document.parse_action(@objects.PdfObject::Dictionary(rich)).kind {
    PdfActionKind::RichMediaExecute(action) =>
      assert_eq(action.command == Map::new(), true)
    _ => fail("expected RichMediaExecute action")
  }
}

///|
test "action source accessors preserve raw APIs and parse trigger metadata" {
  let document = PdfDocument::open(build_action_source_fixture())
  match document.open_action() {
    Some(PdfCatalogOpenAction::Action(action)) =>
      match action.kind {
        PdfActionKind::URI(uri) =>
          assert_eq(uri.uri == b"https://catalog.test", true)
        _ => fail("expected catalog URI action")
      }
    _ => fail("expected typed catalog action")
  }
  match document.catalog_uri() {
    Some(uri) =>
      assert_eq(uri.base == Some(b"https://example.test/base/"), true)
    None => fail("expected catalog URI base")
  }
  match document.catalog_additional_actions() {
    Some(actions) => {
      assert_eq(actions.before_close is Some(_), true)
      assert_eq(actions.raw_dict.get(action_key(b"Z")) is Some(_), true)
    }
    None => fail("expected catalog additional actions")
  }

  let page = document.page(0)
  match page.additional_actions() {
    Some(actions) => {
      assert_eq(actions.open is Some(_), true)
      assert_eq(actions.raw_dict.get(action_key(b"Z")) is Some(_), true)
    }
    None => fail("expected page additional actions")
  }

  let annotations = page.annotations()
  assert_eq(annotations.length(), 1)
  match document.annotation_action(annotations[0]) {
    Some(action) =>
      match action.kind {
        PdfActionKind::URI(uri) =>
          assert_eq(uri.uri == b"https://annot.test", true)
        _ => fail("expected annotation URI action")
      }
    None => fail("expected annotation action")
  }
  match document.annotation_additional_actions(annotations[0]) {
    Some(actions) => {
      assert_eq(actions.enter is Some(_), true)
      assert_eq(actions.raw_dict.get(action_key(b"Z")) is Some(_), true)
    }
    None => fail("expected annotation additional actions")
  }

  let nodes = page.navigation_nodes()
  assert_eq(nodes.length(), 1)
  assert_eq(page.navigation_node_forward_action(nodes[0]) is Some(_), true)
  assert_eq(page.navigation_node_backward_action(nodes[0]) is Some(_), true)

  let ordering = PdfActionTriggerOrdering::standard()
  assert_eq(ordering.page_open_order.length(), 3)
  assert_eq(
    ordering.page_close_order[0] == PdfActionTrigger::AnnotationPageClose,
    true,
  )
}

///|
fn build_action_cycle_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, action_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /S /Named /N /NextPage /Next 4 0 R >>",
  )
  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 5\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(action_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 5 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_action_source_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /OpenAction 4 0 R /URI << /Base (https://example.test/base/) >> /AA << /WC 5 0 R /Z 5 0 R >> >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /AA << /O 5 0 R /Z 5 0 R >> /Annots [6 0 R] /PresSteps 7 0 R >>",
  )
  let (bytes, catalog_action_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Action /S /URI /URI (https://catalog.test) >>",
  )
  let (bytes, named_action_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /S /Named /N /NextPage >>",
  )
  let (bytes, annotation_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /URI /URI (https://annot.test) >> /AA << /E 5 0 R /Z 5 0 R >> >>",
  )
  let (bytes, nav_node_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /NA 5 0 R /PA << /S /Named /N /PrevPage >> >>",
  )
  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 8\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(catalog_action_offset, 0, b'n') +
  xref_entry_line(named_action_offset, 0, b'n') +
  xref_entry_line(annotation_offset, 0, b'n') +
  xref_entry_line(nav_node_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 8 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
