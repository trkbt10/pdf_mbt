///|
fn parse_file_spec_dictionary(
  file : PdfFile,
  source : PdfResolvedFileSpecObject,
) -> PdfFileSpecificationDictionary raise PdfDocumentError {
  let owner = source.source_object_id
  let dict = match source.object {
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise file_spec_error(
        owner, "full file specification must be a dictionary",
      )
  }
  let type_required = dict.get(file_spec_key(b"EF")) is Some(_) ||
    dict.get(file_spec_key(b"RF")) is Some(_) ||
    dict.get(file_spec_key(b"EP")) is Some(_)
  validate_file_spec_type(dict, owner, type_required)
  if type_required && !source.indirect {
    raise file_spec_error(
      owner, "file specification with EF, RF, or EP must be indirect",
    )
  }

  let file_system = parse_file_spec_file_system(dict, owner)
  let is_url = match file_system {
    Some(PdfFileSpecFileSystem::URL) => true
    _ => false
  }
  let f = parse_optional_name_entry(dict, b"F", owner, is_url)
  let uf = parse_optional_name_entry(dict, b"UF", owner, false)
  let dos = parse_optional_name_entry(dict, b"DOS", owner, false)
  let mac = parse_optional_name_entry(dict, b"Mac", owner, false)
  let unix = parse_optional_name_entry(dict, b"Unix", owner, false)
  if f is None && uf is None && dos is None && mac is None && unix is None {
    raise file_spec_error(owner, "file specification must contain a file name")
  }
  let selected_file_name = match uf {
    Some(entry) => Some(entry)
    None => f
  }
  let file_identifier = parse_file_spec_identifier(dict, owner)
  let is_volatile = match dict.get(file_spec_key(b"V")) {
    Some(object) => file_spec_boolean(object, owner, "file specification V")
    None => false
  }
  let embedded_files = parse_embedded_file_mapping(file, dict, owner)
  let related_files = parse_related_file_mapping(
    file, dict, embedded_files, owner,
  )
  let description = match dict.get(file_spec_key(b"Desc")) {
    Some(object) =>
      Some(file_spec_string(object, owner, "file specification Desc"))
    None => None
  }
  let collection_item = match dict.get(file_spec_key(b"CI")) {
    Some(object) => Some(parse_collection_item(file, object, owner))
    None => None
  }
  let thumbnail = match dict.get(file_spec_key(b"Thumb")) {
    Some(object) =>
      Some(
        parse_file_spec_stream_descriptor(
          file, object, owner, "file specification Thumb",
        ),
      )
    None => None
  }
  let encrypted_payload = match dict.get(file_spec_key(b"EP")) {
    Some(object) => Some(parse_encrypted_payload(file, object, owner))
    None => None
  }
  let associated_relationship = match
    dict.get(file_spec_key(b"AFRelationship")) {
    Some(object) =>
      parse_associated_file_relationship(
        file_spec_name(object, owner, "file specification AFRelationship"),
      )
    None => PdfAssociatedFileRelationship::Unspecified
  }
  PdfFileSpecificationDictionary::{
    source_object_id: source.source_object_id,
    indirect: source.indirect,
    file_system,
    f,
    uf,
    dos,
    mac,
    unix,
    selected_file_name,
    file_identifier,
    is_volatile,
    embedded_files,
    related_files,
    description,
    collection_item,
    thumbnail,
    encrypted_payload,
    associated_relationship,
    raw_dict: dict,
    raw_object: source.raw_object,
  }
}

///|
fn validate_file_spec_type(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
  required : Bool,
) -> Unit raise PdfDocumentError {
  match dict.get(file_spec_key(b"Type")) {
    Some(object) => {
      let type_name = file_spec_name(object, owner, "file specification Type")
      if type_name != file_spec_key(b"Filespec") {
        raise file_spec_error(owner, "file specification Type must be Filespec")
      }
    }
    None =>
      if required {
        raise file_spec_error(owner, "file specification Type is required")
      }
  }
}

///|
fn parse_file_spec_file_system(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfFileSpecFileSystem? raise PdfDocumentError {
  match dict.get(file_spec_key(b"FS")) {
    Some(object) => {
      let name = file_spec_name(object, owner, "file specification FS")
      if name == file_spec_key(b"URL") {
        Some(PdfFileSpecFileSystem::URL)
      } else {
        Some(PdfFileSpecFileSystem::Other(name))
      }
    }
    None => None
  }
}

///|
fn parse_optional_name_entry(
  dict : @objects.PdfDictionary,
  key_bytes : Bytes,
  owner : @objects.ObjectId?,
  raw_url : Bool,
) -> PdfFileSpecNameEntry? raise PdfDocumentError {
  match dict.get(file_spec_key(key_bytes)) {
    Some(object) => {
      let bytes = file_spec_string(
        object,
        owner,
        "file specification " + file_spec_key(key_bytes).to_text(),
      )
      let path : PdfFileSpecPath? = if raw_url {
        None
      } else {
        Some(parse_file_spec_path(bytes))
      }
      Some(PdfFileSpecNameEntry::{ raw: bytes, path })
    }
    None => None
  }
}

///|
fn parse_file_spec_identifier(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfFileSpecIdentifier? raise PdfDocumentError {
  match dict.get(file_spec_key(b"ID")) {
    Some(object) => {
      let values = file_spec_array(object, owner, "file specification ID")
      if values.length() != 2 {
        raise file_spec_error(
          owner, "file specification ID must have two strings",
        )
      }
      Some(PdfFileSpecIdentifier::{
        first: file_spec_string(values[0], owner, "file specification ID first"),
        second: file_spec_string(
          values[1],
          owner,
          "file specification ID second",
        ),
        raw_array: values,
      })
    }
    None => None
  }
}

///|
fn parse_embedded_file_mapping(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> Map[@objects.PdfName, PdfEmbeddedFile] raise PdfDocumentError {
  let out : Map[@objects.PdfName, PdfEmbeddedFile] = Map::new()
  match dict.get(file_spec_key(b"EF")) {
    Some(object) => {
      let ef_dict = file_spec_dictionary(object, owner, "file specification EF")
      ef_dict.each((key, value) => {
        out[key] = parse_embedded_file_stream(file, key, value, owner)
      })
    }
    None => ()
  }
  out
}

///|
fn parse_related_file_mapping(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  embedded_files : Map[@objects.PdfName, PdfEmbeddedFile],
  owner : @objects.ObjectId?,
) -> Map[@objects.PdfName, Array[PdfRelatedFile]] raise PdfDocumentError {
  match dict.get(file_spec_key(b"RF")) {
    Some(object) => {
      if embedded_files.length() == 0 {
        raise file_spec_error(owner, "RF requires EF")
      }
      let rf_dict = file_spec_dictionary(object, owner, "file specification RF")
      parse_related_files(file, rf_dict, embedded_files, owner)
    }
    None => Map::new()
  }
}

///|
fn parse_collection_item(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfCollectionItem raise PdfDocumentError {
  let object_id = match value {
    @objects.PdfObject::Ref(id) => id
    _ => raise file_spec_error(owner, "file specification CI must be indirect")
  }
  let resolved = resolve_file_spec_child_object(
    file, value, owner, "collection item",
  )
  let dict = file_spec_dictionary(
    resolved.object,
    owner,
    "file specification CI",
  )
  match dict.get(file_spec_key(b"Type")) {
    Some(object) => {
      let type_name = file_spec_name(object, owner, "collection item Type")
      if type_name != file_spec_key(b"CollectionItem") {
        raise file_spec_error(
          owner, "collection item Type must be CollectionItem",
        )
      }
    }
    None => ()
  }
  PdfCollectionItem::{
    source_object_id: object_id,
    raw_dict: dict,
    raw_object: resolved.raw_object,
  }
}

///|
fn parse_encrypted_payload(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfEncryptedPayload raise PdfDocumentError {
  let resolved = resolve_file_spec_child_object(
    file, value, owner, "encrypted payload dictionary",
  )
  let dict = file_spec_dictionary(
    resolved.object,
    owner,
    "file specification EP",
  )
  PdfEncryptedPayload::{
    source_object_id: resolved.source_object_id,
    raw_dict: dict,
    raw_object: resolved.raw_object,
  }
}

///|
fn parse_associated_file_relationship(
  name : @objects.PdfName,
) -> PdfAssociatedFileRelationship {
  if name == file_spec_key(b"Source") {
    PdfAssociatedFileRelationship::Source
  } else if name == file_spec_key(b"Data") {
    PdfAssociatedFileRelationship::Data
  } else if name == file_spec_key(b"Alternative") {
    PdfAssociatedFileRelationship::Alternative
  } else if name == file_spec_key(b"Supplement") {
    PdfAssociatedFileRelationship::Supplement
  } else if name == file_spec_key(b"EncryptedPayload") {
    PdfAssociatedFileRelationship::EncryptedPayload
  } else if name == file_spec_key(b"FormData") {
    PdfAssociatedFileRelationship::FormData
  } else if name == file_spec_key(b"Schema") {
    PdfAssociatedFileRelationship::Schema
  } else if name == file_spec_key(b"Unspecified") {
    PdfAssociatedFileRelationship::Unspecified
  } else {
    PdfAssociatedFileRelationship::Other(name)
  }
}
