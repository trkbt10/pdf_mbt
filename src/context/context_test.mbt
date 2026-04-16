///|
test "PdfContext creates a parseable single-page document" {
  let context = @context.PdfContext::new()
  context.set_title(b"Context Title")
  let page_ref = context.add_page(300.0, 400.0)
  context.add_font(page_ref, @objects.PdfName::new(b"F1"), helvetica_font())
  |> ignore
  context.set_page_content(page_ref, sample_text_content(b"Hello")) |> ignore
  let bytes = context.to_bytes()
  let document = @reader.PdfDocument::open(bytes)
  assert_eq(document.page_count(), 1)
  let page = document.page(0)
  match page.media_box() {
    Some(media_box) => {
      assert_eq(media_box.right, 300.0)
      assert_eq(media_box.top, 400.0)
    }
    None => fail("expected MediaBox")
  }
  assert_eq(page.content_instructions().length(), 5)
  let file = @reader.PdfFile::open(bytes)
  match file.trailer().info {
    Some(info_ref) =>
      match file.load_object(info_ref) {
        @objects.PdfObject::Dictionary(info) =>
          assert_eq(
            info.get(@objects.PdfName::new(b"Title")) ==
            Some(@objects.PdfObject::String(b"Context Title")),
            true,
          )
        _ => fail("expected Info dictionary")
      }
    None => fail("expected Info reference")
  }
}

///|
test "PdfContext removes pages from the page tree" {
  let context = @context.PdfContext::new()
  let first = context.add_page(100.0, 200.0)
  let second = context.add_page(300.0, 400.0)
  context.set_page_content(first, sample_text_content(b"First")) |> ignore
  context.set_page_content(second, sample_text_content(b"Second")) |> ignore
  context.remove_page(0)
  let document = @reader.PdfDocument::open(context.to_bytes())
  assert_eq(document.page_count(), 1)
  match document.page(0).media_box() {
    Some(media_box) => {
      assert_eq(media_box.right, 300.0)
      assert_eq(media_box.top, 400.0)
    }
    None => fail("expected remaining page MediaBox")
  }
}

///|
test "PdfContext from_document roundtrips and supports incremental edits" {
  let original_context = @context.PdfContext::new()
  let page_ref = original_context.add_page(612.0, 792.0)
  original_context.add_font(
    page_ref,
    @objects.PdfName::new(b"F1"),
    helvetica_font(),
  )
  |> ignore
  original_context.set_page_content(page_ref, sample_text_content(b"Original"))
  |> ignore
  let original = original_context.to_bytes()
  let parsed = @reader.PdfDocument::open(original)
  let context = @context.PdfContext::from_document(parsed)
  assert_eq(context.object_count() >= original_context.object_count(), true)
  let refs = context.page_refs()
  assert_eq(refs.length(), 1)
  context.set_page_content(refs[0], sample_text_content(b"Updated")) |> ignore
  let full = context.to_bytes()
  let reparsed = @reader.PdfDocument::open(full)
  assert_eq(reparsed.page_count(), 1)
  assert_eq(reparsed.page(0).content_instructions().length(), 5)
  let incremental = context.to_incremental_bytes(original)
  assert_eq(incremental.has_prefix(original), true)
  assert_eq(incremental.rev_find(b"/Prev") is Some(_), true)
  assert_eq(incremental.rev_find(b"Updated") is Some(_), true)
  let incremental_document = @reader.PdfDocument::open(incremental)
  assert_eq(incremental_document.page_count(), 1)
  assert_eq(incremental_document.page(0).content_instructions().length(), 5)
}

///|
fn helvetica_font() -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Type")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Font"),
  )
  dict[@objects.PdfName::new(b"Subtype")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Type1"),
  )
  dict[@objects.PdfName::new(b"BaseFont")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Helvetica"),
  )
  @objects.PdfObject::Dictionary(dict)
}

///|
fn sample_text_content(text : Bytes) -> Bytes {
  b"BT\n/F1 12 Tf\n72 720 Td\n" +
  @context.serialize_object(@objects.PdfObject::String(text)) +
  b" Tj\nET\n"
}
