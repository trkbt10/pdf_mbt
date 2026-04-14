///|
fn build_structure_tagged_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Lang (en-US) /MarkInfo << /Marked true /UserProperties false /Suspects true >> /StructTreeRoot 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /StructParents 7 >>",
  )
  let (bytes, root_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /StructTreeRoot /K [5 0 R] /RoleMap << /CustomFigure /Figure /P /Div >> /ClassMap << /emphasis << /O /Layout /TextDecorationType /Underline >> >> /Namespaces [8 0 R] /ParentTree << /Nums [7 [5 0 R 6 0 R] 9 6 0 R] >> /ParentTreeNextKey 10 /IDTree << /Names [(root-id) 5 0 R (child-id) 6 0 R] >> >>",
  )
  let (bytes, parent_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /StructElem /S /CustomFigure /P 4 0 R /ID (root-id) /Pg 3 0 R /Lang (fr-FR) /Alt (diagram) /ActualText (diagram text) /A << /O /UserProperties /P [<< /N (rating) /V 5 /F (five) /H true >>] >> /C /emphasis /K [0 6 0 R << /Type /MCR /Pg 3 0 R /MCID 1 >> << /Type /OBJR /Obj 9 0 R /Pg 3 0 R >>] >>",
  )
  let (bytes, child_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /Type /StructElem /S /P /P 5 0 R /ID (child-id) /E (expansion) /Phoneme (fone) /K 2 >>",
  )
  let (bytes, unused_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"(unused)",
  )
  let (bytes, namespace_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"<< /Type /Namespace /NS (http://example.test/ns) /RoleMapNS << /Special [/P 8 0 R] >> >>",
  )
  let (bytes, annotation_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"<< /Subtype /Link /Rect [0 0 10 10] >>",
  )

  finish_structure_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, root_offset, parent_offset, child_offset,
    unused_offset, namespace_offset, annotation_offset,
  ])
}

///|
fn build_structure_bad_mark_info_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /MarkInfo << /Marked /yes >> >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  finish_structure_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset,
  ])
}

///|
fn build_structure_no_tree_tagged_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /MarkInfo << /Marked true >> >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  finish_structure_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset,
  ])
}

///|
fn build_structure_cycle_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()
  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /MarkInfo << /Marked true >> /StructTreeRoot 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, root_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /StructTreeRoot /K [5 0 R] >>",
  )
  let (bytes, element_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Type /StructElem /S /Document /P 4 0 R /K [5 0 R] >>",
  )
  finish_structure_fixture(bytes, header_base, [
    catalog_offset, pages_offset, page_offset, root_offset, element_offset,
  ])
}

///|
fn finish_structure_fixture(
  bytes : Bytes,
  header_base : Int64,
  offsets : Array[Int64],
) -> Bytes {
  let xref_offset = object_offset(bytes, header_base)
  let mut out = bytes +
    b"xref\r\n" +
    b"0 " +
    decimal_bytes((offsets.length() + 1).to_int64()) +
    b"\r\n" +
    xref_entry_line(0L, 65535, b'f')
  for offset in offsets {
    out = out + xref_entry_line(offset, 0, b'n')
  }
  out +
  b"trailer\r\n" +
  b"<< /Size " +
  decimal_bytes((offsets.length() + 1).to_int64()) +
  b" /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
