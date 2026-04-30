///|
/// Reports the ISO 32000-2 Section 12.1 General interactive navigation
/// features present in this document. The summary covers catalog-level viewer
/// preferences, outlines, page labels, destinations, forms, signatures,
/// requirements, and page-level thumbnails, presentations, annotations,
/// actions, measurement properties, and geospatial features without executing
/// any processor behavior.
pub fn PdfDocument::interactive_navigation(
  self : PdfDocument,
) -> PdfInteractiveNavigation raise PdfDocumentError {
  let pages = self.pages()
  PdfInteractiveNavigation::{
    viewer_preferences: has_catalog_entry(
      self,
      navigation_key(b"ViewerPreferences"),
    ),
    outlines: has_catalog_entry(self, navigation_key(b"Outlines")),
    page_labels: has_catalog_entry(self, navigation_key(b"PageLabels")),
    thumbnails: pages_have_entry(pages, navigation_key(b"Thumb")),
    presentations: has_presentation_features(self, pages),
    destinations: has_destination_features(self),
    annotations: pages_have_entry(pages, navigation_key(b"Annots")),
    actions: has_action_features(self, pages),
    forms: has_catalog_entry(self, navigation_key(b"AcroForm")),
    signatures: has_signature_features(self),
    measurement_properties: pages_have_entry(pages, navigation_key(b"VP")),
    geospatial_features: pages_have_entry(pages, navigation_key(b"VP")),
    document_requirements: has_catalog_entry(
      self,
      navigation_key(b"Requirements"),
    ),
  }
}

///|
fn has_catalog_entry(document : PdfDocument, key : @objects.PdfName) -> Bool {
  document.catalog.entry(key) is Some(_)
}

///|
fn pages_have_entry(pages : Array[PdfPage], key : @objects.PdfName) -> Bool {
  for page in pages {
    if page.entry(key) is Some(_) {
      return true
    }
  }
  false
}

///|
fn has_presentation_features(
  document : PdfDocument,
  pages : Array[PdfPage],
) -> Bool raise PdfDocumentError {
  (
    has_catalog_entry(document, navigation_key(b"Names")) &&
    document.name_tree_root(NameTreeCategory::AlternatePresentations) is Some(_)
  ) ||
  pages_have_entry(pages, navigation_key(b"Dur")) ||
  pages_have_entry(pages, navigation_key(b"Trans")) ||
  pages_have_entry(pages, navigation_key(b"PresSteps"))
}

///|
fn has_destination_features(
  document : PdfDocument,
) -> Bool raise PdfDocumentError {
  has_catalog_entry(document, navigation_key(b"Dests")) ||
  document.name_tree_root(NameTreeCategory::Dests) is Some(_)
}

///|
fn has_action_features(document : PdfDocument, pages : Array[PdfPage]) -> Bool {
  has_catalog_entry(document, navigation_key(b"OpenAction")) ||
  has_catalog_entry(document, navigation_key(b"AA")) ||
  pages_have_entry(pages, navigation_key(b"AA"))
}

///|
fn has_signature_features(document : PdfDocument) -> Bool {
  has_catalog_entry(document, navigation_key(b"Perms")) ||
  has_catalog_entry(document, navigation_key(b"DSS"))
}
