///|
/// Returns the page content resource dictionary context by using the existing
/// inherited Resources lookup from the document structure layer and converting
/// it to the content stream resource model.
pub fn PdfPage::content_resources(
  self : PdfPage,
) -> @content.ContentResources raise PdfDocumentError {
  let object = resolve_optional_page_object(self.file, self.resources())
  try @content.ContentResources::from_object(object, 0L) catch {
    error => raise PdfDocumentError::ContentError(error)
  } noraise {
    resources => resources
  }
}

///|
/// Resolves absent, single-stream, and array-of-stream page Contents, decodes
/// each stream through the filter pipeline, concatenates multiple decoded
/// streams with one LF separator in document order, and parses the decoded
/// bytes into a content stream.
pub fn PdfPage::content_stream(
  self : PdfPage,
) -> @content.ContentStream raise PdfDocumentError {
  let resources = self.content_resources()
  let decoded = self.decoded_content_bytes()
  try @content.parse_decoded_content(decoded, resources) catch {
    error => raise PdfDocumentError::ContentError(error)
  } noraise {
    content => content
  }
}

///|
/// Returns only the parsed page content instructions from `content_stream`.
pub fn PdfPage::content_instructions(
  self : PdfPage,
) -> Array[@content.ContentInstruction] raise PdfDocumentError {
  self.content_stream().instructions
}

///|
fn PdfPage::decoded_content_bytes(
  self : PdfPage,
) -> Bytes raise PdfDocumentError {
  let streams = self.content_stream_objects()
  let output : Array[Byte] = []
  for index in 0..<streams.length() {
    if index > 0 {
      output.push(b'\n')
    }
    let decoded = decode_page_content_stream(streams[index])
    output.append(decoded.to_array())
  }
  Bytes::from_array(output)
}

///|
fn PdfPage::content_stream_objects(
  self : PdfPage,
) -> Array[@objects.PdfStream] raise PdfDocumentError {
  match self.contents() {
    None => []
    Some(@objects.PdfObject::Null) => []
    Some(@objects.PdfObject::Array(values)) =>
      resolve_content_stream_array(self, values)
    Some(value) => [resolve_content_stream_object(self, value)]
  }
}

///|
fn resolve_content_stream_array(
  page : PdfPage,
  values : Array[@objects.PdfObject],
) -> Array[@objects.PdfStream] raise PdfDocumentError {
  let streams : Array[@objects.PdfStream] = []
  for value in values {
    streams.push(resolve_content_stream_object(page, value))
  }
  streams
}

///|
fn resolve_content_stream_object(
  page : PdfPage,
  value : @objects.PdfObject,
) -> @objects.PdfStream raise PdfDocumentError {
  let object = resolve_page_content_object(page.file, value)
  match object {
    @objects.PdfObject::Stream(stream) => stream
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidPage(
        page.object_id(),
        "Contents stream object is missing",
      )
    _ =>
      raise PdfDocumentError::InvalidPage(
        page.object_id(),
        "Contents entry must resolve to a stream or an array of streams",
      )
  }
}

///|
fn resolve_page_content_object(
  file : PdfFile,
  value : @objects.PdfObject,
) -> @objects.PdfObject raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) =>
      try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        object => object
      }
    _ => value
  }
}

///|
fn resolve_optional_page_object(
  file : PdfFile,
  value : @objects.PdfObject?,
) -> @objects.PdfObject? raise PdfDocumentError {
  match value {
    None => None
    Some(object) => Some(resolve_page_content_object(file, object))
  }
}

///|
fn decode_page_content_stream(
  stream : @objects.PdfStream,
) -> Bytes raise PdfDocumentError {
  try @filters.decode_stream(stream) catch {
    error =>
      raise PdfDocumentError::ContentError(
        @content.PdfContentError::FilterError(0L, error),
      )
  } noraise {
    decoded => decoded
  }
}
