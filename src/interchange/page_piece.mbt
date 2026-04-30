///|
/// Validates a resolved PieceInfo dictionary. Each entry value must be a data
/// dictionary with raw LastModified bytes and optional opaque Private data.
pub fn validate_page_piece_dictionary(
  object_id? : @objects.ObjectId? = None,
  object : @objects.PdfObject,
) -> PdfPagePieceDictionary raise PdfInterchangeError {
  let dict = match object {
    @objects.PdfObject::Dictionary(value) => value
    @objects.PdfObject::Null =>
      raise PdfInterchangeError::InvalidPagePiece(
        object_id, "PieceInfo dictionary is missing",
      )
    _ =>
      raise PdfInterchangeError::InvalidPagePiece(
        object_id,
        "PieceInfo entry must be a dictionary, not " + object_kind(object),
      )
  }
  validate_page_piece_entries(object_id~, dict)
}

///|
pub fn validate_page_piece_entries(
  object_id? : @objects.ObjectId? = None,
  dict : @objects.PdfDictionary,
) -> PdfPagePieceDictionary raise PdfInterchangeError {
  let entries : Array[PdfPagePieceData] = []
  for entry in dict.to_array() {
    let (owner_name, value) = entry
    let data_dict = match value {
      @objects.PdfObject::Dictionary(data) => data
      _ =>
        raise PdfInterchangeError::InvalidPagePiece(
          object_id,
          "PieceInfo entry /" +
          name_text(owner_name) +
          " must be a data dictionary, not " +
          object_kind(value),
        )
    }
    entries.push(parse_page_piece_data(object_id, owner_name, data_dict))
  }
  PdfPagePieceDictionary::{ object_id, entries, raw_dict: dict }
}

///|
pub fn validate_optional_page_piece_entry(
  object_id? : @objects.ObjectId? = None,
  dict : @objects.PdfDictionary,
) -> PdfPagePieceDictionary? raise PdfInterchangeError {
  match dict.get(pdf_name(b"PieceInfo")) {
    None => None
    Some(@objects.PdfObject::Null) => None
    Some(value) => Some(validate_page_piece_dictionary(object_id~, value))
  }
}

///|
/// Compares 14.5 page-piece dictionary LastModified dates by equality only.
/// Modification dates for private PDF processor data are not ordered because
/// platforms may have approximate times or differing time zones.
pub fn page_piece_dates_equal(left : Bytes, right : Bytes) -> Bool {
  left == right
}

///|
/// Reports whether two 14.5 page-piece data dictionaries have the same
/// LastModified date for the document, page, or form content they describe.
pub fn PdfPagePieceData::same_last_modified(
  self : PdfPagePieceData,
  other : PdfPagePieceData,
) -> Bool {
  page_piece_dates_equal(self.last_modified, other.last_modified)
}

///|
fn parse_page_piece_data(
  object_id : @objects.ObjectId?,
  owner_name : @objects.PdfName,
  data_dict : @objects.PdfDictionary,
) -> PdfPagePieceData raise PdfInterchangeError {
  let last_modified = match data_dict.get(pdf_name(b"LastModified")) {
    Some(@objects.PdfObject::String(bytes)) => {
      try @common_data.parse_pdf_date(bytes) catch {
        error =>
          raise PdfInterchangeError::InvalidPagePiece(
            object_id,
            "PieceInfo entry /" +
            name_text(owner_name) +
            " /LastModified invalid date: " +
            common_data_reason(error),
          )
      } noraise {
        _ => ()
      }
      bytes
    }
    Some(value) =>
      raise PdfInterchangeError::InvalidPagePiece(
        object_id,
        "PieceInfo entry /" +
        name_text(owner_name) +
        " /LastModified must be a date string, not " +
        object_kind(value),
      )
    None =>
      raise PdfInterchangeError::InvalidPagePiece(
        object_id,
        "PieceInfo entry /" +
        name_text(owner_name) +
        " is missing /LastModified",
      )
  }
  PdfPagePieceData::{
    owner_name,
    last_modified,
    private: data_dict.get(pdf_name(b"Private")),
    raw_dict: data_dict,
  }
}
