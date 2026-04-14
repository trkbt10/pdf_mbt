///|
/// Validates a resolved trailer Info dictionary and exposes known entries as
/// byte-preserved fields.
pub fn validate_document_info(
  object_id? : @objects.ObjectId? = None,
  object : @objects.PdfObject,
) -> PdfDocumentInfo raise PdfInterchangeError {
  let dict = match object {
    @objects.PdfObject::Dictionary(value) => value
    @objects.PdfObject::Null =>
      raise PdfInterchangeError::InvalidDocumentInfo(
        object_id, "document information dictionary is missing",
      )
    _ =>
      raise PdfInterchangeError::InvalidDocumentInfo(
        object_id,
        "document information entry must resolve to a dictionary, not " +
        object_kind(object),
      )
  }
  validate_document_info_dictionary(object_id~, dict)
}

///|
pub fn validate_document_info_dictionary(
  object_id? : @objects.ObjectId? = None,
  dict : @objects.PdfDictionary,
) -> PdfDocumentInfo raise PdfInterchangeError {
  PdfDocumentInfo::{
    object_id,
    title: optional_info_string(dict, b"Title", object_id),
    author: optional_info_string(dict, b"Author", object_id),
    subject: optional_info_string(dict, b"Subject", object_id),
    keywords: optional_info_string(dict, b"Keywords", object_id),
    creator: optional_info_string(dict, b"Creator", object_id),
    producer: optional_info_string(dict, b"Producer", object_id),
    creation_date: optional_info_string(dict, b"CreationDate", object_id),
    mod_date: optional_info_string(dict, b"ModDate", object_id),
    trapped: optional_trapped(dict, object_id),
    raw_dict: dict,
  }
}

///|
fn optional_info_string(
  dict : @objects.PdfDictionary,
  key : Bytes,
  object_id : @objects.ObjectId?,
) -> Bytes? raise PdfInterchangeError {
  match dict.get(pdf_name(key)) {
    None => None
    Some(@objects.PdfObject::String(bytes)) => {
      if key == b"CreationDate" || key == b"ModDate" {
        try @common_data.parse_pdf_date(bytes) catch {
          error =>
            raise PdfInterchangeError::InvalidDocumentInfo(
              object_id,
              "/" +
              @utf8.decode_lossy(key) +
              " invalid date: " +
              common_data_reason(error),
            )
        } noraise {
          _ => ()
        }
      } else {
        try @common_data.parse_text_string(bytes) catch {
          error =>
            raise PdfInterchangeError::InvalidDocumentInfo(
              object_id,
              "/" +
              @utf8.decode_lossy(key) +
              " invalid text string: " +
              common_data_reason(error),
            )
        } noraise {
          _ => ()
        }
      }
      Some(bytes)
    }
    Some(value) =>
      raise PdfInterchangeError::InvalidDocumentInfo(
        object_id,
        "/" +
        @utf8.decode_lossy(key) +
        " must be a text string, not " +
        object_kind(value),
      )
  }
}

///|
fn optional_trapped(
  dict : @objects.PdfDictionary,
  object_id : @objects.ObjectId?,
) -> PdfTrappedStatus raise PdfInterchangeError {
  match dict.get(pdf_name(b"Trapped")) {
    None => PdfTrappedStatus::Unknown
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"True") =>
      PdfTrappedStatus::True
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"False") =>
      PdfTrappedStatus::False
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"Unknown") =>
      PdfTrappedStatus::Unknown
    Some(@objects.PdfObject::Name(name)) =>
      raise PdfInterchangeError::InvalidDocumentInfo(
        object_id,
        "/Trapped must be /True, /False, or /Unknown, not /" + name_text(name),
      )
    Some(value) =>
      raise PdfInterchangeError::InvalidDocumentInfo(
        object_id,
        "/Trapped must be a name, not " + object_kind(value),
      )
  }
}
