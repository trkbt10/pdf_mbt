///|
fn multimedia_fixture_dictionary() -> @objects.PdfDictionary {
  Map::new()
}

///|
fn multimedia_fixture_name_object(bytes : Bytes) -> @objects.PdfObject {
  @objects.PdfObject::Name(multimedia_key(bytes))
}

///|
fn multimedia_fixture_ref(object_number : Int) -> @objects.PdfObject {
  @objects.PdfObject::Ref(oid(object_number))
}

///|
fn multimedia_fixture_array(
  values : Array[@objects.PdfObject],
) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn multimedia_fixture_stream(
  dict : @objects.PdfDictionary,
  data : Bytes,
) -> @objects.PdfStream {
  @objects.PdfStream::{ dict, data }
}

///|
fn multimedia_fixture_annotation_shell(
  subtype : @objects.PdfName,
  action : @objects.PdfObject?,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[multimedia_key(b"Type")] = multimedia_fixture_name_object(b"Annot")
  dict[multimedia_key(b"Subtype")] = @objects.PdfObject::Name(subtype)
  if action is Some(value) {
    dict[multimedia_key(b"A")] = value
  }
  dict
}

///|
fn multimedia_fixture_name_tree_entry(
  key : Bytes,
  value : @objects.PdfObject,
) -> PdfNameTreeEntry {
  PdfNameTreeEntry::{ key, value }
}

///|
fn multimedia_fixture_rendition_action_payload(
  rendition : @objects.PdfObject,
  annotation : @objects.PdfObject,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[multimedia_key(b"S")] = multimedia_fixture_name_object(b"Rendition")
  dict[multimedia_key(b"OP")] = @objects.PdfObject::Integer(0L)
  dict[multimedia_key(b"R")] = rendition
  dict[multimedia_key(b"AN")] = annotation
  dict
}

///|
fn build_multimedia_common_fixture() -> Bytes {
  let (bytes, header_base) = build_document_structure_fixture_prefix()

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names << /AlternatePresentations 10 0 R >> >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Annots [9 0 R] >>",
  )
  let (bytes, rendition_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /Type /Rendition /S /MR /N (clip) /MH 5 0 R /BE << /P true >> /Z (opaque) >>",
  )
  let (bytes, policy_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /C true /Unknown /Future >>",
  )
  let stream_body = build_stream_object_body(
    b"<< /Type /EmbeddedFile /Length 10 >>", b"media-data",
  )
  let (bytes, stream_offset) = append_indirect_object(
    bytes, header_base, 6, 0, stream_body,
  )
  let (bytes, bad_policy_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /Type /Rendition /S /MR /MH /Bad >>",
  )
  let (bytes, cycle_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"8 0 R",
  )
  let (bytes, annotation_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"<< /Type /Annot /Subtype /Screen /A << /S /Rendition /OP 0 /R 4 0 R /AN 9 0 R >> >>",
  )
  let (bytes, name_tree_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"<< /Names [(clip) 4 0 R] >>",
  )
  let (bytes, bad_required_offset) = append_indirect_object(
    bytes, header_base, 11, 0, b"<< /Type /Rendition /S 1 >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 12\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(rendition_offset, 0, b'n') +
  xref_entry_line(policy_offset, 0, b'n') +
  xref_entry_line(stream_offset, 0, b'n') +
  xref_entry_line(bad_policy_offset, 0, b'n') +
  xref_entry_line(cycle_offset, 0, b'n') +
  xref_entry_line(annotation_offset, 0, b'n') +
  xref_entry_line(name_tree_offset, 0, b'n') +
  xref_entry_line(bad_required_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 12 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
