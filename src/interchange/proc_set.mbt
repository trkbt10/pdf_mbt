///|
/// Validates the optional deprecated ProcSet resource category as predefined
/// procedure set names without changing raw resource lookup behavior.
pub fn parse_proc_sets(
  resources : @content.ContentResources,
) -> Array[PdfProcedureSetName] raise PdfInterchangeError {
  let object = try
    resources.category_object(@content.ResourceCategory::ProcSet)
  catch {
    error => raise PdfInterchangeError::ContentError(error)
  } noraise {
    value => value
  }
  match object {
    None => []
    Some(@objects.PdfObject::Array(values)) => parse_proc_set_array(values)
    Some(value) =>
      raise PdfInterchangeError::InvalidProcedureSet(
        "ProcSet resource category must be an array, not " + object_kind(value),
      )
  }
}

///|
pub fn parse_proc_set_name(
  name : @objects.PdfName,
) -> PdfProcedureSetName raise PdfInterchangeError {
  if name == pdf_name(b"PDF") {
    PdfProcedureSetName::PDF
  } else if name == pdf_name(b"Text") {
    PdfProcedureSetName::Text
  } else if name == pdf_name(b"ImageB") {
    PdfProcedureSetName::ImageB
  } else if name == pdf_name(b"ImageC") {
    PdfProcedureSetName::ImageC
  } else if name == pdf_name(b"ImageI") {
    PdfProcedureSetName::ImageI
  } else {
    raise PdfInterchangeError::InvalidProcedureSet(
      "unknown predefined ProcSet name /" + name_text(name),
    )
  }
}

///|
fn parse_proc_set_array(
  values : Array[@objects.PdfObject],
) -> Array[PdfProcedureSetName] raise PdfInterchangeError {
  let names : Array[PdfProcedureSetName] = []
  for value in values {
    match value {
      @objects.PdfObject::Name(name) => names.push(parse_proc_set_name(name))
      _ =>
        raise PdfInterchangeError::InvalidProcedureSet(
          "ProcSet entries must be names, not " + object_kind(value),
        )
    }
  }
  names
}
