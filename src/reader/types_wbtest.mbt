///|
test "reader metadata contracts are constructible" {
  let file_id = PdfFileId::{ first: b"doc-a-0001", second: b"doc-a-0002" }
  let header = PdfHeader::{
    version: PdfVersion::{ major: 2, minor: 0 },
    base_offset: 7L,
    has_binary_indicator: true,
  }
  let raw_dict : @objects.PdfDictionary = Map::new()
  let trailer = TrailerInfo::{
    size: 8,
    root: @objects.ObjectId::{ object_number: 1, generation_number: 0 },
    prev: Some(1024L),
    encrypt: Some(@objects.ObjectId::{ object_number: 9, generation_number: 0 }),
    info: Some(@objects.ObjectId::{ object_number: 10, generation_number: 0 }),
    id: Some(file_id),
    xref_stm: Some(4096L),
    raw_dict,
  }
  let section = XrefSection::{
    provenance: XrefSectionProvenance::{
      source: XrefSectionSource::Table,
      pdf_offset: 2048L,
    },
    entries: [
      XrefSectionEntry::{ object_number: 0, entry: XrefEntry::Free(0, 65535) },
      XrefSectionEntry::{ object_number: 1, entry: XrefEntry::InUse(256L, 0) },
      XrefSectionEntry::{ object_number: 2, entry: XrefEntry::Compressed(3, 4) },
    ],
    trailer,
  }
  let xref_index : XrefIndex = Map::new()
  let file = PdfFile::{
    bytes: b"%PDF-2.0\r\n",
    header,
    trailer,
    sections: [section],
    xref_index,
    encryption: None,
    cache: Map::new(),
    object_stream_tables: Map::new(),
  }

  assert_eq(file.header.version == PdfVersion::{ major: 2, minor: 0 }, true)
  assert_eq(file.header.base_offset, 7L)
  assert_eq(file.header.has_binary_indicator, true)
  assert_eq(file.trailer.size, 8)
  assert_eq(
    file.trailer.root ==
    @objects.ObjectId::{ object_number: 1, generation_number: 0 },
    true,
  )
  match file.trailer.prev {
    Some(prev) => assert_eq(prev, 1024L)
    None => fail("expected prev entry")
  }
  match file.trailer.encrypt {
    Some(encrypt) =>
      assert_eq(
        encrypt == @objects.ObjectId::{ object_number: 9, generation_number: 0 },
        true,
      )
    None => fail("expected encrypt entry")
  }
  match file.trailer.info {
    Some(info) =>
      assert_eq(
        info == @objects.ObjectId::{ object_number: 10, generation_number: 0 },
        true,
      )
    None => fail("expected info entry")
  }
  match file.trailer.id {
    Some(actual_id) => assert_eq(actual_id == file_id, true)
    None => fail("expected file identifier")
  }
  match file.trailer.xref_stm {
    Some(xref_stm) => assert_eq(xref_stm, 4096L)
    None => fail("expected xref stm entry")
  }
  assert_eq(file.sections.length(), 1)
  assert_eq(
    file.sections[0].provenance.source == XrefSectionSource::Table,
    true,
  )
  assert_eq(file.sections[0].provenance.pdf_offset, 2048L)
  assert_eq(file.sections[0].entries.length(), 3)
  match file.sections[0].entries[0].entry {
    Free(next_free_object_number, generation_number) => {
      assert_eq(next_free_object_number, 0)
      assert_eq(generation_number, 65535)
    }
    _ => fail("expected free xref entry")
  }
  match file.sections[0].entries[1].entry {
    InUse(pdf_offset, generation_number) => {
      assert_eq(pdf_offset, 256L)
      assert_eq(generation_number, 0)
    }
    _ => fail("expected in-use xref entry")
  }
  match file.sections[0].entries[2].entry {
    Compressed(object_stream_number, index) => {
      assert_eq(object_stream_number, 3)
      assert_eq(index, 4)
    }
    _ => fail("expected compressed xref entry")
  }
  assert_eq(file.bytes, b"%PDF-2.0\r\n")
  assert_eq(file.xref_index.length(), 0)
  assert_eq(file.cache.length(), 0)
  assert_eq(file.object_stream_tables.length(), 0)
}

///|
test "reader diagnostics preserve offsets and wrapped parser errors" {
  let object_id = @objects.ObjectId::{ object_number: 42, generation_number: 7 }
  let parse_error = @objects.PdfParseError::InvalidDictionary(
    33L, "dictionary key must be a name",
  )

  match PdfReaderError::InvalidHeader(12L, "missing EOL") {
    InvalidHeader(offset, reason) => {
      assert_eq(offset, 12L)
      assert_eq(reason, "missing EOL")
    }
    _ => fail("expected invalid header error")
  }
  match PdfReaderError::MissingTailMarker("%%EOF not found") {
    MissingTailMarker(reason) => assert_eq(reason, "%%EOF not found")
    _ => fail("expected missing tail marker error")
  }
  match PdfReaderError::InvalidXref(88L, "xref entry width") {
    InvalidXref(offset, reason) => {
      assert_eq(offset, 88L)
      assert_eq(reason, "xref entry width")
    }
    _ => fail("expected invalid xref error")
  }
  match PdfReaderError::InvalidTrailer(91L, "Size must be integer") {
    InvalidTrailer(offset, reason) => {
      assert_eq(offset, 91L)
      assert_eq(reason, "Size must be integer")
    }
    _ => fail("expected invalid trailer error")
  }
  match PdfReaderError::InvalidObjectStream(77L, "missing First") {
    InvalidObjectStream(offset, reason) => {
      assert_eq(offset, 77L)
      assert_eq(reason, "missing First")
    }
    _ => fail("expected invalid object stream error")
  }
  match
    PdfReaderError::InvalidObjectLocation(object_id, "generation mismatch") {
    InvalidObjectLocation(actual_id, reason) => {
      assert_eq(actual_id == object_id, true)
      assert_eq(reason, "generation mismatch")
    }
    _ => fail("expected invalid object location error")
  }
  match PdfReaderError::UnsupportedFilter(55L, "Crypt") {
    UnsupportedFilter(offset, reason) => {
      assert_eq(offset, 55L)
      assert_eq(reason, "Crypt")
    }
    _ => fail("expected unsupported filter error")
  }
  match
    PdfReaderError::DecodeStreamError(
      56L,
      @filters.PdfFilterError::UnsupportedFilter("DCTDecode"),
    ) {
    DecodeStreamError(offset, error) => {
      assert_eq(offset, 56L)
      match error {
        UnsupportedFilter(filter_name) => assert_eq(filter_name, "DCTDecode")
        _ => fail("expected wrapped filter error")
      }
    }
    _ => fail("expected wrapped filter decode error")
  }
  match PdfReaderError::PrevChainCycle(144L) {
    PrevChainCycle(offset) => assert_eq(offset, 144L)
    _ => fail("expected prev cycle error")
  }
  match PdfReaderError::ParseObjectError(4096L, parse_error) {
    ParseObjectError(offset, wrapped) => {
      assert_eq(offset, 4096L)
      assert_eq(wrapped == parse_error, true)
    }
    _ => fail("expected parse object error")
  }
}
