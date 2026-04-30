///|
test "form field values flatten AcroForm hierarchy and field states" {
  let document = PdfDocument::open(build_form_values_fixture())
  let values = document.form_field_values()

  assert_eq(values.length(), 6)
  assert_eq(values.get("person.name"), Some("Alice"))
  assert_eq(values.get("person.city"), Some("Tokyo"))
  assert_eq(values.get("colors"), Some("Red,Blue"))
  assert_eq(values.get("agree"), Some("Yes"))
  assert_eq(values.get("newsletter"), Some("Off"))
  assert_eq(values.get("sig1"), Some("signed"))
}

///|
test "form field values are empty when AcroForm is absent" {
  let document = PdfDocument::open(
    build_document_structure_single_page_fixture(),
  )
  let values = document.form_field_values()
  assert_eq(values.length(), 0)
}

///|
test "acro form exposes document metadata and root fields" {
  let document = PdfDocument::open(build_form_values_fixture())
  let acro_form = document.acro_form().unwrap()

  assert_eq(acro_form.root_fields.length(), 5)
  assert_eq(acro_form.root_fields[0].partial_name, Some(b"person"))
  assert_eq(acro_form.root_fields[0].field_type == PdfFormFieldType::Text, true)
  assert_eq(acro_form.root_fields[0].kids.length(), 2)
  assert_eq(
    acro_form.root_fields[3].field_type == PdfFormFieldType::Button,
    true,
  )
  assert_eq(acro_form.need_appearances, Some(false))
  assert_eq(acro_form.signature_flags, Some(3))
  assert_eq(acro_form.default_appearance, Some(b"/Helv 10 Tf 0 g"))
  assert_eq(acro_form.quadding, Some(1))
}

///|
test "acro form is absent when Catalog AcroForm is absent" {
  let document = PdfDocument::open(
    build_document_structure_single_page_fixture(),
  )
  assert_eq(document.acro_form() is None, true)
}

///|
test "typed form fields flatten hierarchy and support qualified lookup" {
  let document = PdfDocument::open(build_form_values_fixture())
  let fields = document.form_fields()
  let city = document.form_field_by_name(b"person.city").unwrap()

  assert_eq(fields.length(), 8)
  assert_eq(city.partial_name, Some(b"city"))
  assert_eq(city.fully_qualified_name, Some(b"person.city"))
  assert_eq(city.parent == Some(oid(5)), true)
  assert_eq(city.field_type == PdfFormFieldType::Text, true)
  assert_eq(document.form_field_by_name(b"missing") is None, true)
}

///|
test "variable text descriptor preserves appearance metadata" {
  let document = PdfDocument::open(build_form_values_fixture())
  let name = document.form_field_by_name(b"person.name").unwrap()
  let variable_text = name.variable_text.unwrap()

  assert_eq(variable_text.default_appearance, Some(b"/Helv 11 Tf 0 g"))
  assert_eq(variable_text.quadding, Some(2))
  assert_eq(variable_text.default_style, Some(b"font: Helvetica"))
  assert_eq(variable_text.rich_text is Some(_), true)
}

///|
test "typed form fields reject invalid partial names" {
  let document = PdfDocument::open(build_form_invalid_name_fixture())
  let result : Result[Array[PdfFormField], PdfDocumentError] = try? document.form_fields()
  match result {
    Err(InvalidForm(object_id, reason)) => {
      assert_eq(object_id == Some(oid(5)), true)
      assert_eq(reason.contains("PERIOD"), true)
    }
    _ => fail("expected InvalidForm for invalid partial name")
  }
}

///|
test "form field traversal rejects field tree cycles" {
  let document = PdfDocument::open(build_form_values_cycle_fixture())
  let result : Result[Map[String, String], PdfDocumentError] = try? document.form_field_values()
  match result {
    Err(InvalidForm(object_id, reason)) => {
      assert_eq(object_id == Some(oid(5)), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected InvalidForm cycle")
  }
}

///|
fn build_form_values_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /AcroForm 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
  )
  let (bytes, acroform_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Fields [5 0 R 8 0 R 9 0 R 10 0 R 12 0 R] /NeedAppearances false /SigFlags 3 /DA (/Helv 10 Tf 0 g) /Q 1 >>",
  )
  let (bytes, parent_text_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /FT /Tx /T (person) /Kids [6 0 R 7 0 R] >>",
  )
  let (bytes, name_offset) = append_indirect_object(
    bytes, header_base, 6, 0, b"<< /T (name) /V (Alice) /DA (/Helv 11 Tf 0 g) /Q 2 /DS (font: Helvetica) /RV (rich) >>",
  )
  let (bytes, city_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /T (city) /V (Tokyo) >>",
  )
  let (bytes, choice_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"<< /FT /Ch /T (colors) /V [(Red) (Blue)] >>",
  )
  let (bytes, checked_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"<< /FT /Btn /T (agree) /V /Yes >>",
  )
  let (bytes, button_parent_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"<< /FT /Btn /T (newsletter) /Kids [11 0 R] >>",
  )
  let (bytes, button_widget_offset) = append_indirect_object(
    bytes, header_base, 11, 0, b"<< /Subtype /Widget /AS /Off >>",
  )
  let (bytes, signature_offset) = append_indirect_object(
    bytes, header_base, 12, 0, b"<< /FT /Sig /T (sig1) /V << /Type /Sig >> >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 13\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(acroform_offset, 0, b'n') +
  xref_entry_line(parent_text_offset, 0, b'n') +
  xref_entry_line(name_offset, 0, b'n') +
  xref_entry_line(city_offset, 0, b'n') +
  xref_entry_line(choice_offset, 0, b'n') +
  xref_entry_line(checked_offset, 0, b'n') +
  xref_entry_line(button_parent_offset, 0, b'n') +
  xref_entry_line(button_widget_offset, 0, b'n') +
  xref_entry_line(signature_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 13 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_form_invalid_name_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /AcroForm 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
  )
  let (bytes, acroform_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Fields [5 0 R] >>",
  )
  let (bytes, field_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /FT /Tx /T (bad.name) /V (x) >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 6\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(acroform_offset, 0, b'n') +
  xref_entry_line(field_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 6 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn build_form_values_cycle_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /AcroForm 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
  )
  let (bytes, acroform_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Fields [5 0 R] >>",
  )
  let (bytes, field_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /FT /Tx /T (loop) /Kids [5 0 R] >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 6\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(acroform_offset, 0, b'n') +
  xref_entry_line(field_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 6 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
