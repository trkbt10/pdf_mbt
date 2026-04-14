///|
fn build_navigation_fixture() -> Bytes {
  let prefix = b"nav\n"
  let header = b"%PDF-1.7\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes,
    header_base,
    1,
    0,
    b"<< /Type /Catalog /Pages 2 0 R" +
    b" /ViewerPreferences << /HideToolbar true /Direction /R2L /PrintScaling /None /Enforce [/PrintScaling] >>" +
    b" /Names 4 0 R /Dests << /Legacy [3 0 R /FitH null] >>" +
    b" /Outlines 7 0 R /PageLabels 8 0 R /Threads [9 0 R] /Collection 14 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes,
    header_base,
    3,
    0,
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]" +
    b" /Thumb 10 0 R /Dur 2 /Trans << /S /Fade /D 0.5 >>" +
    b" /PresSteps 11 0 R /B [12 0 R] >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Dests 5 0 R /EmbeddedFiles 6 0 R >>",
  )
  let (bytes, dests_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [(chapter-1) [3 0 R /XYZ null 72 0]] >>",
  )
  let (bytes, embedded_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Names [([42]file.txt) << /F (file.txt) >>] >>",
  )
  let (bytes, outlines_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /First 13 0 R /Last 13 0 R /Count 1 >>",
  )
  let (bytes, labels_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"<< /Nums [0 << /S /D /P (p-) /St 1 >>] >>",
  )
  let (bytes, thread_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"<< /F 12 0 R /I << /Title (Article) >> >>",
  )
  let (bytes, thumb_offset) = append_indirect_object(
    bytes,
    header_base,
    10,
    0,
    build_stream_object_body(
      b"<< /Width 16 /Height 8 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 0 >>",
      b"",
    ),
  )
  let (bytes, nav_offset) = append_indirect_object(
    bytes, header_base, 11, 0, b"<< /NA << /S /Named /N /NextPage >> /PA << /S /Named /N /PrevPage >> >>",
  )
  let (bytes, bead_offset) = append_indirect_object(
    bytes, header_base, 12, 0, b"<< /T 9 0 R /P 3 0 R /R [0 0 10 10] /N 12 0 R /V 12 0 R >>",
  )
  let (bytes, outline_item_offset) = append_indirect_object(
    bytes, header_base, 13, 0, b"<< /Title (Intro) /Parent 7 0 R /Dest (chapter-1) /Count 0 /C [1 0 0] /F 3 >>",
  )
  let (bytes, collection_offset) = append_indirect_object(
    bytes,
    header_base,
    14,
    0,
    b"<< /View /T /D ([42]file.txt)" +
    b" /Schema << /Title << /Subtype /S /N (Title) /O 1 >> >>" +
    b" /Sort << /S /Title /A false >> /C [0.1 0.2 0.3]" +
    b" /Folders 15 0 R /Navigator << /Layout /Custom /Fallback [/D] >> >>",
  )
  let (bytes, folder_offset) = append_indirect_object(
    bytes, header_base, 15, 0, b"<< /ID 42 /Name (Folder) >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 16\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(dests_offset, 0, b'n') +
  xref_entry_line(embedded_offset, 0, b'n') +
  xref_entry_line(outlines_offset, 0, b'n') +
  xref_entry_line(labels_offset, 0, b'n') +
  xref_entry_line(thread_offset, 0, b'n') +
  xref_entry_line(thumb_offset, 0, b'n') +
  xref_entry_line(nav_offset, 0, b'n') +
  xref_entry_line(bead_offset, 0, b'n') +
  xref_entry_line(outline_item_offset, 0, b'n') +
  xref_entry_line(collection_offset, 0, b'n') +
  xref_entry_line(folder_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 16 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
test "interactive navigation facade reads catalog and page metadata" {
  let document = PdfDocument::open(build_navigation_fixture())
  assert_eq(document.page_count(), 1)

  let prefs = document.viewer_preferences()
  assert_eq(prefs.hide_toolbar, true)
  assert_eq(prefs.direction == PdfReadingDirection::RightToLeft, true)
  assert_eq(prefs.print_scaling == PdfPrintScaling::None, true)
  assert_eq(prefs.enforce.length(), 1)

  let entries = document.name_tree_entries(NameTreeCategory::Dests)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].key, b"chapter-1")
  assert_eq(
    document.lookup_name(NameTreeCategory::Dests, b"chapter-1") is Some(_),
    true,
  )

  match document.named_destination(b"chapter-1") {
    Some(named) =>
      match named.destination.view {
        XYZ(left, top, zoom) => {
          assert_eq(left is None, true)
          assert_eq(top == Some(72.0), true)
          assert_eq(zoom == Some(0.0), true)
        }
        _ => fail("expected XYZ destination")
      }
    None => fail("expected named destination")
  }

  match document.named_destination(b"Legacy") {
    Some(named) =>
      match named.destination.view {
        FitH(top) => assert_eq(top is None, true)
        _ => fail("expected legacy FitH destination")
      }
    None => fail("expected legacy destination")
  }

  match document.outline() {
    Some(outline) => {
      assert_eq(outline.items.length(), 1)
      assert_eq(outline.items[0].title, b"Intro")
      assert_eq(outline.items[0].bold, true)
      assert_eq(outline.items[0].italic, true)
    }
    None => fail("expected outline")
  }

  match document.collection() {
    Some(collection) => {
      assert_eq(collection.files.length(), 1)
      assert_eq(collection.files[0].folder_id == Some(42), true)
      assert_eq(collection.folders.length(), 1)
      assert_eq(collection.folders[0].name, b"Folder")
      assert_eq(collection.schema.length(), 1)
      assert_eq(collection.navigator is Some(_), true)
    }
    None => fail("expected collection")
  }

  match document.page_label(0) {
    Some(label) => assert_eq(label.label, b"p-1")
    None => fail("expected page label")
  }
  assert_eq(document.page_label_ranges().length(), 1)

  let threads = document.threads()
  assert_eq(threads.length(), 1)
  assert_eq(threads[0].beads.length(), 1)
  assert_eq(threads[0].beads[0].page_index == Some(0), true)

  let page = document.page(0)
  match page.thumbnail() {
    Some(thumbnail) => {
      assert_eq(thumbnail.width, 16)
      assert_eq(thumbnail.height, 8)
      assert_eq(
        thumbnail.color_space == PdfThumbnailColorSpace::DeviceRGB,
        true,
      )
    }
    None => fail("expected thumbnail")
  }
  let presentation = page.presentation()
  assert_eq(presentation.duration == Some(2.0), true)
  match presentation.transition {
    Some(transition) =>
      assert_eq(transition.style == PdfTransitionStyle::Fade, true)
    None => fail("expected transition")
  }
  assert_eq(page.navigation_nodes().length(), 1)
  assert_eq(page.article_beads().length(), 1)
}

///|
test "malformed present navigation dictionaries raise navigation errors lazily" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[navigation_key(b"Direction")] = @objects.PdfObject::Name(
    navigation_key(b"Bad"),
  )
  let result : Result[PdfViewerPreferences, PdfDocumentError] = try? parse_viewer_preferences_dictionary(
    dict,
  )
  match result {
    Err(InvalidNavigation(name, reason)) => {
      assert_eq(name == navigation_key(b"ViewerPreferences"), true)
      assert_eq(reason, "Direction must be /L2R or /R2L")
    }
    _ => fail("expected navigation error")
  }
}
