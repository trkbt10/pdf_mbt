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
