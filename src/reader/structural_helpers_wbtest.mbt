///|
test "structural helpers raise domain diagnostics" {
  let owner = Some(oid(42))
  let bad_name : Result[@objects.PdfName, PdfDocumentError] = try? structural_name(
    @objects.PdfObject::Integer(7L),
    StructuralDomain::Form,
    owner,
    "field FT",
  )
  match bad_name {
    Err(InvalidForm(object_id, reason)) => {
      assert_eq(object_id == owner, true)
      assert_eq(reason, "field FT must be a name")
    }
    _ => fail("expected InvalidForm from malformed form name")
  }

  let bad_array : Result[Array[@objects.PdfObject], PdfDocumentError] = try? structural_array(
    @objects.PdfObject::Name(structural_key(b"Sig")),
    StructuralDomain::Signature,
    owner,
    "ByteRange",
  )
  match bad_array {
    Err(InvalidSignature(object_id, reason)) => {
      assert_eq(object_id == owner, true)
      assert_eq(reason, "ByteRange must be an array")
    }
    _ => fail("expected InvalidSignature from malformed byte range")
  }

  let bad_direct : Result[Unit, PdfDocumentError] = try? require_structural_direct_object(
    @objects.PdfObject::Ref(oid(9)),
    StructuralDomain::Requirement,
    owner,
    "requirement dictionary",
  )
  match bad_direct {
    Err(InvalidRequirement(object_id, reason)) => {
      assert_eq(object_id == owner, true)
      assert_eq(reason, "requirement dictionary must be a direct object")
    }
    _ => fail("expected InvalidRequirement for indirect direct-only value")
  }
}

///|
test "structural helper resolution tracks cycles by domain" {
  let file = PdfFile::open(build_structural_helper_cycle_fixture())
  let resolved = resolve_structural_dictionary(
    file,
    @objects.PdfObject::Ref(oid(4)),
    StructuralDomain::Measure,
    "Measure",
  )
  match resolved {
    (Some(object_id), dict) => {
      assert_eq(object_id == oid(4), true)
      assert_eq(
        dict.get(structural_key(b"Type")) ==
        Some(@objects.PdfObject::Name(structural_key(b"Measure"))),
        true,
      )
    }
    _ => fail("expected resolved measure dictionary")
  }

  let cycle_result : Result[
    (@objects.ObjectId?, @objects.PdfDictionary),
    PdfDocumentError,
  ] = try? resolve_structural_dictionary(
    file,
    @objects.PdfObject::Ref(oid(5)),
    StructuralDomain::FDF,
    "FDF dictionary",
  )
  match cycle_result {
    Err(InvalidFDF(object_id, reason)) => {
      assert_eq(object_id == Some(oid(5)), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected InvalidFDF cycle diagnostic")
  }
}

///|
fn build_structural_helper_cycle_fixture() -> Bytes {
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
  let (bytes, measure_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Measure /Subtype /RL >>",
  )
  let (bytes, cycle_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"5 0 R",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 6\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(measure_offset, 0, b'n') +
  xref_entry_line(cycle_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 6 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
