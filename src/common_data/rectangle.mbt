///|
pub fn parse_pdf_rectangle(
  object : @objects.PdfObject,
) -> PdfRectangle raise PdfCommonDataError {
  let values = match object {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfCommonDataError::InvalidRectangle(
        "rectangle must be an array, got " + common_object_kind(object),
      )
  }
  if values.length() != 4 {
    raise PdfCommonDataError::InvalidRectangle(
      "rectangle must contain exactly four numbers",
    )
  }
  PdfRectangle::{
    left: rectangle_number(values[0], "left"),
    bottom: rectangle_number(values[1], "bottom"),
    right: rectangle_number(values[2], "right"),
    top: rectangle_number(values[3], "top"),
  }
}

///|
fn rectangle_number(
  object : @objects.PdfObject,
  label : String,
) -> Double raise PdfCommonDataError {
  match object {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise PdfCommonDataError::InvalidRectangle(
        "rectangle " + label + " coordinate must be a number",
      )
  }
}
