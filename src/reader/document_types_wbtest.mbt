///|
test "document structure foundation types are constructible" {
  let object_id = @objects.ObjectId::{ object_number: 12, generation_number: 0 }
  let dict : @objects.PdfDictionary = Map::new()
  let catalog = PdfCatalog::{ object_id, dict, pages_ref: object_id }
  assert_eq(catalog.object_id == object_id, true)
  assert_eq(catalog.dict.length(), 0)
  assert_eq(catalog.pages_ref == object_id, true)

  let rectangle = PdfRectangle::{ left: 0.0, bottom: 1.0, right: 2.0, top: 3.0 }
  assert_eq(rectangle.left, 0.0)
  assert_eq(rectangle.bottom, 1.0)
  assert_eq(rectangle.right, 2.0)
  assert_eq(rectangle.top, 3.0)

  let page_record = PageTreeRecord::{
    object_id,
    dict,
    index: 0,
    parent_ref: Some(object_id),
    ancestor_refs: [object_id],
  }
  assert_eq(page_record.object_id == object_id, true)
  assert_eq(page_record.dict.length(), 0)
  assert_eq(page_record.index, 0)
  match page_record.parent_ref {
    Some(parent_ref) => assert_eq(parent_ref == object_id, true)
    None => fail("expected parent reference")
  }
  assert_eq(page_record.ancestor_refs.length(), 1)
  assert_eq(page_record.ancestor_refs[0] == object_id, true)

  let page_index = PageTreeIndex::{ pages: [page_record] }
  assert_eq(page_index.pages.length(), 1)
  assert_eq(page_index.pages[0].index, 0)

  assert_eq(NameTreeCategory::Dests == NameTreeCategory::Dests, true)
  assert_eq(NameTreeCategory::AP == NameTreeCategory::AP, true)
  assert_eq(
    NameTreeCategory::JavaScript == NameTreeCategory::JavaScript,
    true,
  )
  assert_eq(NameTreeCategory::Pages == NameTreeCategory::Pages, true)
  assert_eq(NameTreeCategory::Templates == NameTreeCategory::Templates, true)
  assert_eq(
    NameTreeCategory::EmbeddedFiles == NameTreeCategory::EmbeddedFiles,
    true,
  )
  assert_eq(
    NameTreeCategory::AlternatePresentations ==
    NameTreeCategory::AlternatePresentations,
    true,
  )

  match PdfDocumentError::ReaderError(PdfReaderError::MissingTailMarker("EOF")) {
    ReaderError(error) => match error {
      MissingTailMarker(reason) => assert_eq(reason, "EOF")
      _ => fail("expected wrapped reader error")
    }
    _ => fail("expected reader error wrapper")
  }

  match PdfDocumentError::InvalidCatalog(object_id, "missing /Type /Catalog") {
    InvalidCatalog(actual_id, reason) => {
      assert_eq(actual_id == object_id, true)
      assert_eq(reason, "missing /Type /Catalog")
    }
    _ => fail("expected invalid catalog error")
  }

  match PdfDocumentError::InvalidPageTree(object_id, "bad /Kids entry") {
    InvalidPageTree(actual_id, reason) => {
      assert_eq(actual_id == object_id, true)
      assert_eq(reason, "bad /Kids entry")
    }
    _ => fail("expected invalid page tree error")
  }

  match PdfDocumentError::InvalidPage(object_id, "missing /MediaBox") {
    InvalidPage(actual_id, reason) => {
      assert_eq(actual_id == object_id, true)
      assert_eq(reason, "missing /MediaBox")
    }
    _ => fail("expected invalid page error")
  }

  match
    PdfDocumentError::InvalidInheritedAttribute(
      object_id,
      @objects.PdfName::new(b"Rotate"),
      "not a number",
    ) {
    InvalidInheritedAttribute(actual_id, name, reason) => {
      assert_eq(actual_id == object_id, true)
      assert_eq(name == @objects.PdfName::new(b"Rotate"), true)
      assert_eq(reason, "not a number")
    }
    _ => fail("expected invalid inherited attribute error")
  }

  match PdfDocumentError::InvalidNameTree(@objects.PdfName::new(b"Dests"), "bad leaf") {
    InvalidNameTree(name, reason) => {
      assert_eq(name == @objects.PdfName::new(b"Dests"), true)
      assert_eq(reason, "bad leaf")
    }
    _ => fail("expected invalid name tree error")
  }

  match PdfDocumentError::PageIndexOutOfRange(8, 2) {
    PageIndexOutOfRange(requested, count) => {
      assert_eq(requested, 8)
      assert_eq(count, 2)
    }
    _ => fail("expected page index out of range error")
  }

  match PdfDocumentError::CycleDetected(object_id, "parent chain") {
    CycleDetected(actual_id, reason) => {
      assert_eq(actual_id == object_id, true)
      assert_eq(reason, "parent chain")
    }
    _ => fail("expected cycle detected error")
  }
}
