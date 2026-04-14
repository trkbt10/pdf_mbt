///|
test "reader exposes metadata info file identifiers and piece info" {
  let document = PdfDocument::open(build_interchange_fixture())
  match document.metadata_stream() {
    Some(metadata) => assert_eq(metadata.xml, b"<x/>")
    None => fail("expected catalog metadata stream")
  }
  match document.document_info() {
    Some(info) => {
      assert_eq(info.title, Some(b"Doc"))
      assert_eq(info.trapped == @interchange.PdfTrappedStatus::False, true)
    }
    None => fail("expected trailer Info dictionary")
  }
  let sources = document.metadata_sources()
  assert_eq(sources.metadata_stream is Some(_), true)
  assert_eq(sources.document_info is Some(_), true)
  assert_eq(
    sources.diagnostics.creation_date ==
    @interchange.PdfMetadataDateComparison::OnlyInfo,
    true,
  )

  let current = document.raw_file_id_for_interchange_test()
  match current {
    Some(id) => {
      assert_eq(id.first, b"original-id")
      assert_eq(
        id.compare_reference(PdfFileId::{
          first: b"original-id",
          second: b"old-version",
        }) ==
        @interchange.PdfFileIdMatch::SameOriginalDifferentVersion,
        true,
      )
    }
    None => fail("expected trailer ID")
  }

  match document.piece_info() {
    Some(piece_info) => {
      assert_eq(piece_info.entries.length(), 1)
      assert_eq(piece_info.entries[0].last_modified, b"D:20260414")
    }
    None => fail("expected catalog PieceInfo")
  }
  match document.page(0).piece_info() {
    Some(piece_info) => {
      assert_eq(piece_info.entries.length(), 1)
      assert_eq(piece_info.entries[0].last_modified, b"D:20260415")
    }
    None => fail("expected page PieceInfo")
  }
}

///|
test "reader wraps malformed interchange validation" {
  let document = PdfDocument::open(build_interchange_fixture_with_bad_info())
  let result : Result[@interchange.PdfDocumentInfo?, PdfDocumentError] = try? document.document_info()
  match result {
    Err(
      InterchangeError(
        @interchange.PdfInterchangeError::InvalidDocumentInfo(_, reason)
      )
    ) => assert_eq(reason.contains("Title"), true)
    _ => fail("expected document info interchange error")
  }
}

///|
fn PdfDocument::raw_file_id_for_interchange_test(
  self : PdfDocument,
) -> PdfFileId? {
  self.file.file_id()
}

///|
fn build_interchange_fixture() -> Bytes {
  build_interchange_fixture_impl(false)
}

///|
fn build_interchange_fixture_with_bad_info() -> Bytes {
  build_interchange_fixture_impl(true)
}

///|
fn build_interchange_fixture_impl(bad_info : Bool) -> Bytes {
  let prefix = b"fixture\n"
  let header = b"%PDF-2.0\r\n%\x80\x80\x80\x80\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R /Metadata 5 0 R /PieceInfo 7 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 1 1] /PieceInfo 8 0 R >>",
  )
  let info_body = if bad_info {
    b"<< /Title /Bad /CreationDate (D:0001) >>"
  } else {
    b"<< /Title (Doc) /CreationDate (D:0001) /ModDate (D:0002) /Trapped /False >>"
  }
  let (bytes, info_offset) = append_indirect_object(
    bytes, header_base, 4, 0, info_body,
  )
  let (bytes, metadata_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    build_stream_object_body(
      b"<< /Type /Metadata /Subtype /XML /Length 4 >>", b"<x/>",
    ),
  )
  let (bytes, catalog_piece_offset) = append_indirect_object(
    bytes, header_base, 7, 0, b"<< /Producer << /LastModified (D:20260414) /Private 42 >> >>",
  )
  let (bytes, page_piece_offset) = append_indirect_object(
    bytes, header_base, 8, 0, b"<< /PageTool << /LastModified (D:20260415) /Private [1] >> >>",
  )

  let xref_offset = object_offset(bytes, header_base)
  bytes +
  b"xref\r\n" +
  b"0 9\r\n" +
  xref_entry_line(0L, 65535, b'f') +
  xref_entry_line(catalog_offset, 0, b'n') +
  xref_entry_line(pages_offset, 0, b'n') +
  xref_entry_line(page_offset, 0, b'n') +
  xref_entry_line(info_offset, 0, b'n') +
  xref_entry_line(metadata_offset, 0, b'n') +
  xref_entry_line(0L, 1, b'f') +
  xref_entry_line(catalog_piece_offset, 0, b'n') +
  xref_entry_line(page_piece_offset, 0, b'n') +
  b"trailer\r\n" +
  b"<< /Size 9 /Root 1 0 R /Info 4 0 R /ID [(original-id)(current-id)] >>\r\n" +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
