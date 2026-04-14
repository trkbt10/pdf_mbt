///|
pub fn PdfStructureElement::attributes(
  self : PdfStructureElement,
) -> Array[PdfStructureAttributeObject] {
  self.attributes
}

///|
pub fn PdfStructureElement::user_properties(
  self : PdfStructureElement,
) -> Array[PdfUserProperty] raise PdfDocumentError {
  let properties : Array[PdfUserProperty] = []
  for attribute in self.attributes {
    for property in attribute.user_properties {
      properties.push(property)
    }
  }
  properties
}

///|
pub fn PdfStructureTree::resolved_attributes(
  self : PdfStructureTree,
  element : PdfStructureElement,
) -> Array[PdfResolvedAttribute] raise PdfDocumentError {
  let resolved : Array[PdfResolvedAttribute] = []
  append_resolved_attribute_objects(
    resolved,
    element.attributes,
    PdfStructureAttributeSourceKind::Direct,
    false,
    false,
  )
  for class_ref in element.class_refs {
    for entry in self.class_map {
      if entry.name == class_ref.name {
        append_resolved_attribute_objects(
          resolved,
          entry.attributes,
          PdfStructureAttributeSourceKind::ClassMap(class_ref.name),
          false,
          false,
        )
      }
    }
  }
  resolved
}

///|
fn append_resolved_attribute_objects(
  out : Array[PdfResolvedAttribute],
  attributes : Array[PdfStructureAttributeObject],
  source : PdfStructureAttributeSourceKind,
  inherited : Bool,
  defaulted : Bool,
) -> Unit {
  for attribute in attributes {
    match attribute.raw_dict {
      Some(dict) =>
        for key, value in dict {
          if key != structure_key(b"O") &&
            key != structure_key(b"NSO") &&
            key != structure_key(b"P") {
            out.push(PdfResolvedAttribute::{
              key,
              value,
              owner: attribute.owner,
              namespace_owner: attribute.namespace_owner,
              source,
              inherited,
              defaulted,
              revision: attribute.revision,
              raw_origin: attribute.raw_object,
            })
          }
        }
      None => ()
    }
  }
}

///|
fn parse_structure_attribute_objects(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[PdfStructureAttributeObject] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) =>
      parse_structure_attribute_array(file, values, owner, label)
    _ => [parse_structure_attribute_object(file, value, owner, None, label)]
  }
}

///|
fn parse_structure_attribute_array(
  file : PdfFile,
  values : Array[@objects.PdfObject],
  owner : @objects.ObjectId?,
  label : String,
) -> Array[PdfStructureAttributeObject] raise PdfDocumentError {
  let attributes : Array[PdfStructureAttributeObject] = []
  let mut index = 0
  while index < values.length() {
    let candidate = values[index]
    match candidate {
      @objects.PdfObject::Integer(_) =>
        raise structure_error(
          owner,
          label + " revision number must follow an attribute object",
        )
      _ => {
        let mut revision : Int? = None
        if index + 1 < values.length() {
          match values[index + 1] {
            @objects.PdfObject::Integer(number) => {
              revision = Some(number.to_int())
              index += 1
            }
            _ => ()
          }
        }
        attributes.push(
          parse_structure_attribute_object(
            file, candidate, owner, revision, label,
          ),
        )
      }
    }
    index += 1
  }
  attributes
}

///|
fn parse_structure_attribute_object(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  revision : Int?,
  label : String,
) -> PdfStructureAttributeObject raise PdfDocumentError {
  let (object_id, resolved) = structure_resolve_object(
    file,
    value,
    label,
    Map::new(),
  )
  match resolved {
    @objects.PdfObject::Dictionary(dict) =>
      build_structure_attribute_from_dict(
        dict,
        @objects.PdfObject::Dictionary(dict),
        None,
        structure_owner_or(object_id, owner),
        revision,
        label,
      )
    @objects.PdfObject::Stream(stream) =>
      build_structure_attribute_from_dict(
        stream.dict,
        @objects.PdfObject::Stream(stream),
        Some(stream),
        structure_owner_or(object_id, owner),
        revision,
        label,
      )
    _ => raise structure_error(owner, label + " must be a dictionary or stream")
  }
}

///|
fn structure_owner_or(
  first : @objects.ObjectId?,
  second : @objects.ObjectId?,
) -> @objects.ObjectId? {
  match first {
    Some(value) => Some(value)
    None => second
  }
}

///|
fn build_structure_attribute_from_dict(
  dict : @objects.PdfDictionary,
  raw_object : @objects.PdfObject,
  raw_stream : @objects.PdfStream?,
  owner : @objects.ObjectId?,
  revision : Int?,
  label : String,
) -> PdfStructureAttributeObject raise PdfDocumentError {
  let attribute_owner = match dict.get(structure_key(b"O")) {
    Some(value) => Some(structure_name(value, owner, label + " /O"))
    None =>
      raise structure_error(owner, label + " is missing required /O owner")
  }
  let namespace_owner = match dict.get(structure_key(b"NSO")) {
    Some(value) => Some(structure_ref(value, owner, label + " /NSO"))
    None => None
  }
  let user_properties = if attribute_owner ==
    Some(structure_key(b"UserProperties")) {
    parse_user_properties(dict, owner, label)
  } else {
    []
  }
  PdfStructureAttributeObject::{
    owner: attribute_owner,
    namespace_owner,
    revision,
    raw_object,
    raw_dict: Some(dict),
    raw_stream,
    user_properties,
  }
}

///|
fn parse_user_properties(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[PdfUserProperty] raise PdfDocumentError {
  let value = match dict.get(structure_key(b"P")) {
    Some(value) => value
    None => raise structure_error(owner, label + " user properties missing /P")
  }
  let array = match value {
    @objects.PdfObject::Array(values) => values
    _ => raise structure_error(owner, label + " /P must be an array")
  }
  let properties : Array[PdfUserProperty] = []
  for item in array {
    let prop_dict = match item {
      @objects.PdfObject::Dictionary(value) => value
      _ =>
        raise structure_error(owner, label + " property must be a dictionary")
    }
    let name = match prop_dict.get(structure_key(b"N")) {
      Some(value) => structure_string(value, owner, label + " property /N")
      None => raise structure_error(owner, label + " property missing /N")
    }
    let property_value = match prop_dict.get(structure_key(b"V")) {
      Some(value) => value
      None => raise structure_error(owner, label + " property missing /V")
    }
    let formatted_value = match prop_dict.get(structure_key(b"F")) {
      Some(value) =>
        Some(structure_string(value, owner, label + " property /F"))
      None => None
    }
    let hidden = match prop_dict.get(structure_key(b"H")) {
      Some(value) => structure_bool(value, owner, label + " property /H")
      None => false
    }
    properties.push(PdfUserProperty::{
      name,
      value: property_value,
      formatted_value,
      hidden,
      raw_dict: prop_dict,
    })
  }
  properties
}

///|
fn parse_structure_class_refs(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Array[PdfStructureClassReference] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) =>
      [
        PdfStructureClassReference::{
          name: name.bytes,
          revision: None,
          raw_object: value,
        },
      ]
    @objects.PdfObject::String(bytes) =>
      [
        PdfStructureClassReference::{
          name: bytes,
          revision: None,
          raw_object: value,
        },
      ]
    @objects.PdfObject::Array(values) =>
      parse_structure_class_ref_array(values, owner)
    _ =>
      raise structure_error(
        owner, "structure element /C must be a name, string, or array",
      )
  }
}

///|
fn parse_structure_class_ref_array(
  values : Array[@objects.PdfObject],
  owner : @objects.ObjectId?,
) -> Array[PdfStructureClassReference] raise PdfDocumentError {
  let refs : Array[PdfStructureClassReference] = []
  let mut index = 0
  while index < values.length() {
    let raw = values[index]
    let name = match raw {
      @objects.PdfObject::Name(value) => value.bytes
      @objects.PdfObject::String(value) => value
      _ =>
        raise structure_error(
          owner, "structure class entry must be a name or string",
        )
    }
    let mut revision : Int? = None
    if index + 1 < values.length() {
      match values[index + 1] {
        @objects.PdfObject::Integer(number) => {
          revision = Some(number.to_int())
          index += 1
        }
        _ => ()
      }
    }
    refs.push(PdfStructureClassReference::{ name, revision, raw_object: raw })
    index += 1
  }
  refs
}

///|
fn parse_structure_class_map(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Array[PdfStructureClassMapEntry] raise PdfDocumentError {
  let (_, dict) = structure_resolve_dictionary(
    file, value, "structure /ClassMap",
  )
  let entries : Array[PdfStructureClassMapEntry] = []
  for name, raw_value in dict {
    entries.push(PdfStructureClassMapEntry::{
      name: name.bytes,
      attributes: parse_structure_attribute_objects(
        file, raw_value, owner, "structure /ClassMap",
      ),
      raw_value,
    })
  }
  entries
}
