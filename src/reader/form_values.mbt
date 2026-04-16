///|
priv struct FormFieldInheritance {
  full_name : String?
  field_type : @objects.PdfName?
  flags : Int?
  value : @objects.PdfObject?
}

///|
fn form_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn form_error(
  object_id : @objects.ObjectId?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidForm(object_id, reason)
}

///|
/// Returns current interactive-form field values as a flat map from fully
/// qualified field name to string value. Text strings are decoded through the
/// common PDF text-string rules; choice arrays are joined with commas; button
/// fields expose the selected appearance state, including `Off`.
///
/// Field hierarchy traversal starts from the Catalog `/AcroForm` `/Fields`
/// array, walks the AcroForm field tree, resolves parent-child relationships,
/// and inherits `/FT`, `/Ff`, `/T`, and `/V` from parent nodes. Flat form data
/// export returns form field name-value pairs keyed by the field
/// fully-qualified name for programmatic form data extraction.
pub fn PdfDocument::form_field_values(
  self : PdfDocument,
) -> Map[String, String] raise PdfDocumentError {
  let output : Map[String, String] = Map::new()
  match self.catalog.acro_form_entry() {
    None => output
    Some(value) => {
      let (acroform_id, acroform) = resolve_structural_dictionary(
        self.file,
        value,
        StructuralDomain::Form,
        "Catalog AcroForm",
      )
      let fields_value = match acroform.get(form_key(b"Fields")) {
        Some(value) => value
        None => raise form_error(acroform_id, "AcroForm is missing /Fields")
      }
      let (_, fields) = resolve_structural_array(
        self.file,
        fields_value,
        StructuralDomain::Form,
        "AcroForm Fields",
      )
      let inherited = FormFieldInheritance::{
        full_name: None,
        field_type: None,
        flags: None,
        value: None,
      }
      for field in fields {
        collect_form_field_value(self.file, field, inherited, [], output)
      }
      output
    }
  }
}

///|
fn collect_form_field_value(
  file : PdfFile,
  value : @objects.PdfObject,
  inherited : FormFieldInheritance,
  path : Array[@objects.ObjectId],
  output : Map[String, String],
) -> Unit raise PdfDocumentError {
  let (object_id, dict, field_path) = resolve_form_field_dictionary(
    file, value, path,
  )
  let current = form_field_inheritance(dict, inherited, object_id)
  match current.full_name {
    Some(name) =>
      match form_field_current_value(file, dict, object_id, current) {
        Some(value) => output[name] = value
        None => ()
      }
    None => ()
  }

  match dict.get(form_key(b"Kids")) {
    Some(kids_value) => {
      let (_, kids) = resolve_structural_array(
        file,
        kids_value,
        StructuralDomain::Form,
        "form field Kids",
      )
      for kid in kids {
        collect_form_field_value(file, kid, current, field_path, output)
      }
    }
    None => ()
  }
}

///|
fn resolve_form_field_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  path : Array[@objects.ObjectId],
) -> (@objects.ObjectId?, @objects.PdfDictionary, Array[@objects.ObjectId]) raise PdfDocumentError {
  let (object_id, resolved, final_path) = resolve_structural_object_path(
    file,
    value,
    StructuralDomain::Form,
    "form field",
    path,
  )
  (
    object_id,
    structural_dictionary(
      resolved,
      StructuralDomain::Form,
      object_id,
      "form field",
    ),
    final_path,
  )
}

///|
fn form_field_inheritance(
  dict : @objects.PdfDictionary,
  inherited : FormFieldInheritance,
  object_id : @objects.ObjectId?,
) -> FormFieldInheritance raise PdfDocumentError {
  let partial_name = form_optional_text(
    dict,
    form_key(b"T"),
    object_id,
    "field T",
  )
  FormFieldInheritance::{
    full_name: form_qualified_name(inherited.full_name, partial_name),
    field_type: form_inherit_name(
      form_optional_name(dict, form_key(b"FT"), object_id, "field FT"),
      inherited.field_type,
    ),
    flags: form_inherit_int(
      form_optional_int(dict, form_key(b"Ff"), object_id, "field Ff"),
      inherited.flags,
    ),
    value: form_inherit_object(dict.get(form_key(b"V")), inherited.value),
  }
}

///|
fn form_qualified_name(parent : String?, partial : String?) -> String? {
  match partial {
    Some(name) =>
      match parent {
        Some(prefix) =>
          if prefix.length() == 0 {
            Some(name)
          } else if name.length() == 0 {
            Some(prefix)
          } else {
            Some(prefix + "." + name)
          }
        None => Some(name)
      }
    None => parent
  }
}

///|
fn form_inherit_name(
  value : @objects.PdfName?,
  inherited : @objects.PdfName?,
) -> @objects.PdfName? {
  match value {
    Some(name) => Some(name)
    None => inherited
  }
}

///|
fn form_inherit_int(value : Int?, inherited : Int?) -> Int? {
  match value {
    Some(flags) => Some(flags)
    None => inherited
  }
}

///|
fn form_inherit_object(
  value : @objects.PdfObject?,
  inherited : @objects.PdfObject?,
) -> @objects.PdfObject? {
  match value {
    Some(object) => Some(object)
    None => inherited
  }
}

///|
fn form_field_current_value(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  object_id : @objects.ObjectId?,
  inherited : FormFieldInheritance,
) -> String? raise PdfDocumentError {
  match inherited.field_type {
    Some(name) if name == form_key(b"Btn") =>
      form_button_value(file, dict, object_id, inherited.value)
    Some(name) if name == form_key(b"Sig") =>
      match inherited.value {
        Some(value) => {
          let _ = resolve_form_value_object(
            file, value, object_id, "signature V",
          )
          Some("signed")
        }
        None => None
      }
    Some(name) if name == form_key(b"Ch") =>
      match inherited.value {
        Some(value) => Some(form_choice_value(file, value, object_id))
        None => None
      }
    Some(name) if name == form_key(b"Tx") =>
      match inherited.value {
        Some(value) => Some(form_text_value(file, value, object_id, "field V"))
        None => None
      }
    Some(_) | None =>
      match inherited.value {
        Some(value) =>
          Some(form_object_value(file, value, object_id, "field V"))
        None => None
      }
  }
}

///|
fn form_button_value(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  object_id : @objects.ObjectId?,
  value : @objects.PdfObject?,
) -> String? raise PdfDocumentError {
  match value {
    Some(object) => Some(form_object_value(file, object, object_id, "button V"))
    None =>
      match dict.get(form_key(b"AS")) {
        Some(appearance) =>
          Some(form_appearance_state(file, appearance, object_id))
        None => None
      }
  }
}

///|
fn form_appearance_state(
  file : PdfFile,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
) -> String raise PdfDocumentError {
  match resolve_form_value_object(file, value, object_id, "button AS") {
    @objects.PdfObject::Name(name) => name.to_text()
    _ => raise form_error(object_id, "button AS must be a name")
  }
}

///|
fn form_choice_value(
  file : PdfFile,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
) -> String raise PdfDocumentError {
  let resolved = resolve_form_value_object(file, value, object_id, "choice V")
  match resolved {
    @objects.PdfObject::Array(values) =>
      form_join_values(file, values, object_id)
    _ => form_object_value(file, resolved, object_id, "choice V")
  }
}

///|
fn form_join_values(
  file : PdfFile,
  values : Array[@objects.PdfObject],
  object_id : @objects.ObjectId?,
) -> String raise PdfDocumentError {
  let mut output = ""
  for index in 0..<values.length() {
    if index > 0 {
      output = output + ","
    }
    output = output +
      form_object_value(file, values[index], object_id, "choice V")
  }
  output
}

///|
fn form_text_value(
  file : PdfFile,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  label : String,
) -> String raise PdfDocumentError {
  match resolve_form_value_object(file, value, object_id, label) {
    @objects.PdfObject::String(bytes) =>
      form_decode_text_string(bytes, object_id, label)
    _ => raise form_error(object_id, label + " must be a text string")
  }
}

///|
fn form_object_value(
  file : PdfFile,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  label : String,
) -> String raise PdfDocumentError {
  match resolve_form_value_object(file, value, object_id, label) {
    @objects.PdfObject::String(bytes) =>
      form_decode_text_string(bytes, object_id, label)
    @objects.PdfObject::Name(name) => name.to_text()
    @objects.PdfObject::Boolean(flag) => if flag { "true" } else { "false" }
    @objects.PdfObject::Integer(number) => number.to_string()
    @objects.PdfObject::Real(number) => number.to_string()
    @objects.PdfObject::Array(values) =>
      form_join_values(file, values, object_id)
    @objects.PdfObject::Null => ""
    @objects.PdfObject::Dictionary(_) | @objects.PdfObject::Stream(_) =>
      raise form_error(object_id, label + " cannot be represented as a string")
    @objects.PdfObject::Ref(_) =>
      raise form_error(object_id, label + " unresolved reference")
  }
}

///|
fn resolve_form_value_object(
  file : PdfFile,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  label : String,
) -> @objects.PdfObject raise PdfDocumentError {
  let (_, resolved) = resolve_structural_object(
    file,
    value,
    StructuralDomain::Form,
    label,
  )
  match resolved {
    @objects.PdfObject::Null =>
      raise form_error(object_id, label + " object is missing")
    _ => resolved
  }
}

///|
fn form_optional_text(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  label : String,
) -> String? raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::String(bytes)) =>
      Some(form_decode_text_string(bytes, object_id, label))
    Some(_) => raise form_error(object_id, label + " must be a text string")
    None => None
  }
}

///|
fn form_decode_text_string(
  bytes : Bytes,
  object_id : @objects.ObjectId?,
  label : String,
) -> String raise PdfDocumentError {
  try @common_data.parse_text_string(bytes) catch {
    _ => raise form_error(object_id, label + " is not a valid text string")
  } noraise {
    text => text.text
  }
}

///|
fn form_optional_name(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName? raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::Name(name)) => Some(name)
    Some(_) => raise form_error(object_id, label + " must be a name")
    None => None
  }
}

///|
fn form_optional_int(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  label : String,
) -> Int? raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::Integer(number)) => Some(number.to_int())
    Some(_) => raise form_error(object_id, label + " must be an integer")
    None => None
  }
}
