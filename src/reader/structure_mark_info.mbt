///|
/// Returns Catalog MarkInfo with ISO defaults when the dictionary is absent.
pub fn PdfDocument::mark_info(
  self : PdfDocument,
) -> PdfMarkInfo raise PdfDocumentError {
  match self.catalog.entry(structure_key(b"MarkInfo")) {
    None =>
      PdfMarkInfo::{
        marked: false,
        user_properties: false,
        suspects: false,
        raw_dict: None,
      }
    Some(value) => {
      let (object_id, dict) = structure_resolve_dictionary(
        self.file,
        value,
        "catalog /MarkInfo",
      )
      PdfMarkInfo::{
        marked: structure_optional_mark_flag(dict, object_id, b"Marked", false),
        user_properties: structure_optional_mark_flag(
          dict, object_id, b"UserProperties", false,
        ),
        suspects: structure_optional_mark_flag(
          dict, object_id, b"Suspects", false,
        ),
        raw_dict: Some(dict),
      }
    }
  }
}

///|
/// Returns the Catalog Lang text string, if present.
pub fn PdfDocument::document_language(
  self : PdfDocument,
) -> Bytes? raise PdfDocumentError {
  match self.catalog.entry(structure_key(b"Lang")) {
    Some(value) =>
      Some(
        structure_string(value, Some(self.catalog.object_id), "catalog /Lang"),
      )
    None => None
  }
}

///|
fn structure_optional_mark_flag(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
  key : Bytes,
  default_value : Bool,
) -> Bool raise PdfDocumentError {
  match dict.get(structure_key(key)) {
    Some(value) => structure_bool(value, owner, "mark information flag")
    None => default_value
  }
}
