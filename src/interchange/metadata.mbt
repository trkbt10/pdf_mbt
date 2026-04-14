///|
/// Validates a resolved metadata stream and decodes its XML payload through the
/// existing filter pipeline. The XML bytes are opaque to this feature.
pub fn validate_metadata_stream(
  object_id? : @objects.ObjectId? = None,
  object : @objects.PdfObject,
) -> PdfMetadataStream raise PdfInterchangeError {
  let stream = match object {
    @objects.PdfObject::Stream(value) => value
    @objects.PdfObject::Null =>
      raise PdfInterchangeError::InvalidMetadata(
        object_id, "metadata stream object is missing",
      )
    _ =>
      raise PdfInterchangeError::InvalidMetadata(
        object_id,
        "metadata entry must resolve to a stream, not " + object_kind(object),
      )
  }
  validate_metadata_stream_value(object_id~, stream)
}

///|
/// Validates a metadata stream already available as a stream value.
pub fn validate_metadata_stream_value(
  object_id? : @objects.ObjectId? = None,
  stream : @objects.PdfStream,
) -> PdfMetadataStream raise PdfInterchangeError {
  required_name_entry(
    stream.dict,
    b"Type",
    b"Metadata",
    object_id,
    "metadata stream",
  )
  required_name_entry(
    stream.dict,
    b"Subtype",
    b"XML",
    object_id,
    "metadata stream",
  )
  let xml = try @filters.decode_stream(stream) catch {
    error => raise PdfInterchangeError::FilterError(error)
  } noraise {
    decoded => decoded
  }
  PdfMetadataStream::{ object_id, raw_stream: stream, xml }
}

///|
/// Validates an optional object-level Metadata entry from an owner dictionary.
/// The owner still controls indirect loading; present entries must already be
/// materialized as stream objects.
pub fn validate_object_metadata(
  owner_id? : @objects.ObjectId? = None,
  owner : @objects.PdfObject,
) -> PdfMetadataStream? raise PdfInterchangeError {
  match owner {
    @objects.PdfObject::Dictionary(dict) =>
      validate_metadata_entry(owner_id~, dict)
    @objects.PdfObject::Stream(stream) =>
      validate_metadata_entry(owner_id~, stream.dict)
    @objects.PdfObject::Null => None
    _ =>
      raise PdfInterchangeError::InvalidMetadata(
        owner_id,
        "metadata owner must be a dictionary or stream, not " +
        object_kind(owner),
      )
  }
}

///|
pub fn validate_metadata_entry(
  owner_id? : @objects.ObjectId? = None,
  dict : @objects.PdfDictionary,
) -> PdfMetadataStream? raise PdfInterchangeError {
  match dict.get(pdf_name(b"Metadata")) {
    None => None
    Some(@objects.PdfObject::Null) => None
    Some(value) => Some(validate_metadata_stream(object_id=owner_id, value))
  }
}

///|
/// Builds metadata source diagnostics when optional XMP date bytes are
/// available from a future semantic extractor. This feature normally passes no
/// XMP dates, producing `OnlyInfo` or `NotEvaluated` as appropriate.
pub fn metadata_source_diagnostics(
  metadata : PdfMetadataStream?,
  info : PdfDocumentInfo?,
  metadata_creation_date? : Bytes? = None,
  metadata_mod_date? : Bytes? = None,
) -> PdfMetadataSourceDiagnostics {
  PdfMetadataSourceDiagnostics::{
    has_metadata_stream: metadata is Some(_),
    has_document_info: info is Some(_),
    creation_date: compare_optional_dates(
      info_creation_date(info),
      metadata_creation_date,
    ),
    mod_date: compare_optional_dates(info_mod_date(info), metadata_mod_date),
  }
}

///|
fn info_creation_date(info : PdfDocumentInfo?) -> Bytes? {
  match info {
    Some(value) => value.creation_date
    None => None
  }
}

///|
fn info_mod_date(info : PdfDocumentInfo?) -> Bytes? {
  match info {
    Some(value) => value.mod_date
    None => None
  }
}

///|
fn compare_optional_dates(
  info_date : Bytes?,
  metadata_date : Bytes?,
) -> PdfMetadataDateComparison {
  match (info_date, metadata_date) {
    (Some(left), Some(right)) =>
      if left == right {
        PdfMetadataDateComparison::Equivalent
      } else {
        PdfMetadataDateComparison::Different
      }
    (Some(_), None) => PdfMetadataDateComparison::OnlyInfo
    (None, Some(_)) => PdfMetadataDateComparison::OnlyMetadataStream
    (None, None) => PdfMetadataDateComparison::NotEvaluated
  }
}
