///|
/// Typed Catalog Extensions aggregate for PDF developer extensions from ISO
/// 32000-2 clause 7.12.1 General. It represents the optional Catalog
/// Extensions dictionary whose entries identify developer-defined extensions
/// used by the document.
///
/// The Extensions dictionary may contain the Type name Extensions, and its
/// remaining keys are registered developer-prefix Name entries. Each
/// developer-prefix Name value is a direct developer extensions dictionary or,
/// for PDF 2.0, an array of direct developer extensions dictionaries. Each
/// Table 49 developer extensions dictionary records developer-defined version
/// information with BaseVersion and ExtensionLevel entries.
pub(all) struct PdfExtensions {
  prefixes : Array[PdfExtensionPrefixEntry]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// One exact developer-prefix entry in a Catalog Extensions dictionary.
/// Dictionary and array forms are normalized to ordered developer entries, and
/// the original prefix value is retained byte-for-byte as parsed object data.
pub(all) struct PdfExtensionPrefixEntry {
  prefix : @objects.PdfName
  developers : Array[PdfDeveloperExtension]
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// URL string entry for a PDF developer extension. Spec section 7.12.6 URL
/// defines the optional URL entry as a string containing a URL to the
/// documentation provided by the developer of this extension and as registered
/// in the PDF Registry, see Annex E "Extending PDF".
///
/// This extension URL registration data is associated with the developer
/// prefix URL and is preserved as raw bytes without network access.
pub type PdfDeveloperExtensionURL = Bytes

///|
/// One developer extension dictionary under a prefix. The optional URL entry
/// from spec section 7.12.6 is the extension URL for documentation
/// registration, associated with the developer prefix URL in the PDF Registry.
/// URL and ExtensionRevision strings are kept as raw bytes and are never
/// decoded, fetched, normalized, or interpreted by the reader.
pub(all) struct PdfDeveloperExtension {
  prefix : @objects.PdfName
  base_version : PdfVersion
  extension_level : Int
  url : PdfDeveloperExtensionURL?
  extension_revision : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Returns the optional URL entry from spec section 7.12.6 URL. The extension
/// URL is documentation registration data supplied by the developer and
/// registered in the PDF Registry for the developer prefix URL; the reader does
/// not fetch or interpret it.
pub fn PdfDeveloperExtension::extension_url(
  self : PdfDeveloperExtension,
) -> PdfDeveloperExtensionURL? {
  self.url
}

///|
/// Counts developer extension dictionaries across all Catalog prefixes.
pub fn PdfExtensions::developer_count(self : PdfExtensions) -> Int {
  let mut count = 0
  for entry in self.prefixes {
    if entry.developers.length() > 0 {
      count += entry.developers.length()
    }
  }
  count
}

///|
/// True when a prefix entry has a non-empty prefix and valid developers.
pub fn PdfExtensionPrefixEntry::has_valid_developer_set(
  self : PdfExtensionPrefixEntry,
) -> Bool {
  if self.prefix.to_text().length() == 0 || self.developers.length() == 0 {
    false
  } else {
    for developer in self.developers {
      if developer.extension_level < 0 {
        return false
      }
    }
    true
  }
}

///|
/// True when the developer extension targets PDF 2.0 or later semantics.
pub fn PdfDeveloperExtension::targets_pdf2_or_later(
  self : PdfDeveloperExtension,
) -> Bool {
  if self.extension_level < 0 {
    false
  } else if self.base_version.is_pdf2_or_later() {
    true
  } else {
    self.extension_revision is Some(bytes) && bytes.length() > 0
  }
}
