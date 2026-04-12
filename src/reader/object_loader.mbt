///|
pub fn PdfFile::load_object(
  self : PdfFile,
  id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfReaderError {
  match self.cache.get(id) {
    Some(object) => object
    None => {
      let object = match self.xref_index.resolve(id) {
        Some(location) => load_object_at_location(self, id, location)
        None => @objects.PdfObject::Null
      }
      self.cache[id] = object
      object
    }
  }
}

///|
fn load_object_at_location(
  file : PdfFile,
  id : @objects.ObjectId,
  location : ObjectLocation,
) -> @objects.PdfObject raise PdfReaderError {
  match location {
    ObjectLocation::Uncompressed(pdf_offset, _) =>
      load_uncompressed_object(file, id, pdf_offset)
    ObjectLocation::Compressed(object_stream_number, index) =>
      load_compressed_object(file, id, object_stream_number, index)
  }
}

///|
fn load_uncompressed_object(
  file : PdfFile,
  id : @objects.ObjectId,
  pdf_offset : Int64,
) -> @objects.PdfObject raise PdfReaderError {
  let source = ByteSource::new(file.bytes, file.header.base_offset)
  let bytes = source.slice_from_pdf_offset(pdf_offset)
  let parsed_result : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    bytes,
  )
  let parsed = match parsed_result {
    Ok(value) => value
    Err(error) => raise PdfReaderError::ParseObjectError(pdf_offset, error)
  }

  if parsed.id != id {
    raise PdfReaderError::InvalidObjectLocation(
      id, "parsed indirect object id mismatch",
    )
  }

  parsed.value
}

///|
fn load_compressed_object(
  file : PdfFile,
  id : @objects.ObjectId,
  object_stream_number : Int,
  index : Int,
) -> @objects.PdfObject raise PdfReaderError {
  if id.generation_number != 0 {
    raise PdfReaderError::InvalidObjectStream(
      object_stream_number.to_int64(),
      "compressed objects must have generation 0",
    )
  }

  let object_stream_id = @objects.ObjectId::{
    object_number: object_stream_number,
    generation_number: 0,
  }
  match file.object_stream_tables.get(object_stream_id) {
    Some(cache) => {
      let entry = require_object_stream_cache_entry(cache, index)
      if entry.object_number != id.object_number {
        raise PdfReaderError::InvalidObjectLocation(
          id, "compressed object stream member mismatch",
        )
      }
      entry.object
    }
    None => {
      let location = match file.xref_index.resolve(object_stream_id) {
        Some(location) => location
        None =>
          raise PdfReaderError::InvalidObjectLocation(
            object_stream_id, "object stream container is missing",
          )
      }

      let parse_offset = match location {
        ObjectLocation::Uncompressed(pdf_offset, _) => pdf_offset
        ObjectLocation::Compressed(_, _) =>
          raise PdfReaderError::InvalidObjectLocation(
            object_stream_id, "object stream container must be uncompressed",
          )
      }

      let stream_object = file.load_object(object_stream_id)
      let stream = match stream_object {
        @objects.PdfObject::Stream(stream) => stream
        @objects.PdfObject::Null =>
          raise PdfReaderError::InvalidObjectLocation(
            object_stream_id, "object stream container is missing",
          )
        _ =>
          raise PdfReaderError::InvalidObjectLocation(
            object_stream_id, "object stream container must be a stream",
          )
      }

      let table = parse_object_stream(stream, offset=parse_offset)
      let cache = ObjectStreamTableCache::{
        offset: parse_offset,
        members: table.entries(),
      }
      file.object_stream_tables[object_stream_id] = cache
      let entry = table.entry_at(index)
      if entry.object_number != id.object_number {
        raise PdfReaderError::InvalidObjectLocation(
          id, "compressed object stream member mismatch",
        )
      }
      entry.object
    }
  }
}

///|
fn require_object_stream_cache_entry(
  cache : ObjectStreamTableCache,
  index : Int,
) -> ObjectStreamTableCacheEntry raise PdfReaderError {
  if index < 0 {
    raise PdfReaderError::InvalidObjectStream(
      cache.offset,
      "object stream member index is out of range",
    )
  }

  match cache.members.get(index) {
    Some(entry) => entry
    None =>
      raise PdfReaderError::InvalidObjectStream(
        cache.offset,
        "object stream member index is out of range",
      )
  }
}
