///|
/// Typed Catalog Extensions aggregate from ISO 32000-2 clause 7.12. It
/// preserves the raw direct Extensions dictionary so callers can apply future
/// registry or developer-specific policy without losing original payload data.
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
/// One developer extension dictionary under a prefix. Optional URL and
/// ExtensionRevision strings are kept as raw bytes and are never decoded,
/// fetched, normalized, or interpreted by the reader.
pub(all) struct PdfDeveloperExtension {
  prefix : @objects.PdfName
  base_version : PdfVersion
  extension_level : Int
  url : Bytes?
  extension_revision : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

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
