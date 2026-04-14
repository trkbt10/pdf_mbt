///|
fn common_data_reason(error : @common_data.PdfCommonDataError) -> String {
  match error {
    @common_data.PdfCommonDataError::ExpectedString(reason) => reason
    @common_data.PdfCommonDataError::InvalidTextString(reason) => reason
    @common_data.PdfCommonDataError::InvalidAsciiString(reason) => reason
    @common_data.PdfCommonDataError::InvalidDate(_, reason) => reason
    @common_data.PdfCommonDataError::InvalidRectangle(reason) => reason
    @common_data.PdfCommonDataError::InvalidTreeNode(reason) => reason
  }
}

///|
fn reader_common_error(
  owner : @objects.PdfName,
  label : String,
  error : @common_data.PdfCommonDataError,
) -> PdfDocumentError {
  navigation_error(owner, label + ": " + common_data_reason(error))
}

///|
fn reader_rectangle(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> PdfRectangle raise PdfDocumentError {
  try @common_data.parse_pdf_rectangle(value) catch {
    error => raise reader_common_error(owner, label, error)
  } noraise {
    rect =>
      PdfRectangle::{
        left: rect.left,
        bottom: rect.bottom,
        right: rect.right,
        top: rect.top,
      }
  }
}

///|
fn typed_page_common_error(
  page_id : @objects.ObjectId,
  key : @objects.PdfName,
  label : String,
  inherited : Bool,
  error : @common_data.PdfCommonDataError,
) -> PdfDocumentError {
  typed_page_error(
    page_id,
    key,
    label + ": " + common_data_reason(error),
    inherited,
  )
}

///|
fn typed_page_rectangle(
  page_id : @objects.ObjectId,
  key : @objects.PdfName,
  value : @objects.PdfObject,
  label : String,
  inherited : Bool,
) -> PdfRectangle raise PdfDocumentError {
  try @common_data.parse_pdf_rectangle(value) catch {
    error =>
      raise typed_page_common_error(page_id, key, label, inherited, error)
  } noraise {
    rect =>
      PdfRectangle::{
        left: rect.left,
        bottom: rect.bottom,
        right: rect.right,
        top: rect.top,
      }
  }
}

///|
fn name_tree_common_error(
  key : @objects.PdfName,
  error : @common_data.PdfCommonDataError,
) -> PdfDocumentError {
  PdfDocumentError::InvalidNameTree(key, common_data_reason(error))
}

///|
fn number_tree_common_error(
  owner : @objects.PdfName,
  error : @common_data.PdfCommonDataError,
) -> PdfDocumentError {
  navigation_error(owner, common_data_reason(error))
}
