///|
fn build_file_spec_embedded_fixture() -> Bytes {
  let prefix = b"filespec\n"
  let header = b"%PDF-2.0\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Names 4 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let (bytes, names_offset) = append_indirect_object(
    bytes, header_base, 4, 0, b"<< /EmbeddedFiles 5 0 R >>",
  )
  let (bytes, embedded_tree_offset) = append_indirect_object(
    bytes, header_base, 5, 0, b"<< /Names [(attach-a) 6 0 R (attach-b) 10 0 R] >>",
  )
  let full_spec = b"<< /Type /Filespec /F (fallback.bin) /UF (selected.bin) /Desc (desc) /AFRelationship /Data /EF << /F 7 0 R /UF 8 0 R >> /RF << /UF 9 0 R >> /CI 12 0 R /Thumb 13 0 R /EP << /Subtype /EncryptedPayload >> >>"
  let (bytes, file_spec_offset) = append_indirect_object(
    bytes, header_base, 6, 0, full_spec,
  )
  let primary_stream = build_stream_object_body(
    b"<< /Type /EmbeddedFile /Subtype /application#2Foctet-stream /Params << /Size 4 /CreationDate (D:20200101000000Z) /ModDate (D:20200102000000Z) /Mac << /Creator (tt) >> /CheckSum (1234567890abcdef) >> /Length 4 >>",
    b"DATA",
  )
  let (bytes, primary_offset) = append_indirect_object(
    bytes, header_base, 7, 0, primary_stream,
  )
  let selected_stream = build_stream_object_body(
    b"<< /Type /EmbeddedFile /Length 3 >>", b"UFD",
  )
  let (bytes, selected_offset) = append_indirect_object(
    bytes, header_base, 8, 0, selected_stream,
  )
  let (bytes, related_array_offset) = append_indirect_object(
    bytes, header_base, 9, 0, b"[(related.bin) 11 0 R]",
  )
  let (bytes, simple_spec_offset) = append_indirect_object(
    bytes, header_base, 10, 0, b"(simple/path.bin)",
  )
  let related_stream = build_stream_object_body(
    b"<< /Type /EmbeddedFile /Length 3 >>", b"REL",
  )
  let (bytes, related_offset) = append_indirect_object(
    bytes, header_base, 11, 0, related_stream,
  )
  let (bytes, collection_item_offset) = append_indirect_object(
    bytes, header_base, 12, 0, b"<< /Type /CollectionItem /Field (raw) >>",
  )
  let thumb_stream = build_stream_object_body(b"<< /Length 2 >>", b"TH")
  let (bytes, thumb_offset) = append_indirect_object(
    bytes, header_base, 13, 0, thumb_stream,
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 14\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(names_offset, 0, b'n') +
  xref_entry_line(embedded_tree_offset, 0, b'n') +
  xref_entry_line(file_spec_offset, 0, b'n') +
  xref_entry_line(primary_offset, 0, b'n') +
  xref_entry_line(selected_offset, 0, b'n') +
  xref_entry_line(related_array_offset, 0, b'n') +
  xref_entry_line(simple_spec_offset, 0, b'n') +
  xref_entry_line(related_offset, 0, b'n') +
  xref_entry_line(collection_item_offset, 0, b'n') +
  xref_entry_line(thumb_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 14 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
