///|
/// Appends new or modified indirect objects to an existing PDF as an
/// incremental update, preserving the original bytes and writing a new xref
/// table and trailer whose /Prev points to the previous xref section.
///
/// Delegates to `@context.append_incremental_update` and translates the
/// context-level error wrapper back to the reader error that originally
/// occurred. The other `PdfContextError` variants cannot arise from this
/// path because no context-level document or object resolution happens.
pub fn append_incremental_update(
  original : Bytes,
  objects : Array[@objects.IndirectObject],
) -> Bytes raise @reader.PdfReaderError {
  try @context.append_incremental_update(original, objects) catch {
    @context.PdfContextError::ReaderError(error) => raise error
    _ =>
      raise @reader.PdfReaderError::MissingTailMarker(
        "unexpected context error during incremental update",
      )
  }
}
