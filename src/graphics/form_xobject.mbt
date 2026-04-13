///|
pub(all) struct FormGroupInfo {
  subtype : @objects.PdfName?
  raw : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct ReferenceXObjectInfo {
  file_spec : @objects.PdfObject?
  page : @objects.PdfObject?
  id : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct FormXObject {
  name : @objects.PdfName?
  form_type : Int
  bbox : GraphicsRect
  matrix : GraphicsMatrix
  resources : @objects.PdfDictionary?
  group : FormGroupInfo?
  reference : ReferenceXObjectInfo?
  struct_parent : Int?
  struct_parents : Int?
  metadata : @objects.PdfObject?
  associated_files : @objects.PdfObject?
  oc : @objects.PdfObject?
  stream : @objects.PdfStream
} derive(Eq, Debug)

///|
pub fn validate_form_xobject(
  name : @objects.PdfName?,
  stream : @objects.PdfStream,
  offset : Int64,
) -> FormXObject raise PdfGraphicsError {
  require_type_marker(stream.dict, b"XObject", offset, "Form XObject")
  require_name_entry_value(
    stream.dict,
    b"Subtype",
    b"Form",
    offset,
    "Form Subtype",
  )
  let form_type = match optional_entry(stream.dict, b"FormType") {
    Some(value) => {
      let n = require_integer_value(value, offset, "FormType")
      if n != 1L {
        raise invalid_xobject(offset, "FormType must be 1")
      }
      1
    }
    None => 1
  }
  let struct_parent = image_optional_int(
    stream.dict,
    b"StructParent",
    offset,
    "StructParent",
  )
  let struct_parents = image_optional_int(
    stream.dict,
    b"StructParents",
    offset,
    "StructParents",
  )
  if struct_parent is Some(_) && struct_parents is Some(_) {
    raise invalid_xobject(
      offset, "Form XObject cannot contain both StructParent and StructParents",
    )
  }
  FormXObject::{
    name,
    form_type,
    bbox: required_graphics_rect(stream.dict, b"BBox", offset, "BBox"),
    matrix: optional_graphics_matrix(stream.dict, offset, "Form Matrix"),
    resources: optional_form_resources(stream.dict, offset),
    group: optional_group(stream.dict, offset),
    reference: optional_reference(stream.dict, offset),
    struct_parent,
    struct_parents,
    metadata: optional_entry(stream.dict, b"Metadata"),
    associated_files: optional_entry(stream.dict, b"AF"),
    oc: optional_entry(stream.dict, b"OC"),
    stream,
  }
}

///|
fn optional_form_resources(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> @objects.PdfDictionary? raise PdfGraphicsError {
  match optional_entry(dict, b"Resources") {
    Some(value) => Some(require_dictionary_value(value, offset, "Resources"))
    None => None
  }
}

///|
fn optional_group(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> FormGroupInfo? raise PdfGraphicsError {
  match optional_entry(dict, b"Group") {
    Some(value) => {
      let group = require_dictionary_value(value, offset, "Group")
      match optional_entry(group, b"Type") {
        Some(type_value) => {
          let type_name = require_name_value(type_value, offset, "Group Type")
          if type_name != pdf_name(b"Group") {
            raise invalid_xobject(offset, "Group Type must be Group")
          }
        }
        None => ()
      }
      Some(FormGroupInfo::{
        subtype: image_optional_name(group, b"S", offset, "Group subtype"),
        raw: group,
      })
    }
    None => None
  }
}

///|
fn optional_reference(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> ReferenceXObjectInfo? raise PdfGraphicsError {
  match optional_entry(dict, b"Ref") {
    Some(value) => {
      let ref_dict = require_dictionary_value(value, offset, "Ref")
      Some(ReferenceXObjectInfo::{
        file_spec: optional_entry(ref_dict, b"F"),
        page: optional_entry(ref_dict, b"Page"),
        id: optional_entry(ref_dict, b"ID"),
      })
    }
    None => None
  }
}

///|
fn invalid_xobject(offset : Int64, reason : String) -> PdfGraphicsError {
  PdfGraphicsError::InvalidXObject(offset, reason)
}
