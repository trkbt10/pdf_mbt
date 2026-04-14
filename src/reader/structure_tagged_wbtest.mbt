///|
test "structure mark information uses ISO defaults and validates present flags" {
  let unmarked = PdfDocument::open(
    build_document_structure_single_page_fixture(),
  )
  let defaults = unmarked.mark_info()
  assert_eq(defaults.marked, false)
  assert_eq(defaults.user_properties, false)
  assert_eq(defaults.suspects, false)
  assert_eq(defaults.raw_dict is None, true)
  assert_eq(unmarked.document_language() is None, true)

  let tagged = PdfDocument::open(build_structure_tagged_fixture())
  let mark_info = tagged.mark_info()
  assert_eq(mark_info.marked, true)
  assert_eq(mark_info.user_properties, false)
  assert_eq(mark_info.suspects, true)
  assert_eq(mark_info.raw_dict is Some(_), true)
  assert_eq(tagged.document_language() == Some(b"en-US"), true)

  let bad = PdfDocument::open(build_structure_bad_mark_info_fixture())
  let result : Result[PdfMarkInfo, PdfDocumentError] = try? bad.mark_info()
  match result {
    Err(InvalidStructure(_, reason)) =>
      assert_eq(reason.contains("boolean"), true)
    _ => fail("expected malformed MarkInfo flag to fail")
  }
}

///|
test "structure tree parses logical order children identifiers and parent tree" {
  let document = PdfDocument::open(build_structure_tagged_fixture())
  let tree = match document.structure_tree() {
    Some(value) => value
    None => fail("expected structure tree")
  }

  assert_eq(tree.root_object_id == Some(oid(4)), true)
  assert_eq(tree.root_children.length(), 1)
  assert_eq(tree.elements().length(), 2)
  assert_eq(tree.parent_tree_next_key == Some(10), true)
  assert_eq(tree.id_tree_entries.length(), 2)
  assert_eq(tree.parent_tree_entries.length(), 2)

  let root_element = tree.elements()[0]
  assert_eq(root_element.object_id == Some(oid(5)), true)
  assert_eq(root_element.parent == PdfStructureParent::Root, true)
  assert_eq(root_element.children.length(), 4)
  match root_element.children[0] {
    PdfStructureChild::Content(PdfStructureContentItem::MCID(mcid)) => {
      assert_eq(mcid.mcid, 0)
      assert_eq(mcid.page_ref == Some(oid(3)), true)
    }
    _ => fail("expected MCID child")
  }
  match root_element.children[1] {
    PdfStructureChild::Element(index, object_id) => {
      assert_eq(index, 1)
      assert_eq(object_id == Some(oid(6)), true)
    }
    _ => fail("expected child structure element")
  }
  match root_element.children[2] {
    PdfStructureChild::Content(PdfStructureContentItem::MCR(reference)) => {
      assert_eq(reference.mcid, 1)
      assert_eq(reference.page_ref == Some(oid(3)), true)
    }
    _ => fail("expected MCR child")
  }
  match root_element.children[3] {
    PdfStructureChild::Content(PdfStructureContentItem::OBJR(reference)) => {
      assert_eq(reference.object_ref == oid(9), true)
      assert_eq(reference.page_ref == Some(oid(3)), true)
    }
    _ => fail("expected OBJR child")
  }

  match tree.element_by_id(b"child-id") {
    Some(element) => assert_eq(element.object_id == Some(oid(6)), true)
    None => fail("expected child ID lookup")
  }
  assert_eq(tree.element_by_id(b"child-id\x00") is None, true)

  match tree.parent_for_mcid(7, 1) {
    Some(parent) => {
      assert_eq(parent.element_index == Some(1), true)
      assert_eq(parent.element_ref == Some(oid(6)), true)
    }
    None => fail("expected parent tree MCID lookup")
  }
  match tree.parent_for_object(9) {
    Some(parent) => {
      assert_eq(parent.element_index == Some(1), true)
      assert_eq(parent.element_ref == Some(oid(6)), true)
    }
    None => fail("expected parent tree object lookup")
  }
}

///|
test "structure roles namespaces attributes and accessibility are inspectable" {
  let document = PdfDocument::open(build_structure_tagged_fixture())
  let tree = match document.structure_tree() {
    Some(value) => value
    None => fail("expected structure tree")
  }
  let root_element = tree.elements()[0]
  let child = tree.elements()[1]

  let resolved_root = tree.resolve_structure_type(root_element)
  assert_eq(resolved_root.chain.length(), 2)
  assert_eq(resolved_root.standard_target is Some(_), true)
  match resolved_root.standard_target {
    Some(standard) =>
      assert_eq(standard.category == PdfStandardStructureCategory::Figure, true)
    None => fail("expected mapped Figure role")
  }

  let resolved_child = tree.resolve_structure_type(child)
  assert_eq(resolved_child.chain.length(), 2)
  match resolved_child.standard_target {
    Some(standard) =>
      assert_eq(standard.name == @objects.PdfName::new(b"Div"), true)
    None => fail("expected root RoleMap to remap /P before standard lookup")
  }

  let namespaces = tree.namespaces()
  assert_eq(namespaces.length(), 1)
  assert_eq(namespaces[0].name == Some(b"http://example.test/ns"), true)
  assert_eq(namespaces[0].role_map.length(), 1)

  let user_properties = root_element.user_properties()
  assert_eq(user_properties.length(), 1)
  assert_eq(user_properties[0].name == b"rating", true)
  assert_eq(user_properties[0].hidden, true)

  let resolved_attributes = tree.resolved_attributes(root_element)
  assert_eq(resolved_attributes.length(), 1)
  assert_eq(
    resolved_attributes[0].key == @objects.PdfName::new(b"TextDecorationType"),
    true,
  )
  assert_eq(
    resolved_attributes[0].source ==
    PdfStructureAttributeSourceKind::ClassMap(b"emphasis"),
    true,
  )

  let accessibility = child.accessibility_properties()
  assert_eq(accessibility.expansion_text == Some(b"expansion"), true)
  assert_eq(accessibility.phoneme == Some(b"fone"), true)
  assert_eq(
    accessibility.phonetic_alphabet == Some(@objects.PdfName::new(b"ipa")),
    true,
  )

  let effective = tree.effective_language(child)
  assert_eq(effective.language == Some(b"fr-FR"), true)
  assert_eq(
    effective.source == PdfEffectiveLanguageSource::Element(Some(oid(5))),
    true,
  )
}

///|
test "structure reports separate hard diagnostics warnings and unchecked items" {
  let document = PdfDocument::open(build_structure_tagged_fixture())
  let tree = match document.structure_tree() {
    Some(value) => value
    None => fail("expected structure tree")
  }

  let content_report = document.structure_content_report()
  assert_eq(content_report.diagnostics.length(), 0)
  assert_eq(content_report.unchecked.length() > 0, true)

  let report = tree.tagged_pdf_report()
  assert_eq(report.is_marked, true)
  assert_eq(report.has_structure_tree, true)
  assert_eq(report.errors.length(), 0)
  assert_eq(report.warnings.length() > 0, true)
  assert_eq(report.unchecked.length() > 0, true)

  let missing_tree = PdfDocument::open(build_structure_no_tree_tagged_fixture())
  let missing_report = missing_tree.tagged_pdf_report()
  assert_eq(missing_report.has_structure_tree, false)
  assert_eq(missing_report.errors.length(), 1)
  assert_eq(
    missing_report.errors[0].code ==
    @objects.PdfName::new(b"MissingStructureTree"),
    true,
  )
}

///|
test "structure traversal rejects indirect element cycles" {
  let document = PdfDocument::open(build_structure_cycle_fixture())
  let result : Result[PdfStructureTree?, PdfDocumentError] = try? document.structure_tree()
  match result {
    Err(CycleDetected(object_id, reason)) => {
      assert_eq(object_id == oid(5), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected structure element cycle")
  }
}
