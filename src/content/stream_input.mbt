///|
/// Parses already-decoded content stream bytes with an explicit resource
/// dictionary context and returns the ordered instruction model. Byte offsets
/// are preserved relative to the decoded input supplied to the parser.
pub fn parse_decoded_content(
  input : Bytes,
  resources : ContentResources,
) -> ContentStream raise PdfContentError {
  ContentStreamParser::with_resources(input, resources).parse_all()
}

///|
/// Decodes a PDF stream through the filter pipeline and then parses the
/// decoded content stream bytes with the supplied resource context. Filter
/// failures are wrapped as content stream diagnostics.
pub fn parse_content_stream(
  stream : @objects.PdfStream,
  resources : ContentResources,
) -> ContentStream raise PdfContentError {
  let decoded = try @filters.decode_stream(stream) catch {
    error => raise FilterError(0L, error)
  } noraise {
    bytes => bytes
  }
  parse_decoded_content(decoded, resources)
}
