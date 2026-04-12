///|
fn read_section_chain(
  source : ByteSource,
  latest_startxref : Int64,
  version : PdfVersion,
) -> Array[XrefSection] raise PdfReaderError {
  let sections : Array[XrefSection] = []
  let visited : Map[Int64, Bool] = Map::new()
  read_section_chain_from_offset(
    source, latest_startxref, version, visited, sections, true,
  )
  sections
}

///|
fn read_section_chain_from_offset(
  source : ByteSource,
  pdf_offset : Int64,
  version : PdfVersion,
  visited : Map[Int64, Bool],
  sections : Array[XrefSection],
  follow_prev : Bool,
) -> Unit raise PdfReaderError {
  if visited.contains(pdf_offset) {
    raise PdfReaderError::PrevChainCycle(pdf_offset)
  }

  visited[pdf_offset] = true
  let section = read_xref_section_at_offset(source, pdf_offset, version)
  sections.push(section)

  match section.provenance.source {
    XrefSectionSource::Table => {
      match section.trailer.xref_stm {
        Some(xref_stm_offset) =>
          read_section_chain_from_offset(
            source, xref_stm_offset, version, visited, sections, false,
          )
        None => ()
      }
      if follow_prev {
        match section.trailer.prev {
          Some(prev_offset) =>
            read_section_chain_from_offset(
              source, prev_offset, version, visited, sections, true,
            )
          None => ()
        }
      }
    }
    XrefSectionSource::Stream =>
      if follow_prev {
        match section.trailer.prev {
          Some(prev_offset) =>
            read_section_chain_from_offset(
              source, prev_offset, version, visited, sections, true,
            )
          None => ()
        }
      }
  }
}

///|
fn read_xref_section_at_offset(
  source : ByteSource,
  pdf_offset : Int64,
  version : PdfVersion,
) -> XrefSection raise PdfReaderError {
  let bytes = source.slice_from_pdf_offset(pdf_offset)
  if matches_keyword_at(bytes, 0, b"xref") {
    parse_xref_table_section(source, pdf_offset)
  } else {
    parse_xref_stream_section(source, pdf_offset, version)
  }
}
