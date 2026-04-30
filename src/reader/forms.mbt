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
/// Enumerates AcroForm fields in deterministic field-tree order with
/// inherited FT, Ff, V, and DV attributes resolved into each returned record.
pub fn PdfDocument::form_fields(
  self : PdfDocument,
) -> Array[PdfFormField] raise PdfDocumentError {
  let fields : Array[PdfFormField] = []
  let index : Map[String, PdfFormField] = Map::new()
  match self.catalog.acro_form_entry() {
    None => fields
    Some(value) => {
      let (object_id, acroform) = resolve_structural_dictionary(
        self.file,
        value,
        StructuralDomain::Form,
        "Catalog AcroForm",
      )
      let fields_value = match acroform.get(form_key(b"Fields")) {
        Some(value) => value
        None => raise form_error(object_id, "AcroForm is missing /Fields")
      }
      let (_, root_fields) = resolve_structural_array(
        self.file,
        fields_value,
        StructuralDomain::Form,
        "AcroForm Fields",
      )
      let inherited = FormTreeInheritance::{
        name: None,
        field_type: None,
        flags: None,
        value: None,
        default_value: None,
      }
      for field in root_fields {
        collect_typed_form_fields(
          self.file,
          field,
          inherited,
          [],
          None,
          fields,
          index,
        )
      }
      fields
    }
  }
}

///|
/// Looks up one typed AcroForm field by fully qualified field name.
pub fn PdfDocument::form_field_by_name(
  self : PdfDocument,
  name : Bytes,
) -> PdfFormField? raise PdfDocumentError {
  let wanted = form_bytes_to_text(name)
  for field in self.form_fields() {
    if field.fully_qualified_name is Some(field_name) &&
      form_bytes_to_text(field_name) == wanted {
      return Some(field)
    }
  }
  None
}

///|
priv struct FormTreeInheritance {
  name : Bytes?
  field_type : @objects.PdfName?
  flags : Int?
  value : @objects.PdfObject?
  default_value : @objects.PdfObject?
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
  let inherited = FormTreeInheritance::{
    name: None,
    field_type: None,
    flags: None,
    value: None,
    default_value: None,
  }
  let (object_id, dict, _) = resolve_form_field_dictionary(file, value, [])
  parse_typed_form_field(file, object_id, dict, inherited, None)
}

///|
fn collect_typed_form_fields(
  file : PdfFile,
  value : @objects.PdfObject,
  inherited : FormTreeInheritance,
  path : Array[@objects.ObjectId],
  parent : @objects.ObjectId?,
  fields : Array[PdfFormField],
  index : Map[String, PdfFormField],
) -> Unit raise PdfDocumentError {
  let (object_id, dict, field_path) = resolve_form_field_dictionary(
    file, value, path,
  )
  let field = parse_typed_form_field(file, object_id, dict, inherited, parent)
  if field.fully_qualified_name is Some(name) {
    let key = form_bytes_to_text(name)
    match index.get(key) {
      Some(previous) =>
        if !form_duplicate_fields_consistent(previous, field) {
          raise form_error(object_id, "inconsistent duplicate field name")
        }
      None => index[key] = field
    }
  }
  fields.push(field)
  let child_inheritance = form_tree_inheritance_from_field(field)
  for kid in field.kids {
    collect_typed_form_fields(
      file, kid, child_inheritance, field_path, object_id, fields, index,
    )
  }
}

///|
fn parse_typed_form_field(
  file : PdfFile,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
  inherited : FormTreeInheritance,
  parent : @objects.ObjectId?,
) -> PdfFormField raise PdfDocumentError {
  let partial_name = form_optional_bytes(
    dict,
    form_key(b"T"),
    object_id,
    "field T",
  )
  if partial_name is Some(name) && form_bytes_contains(name, b'.') {
    raise form_error(object_id, "field T partial name must not contain PERIOD")
  }
  let field_type_name = form_inherit_name(
    form_optional_name(dict, form_key(b"FT"), object_id, "field FT"),
    inherited.field_type,
  )
  let flags = form_inherit_int(
    form_optional_int(dict, form_key(b"Ff"), object_id, "field Ff"),
    inherited.flags,
  )
  let value = form_inherit_object(dict.get(form_key(b"V")), inherited.value)
  let default_value = form_inherit_object(
    dict.get(form_key(b"DV")),
    inherited.default_value,
  )
  PdfFormField::{
    object_id,
    partial_name,
    fully_qualified_name: form_qualified_name_bytes(
      inherited.name,
      partial_name,
    ),
    field_type: match field_type_name {
      Some(name) => form_field_type_from_name(name)
      None => PdfFormFieldType::Absent
    },
    flags: PdfFormFieldFlags::{ bits: flags.unwrap_or(0) },
    value: form_field_value_from_object(value),
    default_value: form_field_value_from_object(default_value),
    parent,
    kids: form_optional_array_objects(
      file,
      dict,
      form_key(b"Kids"),
      "field Kids",
    ),
    widgets: [],
    variable_text: parse_variable_text_descriptor(dict, object_id),
    raw_dict: dict,
  }
}

///|
fn parse_variable_text_descriptor(
  dict : @objects.PdfDictionary,
  object_id : @objects.ObjectId?,
) -> PdfVariableTextDescriptor? raise PdfDocumentError {
  let default_appearance = form_optional_bytes(
    dict,
    form_key(b"DA"),
    object_id,
    "variable text DA",
  )
  let quadding = form_optional_int(
    dict,
    form_key(b"Q"),
    object_id,
    "variable text Q",
  )
  let default_style = form_optional_bytes(
    dict,
    form_key(b"DS"),
    object_id,
    "variable text DS",
  )
  let rich_text = dict.get(form_key(b"RV"))
  let default_resources = dict.get(form_key(b"DR"))
  if default_appearance is None &&
    quadding is None &&
    default_style is None &&
    rich_text is None &&
    default_resources is None {
    None
  } else {
    Some(PdfVariableTextDescriptor::{
      default_appearance,
      quadding,
      default_style,
      rich_text,
      default_resources,
      raw_dict: dict,
    })
  }
}

///|
fn form_tree_inheritance_from_field(
  field : PdfFormField,
) -> FormTreeInheritance {
  FormTreeInheritance::{
    name: field.fully_qualified_name,
    field_type: match field.field_type {
      Button => Some(form_key(b"Btn"))
      Text => Some(form_key(b"Tx"))
      Choice => Some(form_key(b"Ch"))
      Signature => Some(form_key(b"Sig"))
      Unknown(name) => Some(name)
      Absent => None
    },
    flags: Some(field.flags.bits),
    value: match field.value {
      Name(name) => Some(@objects.PdfObject::Name(name))
      String(bytes) => Some(@objects.PdfObject::String(bytes))
      Array(values) => Some(@objects.PdfObject::Array(values))
      Raw(object) => Some(object)
      Absent => None
    },
    default_value: match field.default_value {
      Name(name) => Some(@objects.PdfObject::Name(name))
      String(bytes) => Some(@objects.PdfObject::String(bytes))
      Array(values) => Some(@objects.PdfObject::Array(values))
      Raw(object) => Some(object)
      Absent => None
    },
  }
}

///|
fn form_duplicate_fields_consistent(
  left : PdfFormField,
  right : PdfFormField,
) -> Bool {
  left.field_type == right.field_type && left.flags.bits == right.flags.bits
}

///|
fn form_qualified_name_bytes(parent : Bytes?, partial : Bytes?) -> Bytes? {
  match partial {
    Some(name) =>
      match parent {
        Some(prefix) =>
          if prefix.length() == 0 {
            Some(name)
          } else if name.length() == 0 {
            Some(prefix)
          } else {
            Some(prefix + b"." + name)
          }
        None => Some(name)
      }
    None => parent
  }
}

///|
fn form_bytes_contains(bytes : Bytes, wanted : Byte) -> Bool {
  for byte in bytes {
    if byte == wanted {
      return true
    }
  }
  false
}

///|
fn form_bytes_to_text(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(byte.to_char())
  }
  String::from_array(chars)
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
