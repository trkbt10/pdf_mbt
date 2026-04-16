///|
fn merge_sections(
  sections : Array[XrefSection],
) -> XrefIndex raise PdfReaderError {
  let active : XrefIndex = Map::new()
  let seen_object_numbers : Map[Int, Bool] = Map::new()

  for section in sections {
    let size = section.trailer.size
    for section_entry in section.entries {
      let object_number = section_entry.object_number
      if object_number < 0 {
        raise PdfReaderError::InvalidObjectLocation(
          @objects.ObjectId::{ object_number, generation_number: 0 },
          "xref object number must be non-negative",
        )
      }
      if object_number >= size {
        continue
      }

      if seen_object_numbers.contains(object_number) {
        continue
      }

      match section_entry.entry {
        XrefEntry::Free(next_free_object_number, generation_number) => {
          let object_id = @objects.ObjectId::{
            object_number,
            generation_number,
          }
          require_non_negative_object_location(
            object_id,
            next_free_object_number.to_int64(),
            "xref free entry next object number",
          )
          seen_object_numbers[object_number] = true
        }
        XrefEntry::InUse(pdf_offset, generation_number) => {
          let object_id = @objects.ObjectId::{
            object_number,
            generation_number,
          }
          require_non_negative_object_location(
            object_id, pdf_offset, "xref in-use entry byte offset",
          )
          seen_object_numbers[object_number] = true
          active[object_id] = ObjectLocation::Uncompressed(
            pdf_offset, generation_number,
          )
        }
        XrefEntry::Compressed(object_stream_number, index) => {
          let object_id = @objects.ObjectId::{
            object_number,
            generation_number: 0,
          }
          require_non_negative_object_location(
            object_id,
            object_stream_number.to_int64(),
            "xref compressed entry object stream number",
          )
          require_non_negative_object_location(
            object_id,
            index.to_int64(),
            "xref compressed entry index",
          )
          seen_object_numbers[object_number] = true
          active[object_id] = ObjectLocation::Compressed(
            object_stream_number, index,
          )
        }
      }
    }
  }

  active
}

///|
fn resolve_merged_trailer(
  sections : Array[XrefSection],
) -> TrailerInfo raise PdfReaderError {
  if sections.length() == 0 {
    raise PdfReaderError::InvalidTrailer(0L, "missing cross-reference sections")
  }

  let latest = sections[0].trailer
  match find_first_trailer_root(sections) {
    Some(root) => {
      let info = find_first_trailer_info(sections)
      let raw_dict = latest.raw_dict.copy()
      raw_dict[@objects.PdfName::new(b"Root")] = @objects.PdfObject::Ref(root)
      match info {
        Some(info_ref) =>
          raw_dict[@objects.PdfName::new(b"Info")] = @objects.PdfObject::Ref(
            info_ref,
          )
        None => ()
      }
      TrailerInfo::{
        size: latest.size,
        root: Some(root),
        prev: latest.prev,
        encrypt: latest.encrypt,
        info,
        id: latest.id,
        xref_stm: latest.xref_stm,
        raw_dict,
      }
    }
    None =>
      raise PdfReaderError::InvalidTrailer(
        sections[0].provenance.pdf_offset,
        "missing Root entry in trailer chain",
      )
  }
}

///|
fn find_first_trailer_root(sections : Array[XrefSection]) -> @objects.ObjectId? {
  let mut found : @objects.ObjectId? = None
  for section in sections {
    if found is None {
      match section.trailer.root {
        Some(root) => found = Some(root)
        None => ()
      }
    }
  }
  found
}

///|
fn find_first_trailer_info(sections : Array[XrefSection]) -> @objects.ObjectId? {
  let mut found : @objects.ObjectId? = None
  for section in sections {
    if found is None {
      match section.trailer.info {
        Some(info) => found = Some(info)
        None => ()
      }
    }
  }
  found
}

///|
fn XrefIndex::resolve(
  self : XrefIndex,
  id : @objects.ObjectId,
) -> ObjectLocation? {
  self.get(id)
}

///|
fn require_non_negative_object_location(
  object_id : @objects.ObjectId,
  value : Int64,
  context : String,
) -> Unit raise PdfReaderError {
  if value < 0L {
    raise PdfReaderError::InvalidObjectLocation(
      object_id,
      "\{context} must be non-negative",
    )
  }
}
