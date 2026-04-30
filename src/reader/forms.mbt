///|
/// Returns the Catalog AcroForm dictionary as typed reader data. Missing
/// AcroForm data is distinct from an empty interactive form; present malformed
/// dictionaries raise InvalidForm.
pub fn PdfDocument::acro_form(
  self : PdfDocument,
) -> PdfAcroForm? raise PdfDocumentError {
  match self.catalog.acro_form_entry() {
    None => None
    Some(value) => {
      let (object_id, dict) = resolve_structural_dictionary(
        self.file,
        value,
        StructuralDomain::Form,
        "Catalog AcroForm",
      )
      Some(parse_acro_form(self.file, object_id, dict))
    }
  }
}

///|
fn parse_acro_form(
  file : PdfFile,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> PdfAcroForm raise PdfDocumentError {
  let fields = match dict.get(form_key(b"Fields")) {
    Some(value) => parse_acro_form_root_fields(file, value)
    None => raise form_error(object_id, "AcroForm is missing /Fields")
  }
  PdfAcroForm::{
    root_fields: fields,
    need_appearances: form_optional_bool(
      dict,
      form_key(b"NeedAppearances"),
      object_id,
      "AcroForm NeedAppearances",
    ),
    signature_flags: form_optional_int(
      dict,
      form_key(b"SigFlags"),
      object_id,
      "AcroForm SigFlags",
    ),
    calculation_order: form_optional_array_objects(
      file,
      dict,
      form_key(b"CO"),
      "AcroForm calculation order",
    ),
    default_resources: dict.get(form_key(b"DR")),
    default_appearance: form_optional_bytes(
      dict,
      form_key(b"DA"),
      object_id,
      "AcroForm DA",
    ),
    quadding: form_optional_int(dict, form_key(b"Q"), object_id, "AcroForm Q"),
    xfa: dict.get(form_key(b"XFA")),
    raw_dict: dict,
  }
}

///|
fn parse_acro_form_root_fields(
  file : PdfFile,
  value : @objects.PdfObject,
) -> Array[PdfFormField] raise PdfDocumentError {
  let (_, field_objects) = resolve_structural_array(
    file,
    value,
    StructuralDomain::Form,
    "AcroForm Fields",
  )
  let fields : Array[PdfFormField] = []
  for field in field_objects {
    fields.push(parse_acro_form_root_field(file, field))
  }
  fields
}

///|
fn parse_acro_form_root_field(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfFormField raise PdfDocumentError {
  let (object_id, dict, _) = resolve_form_field_dictionary(file, value, [])
  let field_type = match
    form_optional_name(dict, form_key(b"FT"), object_id, "field FT") {
    Some(name) => form_field_type_from_name(name)
    None => PdfFormFieldType::Absent
  }
  PdfFormField::{
    object_id,
    partial_name: form_optional_bytes(
      dict,
      form_key(b"T"),
      object_id,
      "field T",
    ),
    fully_qualified_name: form_optional_bytes(
      dict,
      form_key(b"T"),
      object_id,
      "field T",
    ),
    field_type,
    flags: PdfFormFieldFlags::{
      bits: form_optional_int(dict, form_key(b"Ff"), object_id, "field Ff").unwrap_or(
        0,
      ),
    },
    value: form_field_value_from_object(dict.get(form_key(b"V"))),
    default_value: form_field_value_from_object(dict.get(form_key(b"DV"))),
    parent: None,
    kids: form_optional_array_objects(
      file,
      dict,
      form_key(b"Kids"),
      "field Kids",
    ),
    widgets: [],
    variable_text: None,
    raw_dict: dict,
  }
}

///|
fn form_field_type_from_name(name : @objects.PdfName) -> PdfFormFieldType {
  if name == form_key(b"Btn") {
    PdfFormFieldType::Button
  } else if name == form_key(b"Tx") {
    PdfFormFieldType::Text
  } else if name == form_key(b"Ch") {
    PdfFormFieldType::Choice
  } else if name == form_key(b"Sig") {
    PdfFormFieldType::Signature
  } else {
    PdfFormFieldType::Unknown(name)
  }
}

///|
fn form_field_value_from_object(
  value : @objects.PdfObject?,
) -> PdfFormFieldValue {
  match value {
    Some(@objects.PdfObject::Name(name)) => PdfFormFieldValue::Name(name)
    Some(@objects.PdfObject::String(bytes)) => PdfFormFieldValue::String(bytes)
    Some(@objects.PdfObject::Array(values)) => PdfFormFieldValue::Array(values)
    Some(object) => PdfFormFieldValue::Raw(object)
    None => PdfFormFieldValue::Absent
  }
}

///|
fn form_optional_array_objects(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  label : String,
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => {
      let (_, values) = resolve_structural_array(
        file,
        value,
        StructuralDomain::Form,
        label,
      )
      values
    }
    None => []
  }
}

///|
fn form_optional_bytes(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  label : String,
) -> Bytes? raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::String(bytes)) => Some(bytes)
    Some(_) => raise form_error(object_id, label + " must be a string")
    None => None
  }
}

///|
fn form_optional_bool(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  label : String,
) -> Bool? raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::Boolean(value)) => Some(value)
    Some(_) => raise form_error(object_id, label + " must be a boolean")
    None => None
  }
}
