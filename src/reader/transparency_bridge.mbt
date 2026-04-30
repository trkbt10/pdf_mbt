///|
/// Materialized page-level transparency inputs that the reader owns before
/// graphics interpretation or rendering begins.
pub(all) struct PdfPageTransparencyInputs {
  page_group : @graphics.TransparencyGroup?
  resources : @content.ContentResources
} derive(Eq, Debug)

///|
pub fn PdfPage::transparency_group(
  self : PdfPage,
) -> @graphics.TransparencyGroup? raise PdfDocumentError {
  let object = resolve_optional_page_object(
    self.file,
    self.entry(@objects.PdfName::new(b"Group")),
  )
  match object {
    Some(@objects.PdfObject::Dictionary(dict)) =>
      try
        @graphics.try_parse_transparency_group_dictionary(
          dict,
          @graphics.TransparencyGroupContext::PageTransparencyGroup,
          0L,
        )
      catch {
        error => raise PdfDocumentError::GraphicsError(error)
      } noraise {
        group => group
      }
    Some(@objects.PdfObject::Null) | None => None
    Some(_) =>
      raise PdfDocumentError::InvalidPage(
        self.object_id(),
        "Page Group entry must resolve to a dictionary",
      )
  }
}

///|
pub fn PdfPage::materialized_transparency_inputs(
  self : PdfPage,
) -> PdfPageTransparencyInputs raise PdfDocumentError {
  PdfPageTransparencyInputs::{
    page_group: self.transparency_group(),
    resources: self.materialized_content_resources(),
  }
}
