///|
enum StructuralDomain {
  Form
  FDF
  Signature
  Measure
  Requirement
  Multimedia
} derive(Eq, Debug)

///|
fn structural_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn structural_error(
  domain : StructuralDomain,
  object_id : @objects.ObjectId?,
  reason : String,
) -> PdfDocumentError {
  match domain {
    Form => PdfDocumentError::InvalidForm(object_id, reason)
    FDF => PdfDocumentError::InvalidFDF(object_id, reason)
    Signature => PdfDocumentError::InvalidSignature(object_id, reason)
    Measure => PdfDocumentError::InvalidMeasure(object_id, reason)
    Requirement => PdfDocumentError::InvalidRequirement(object_id, reason)
    Multimedia => PdfDocumentError::InvalidMultimedia(object_id, reason)
  }
}

///|
fn load_structural_object(
  file : PdfFile,
  object_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    value => value
  }
}

///|
fn structural_path_contains(
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId,
) -> Bool {
  for existing in path {
    if existing == object_id {
      return true
    }
  }
  false
}

///|
fn structural_copy_object_ids(
  source : Array[@objects.ObjectId],
) -> Array[@objects.ObjectId] {
  let copy : Array[@objects.ObjectId] = []
  for object_id in source {
    copy.push(object_id)
  }
  copy
}

///|
fn resolve_structural_object_path(
  file : PdfFile,
  value : @objects.PdfObject,
  domain : StructuralDomain,
  context : String,
  path : Array[@objects.ObjectId],
) -> (@objects.ObjectId?, @objects.PdfObject, Array[@objects.ObjectId]) raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if structural_path_contains(path, object_id) {
        raise structural_error(
          domain,
          Some(object_id),
          context + " indirect-object cycle detected",
        )
      }
      let next_path = structural_copy_object_ids(path)
      next_path.push(object_id)
      let loaded = load_structural_object(file, object_id)
      if loaded == @objects.PdfObject::Null {
        raise structural_error(
          domain,
          Some(object_id),
          context + " object is missing",
        )
      }
      let (_, resolved, final_path) = resolve_structural_object_path(
        file, loaded, domain, context, next_path,
      )
      (Some(object_id), resolved, final_path)
    }
    _ => (None, value, path)
  }
}

///|
fn resolve_structural_object(
  file : PdfFile,
  value : @objects.PdfObject,
  domain : StructuralDomain,
  context : String,
) -> (@objects.ObjectId?, @objects.PdfObject) raise PdfDocumentError {
  let (object_id, resolved, _) = resolve_structural_object_path(
    file,
    value,
    domain,
    context,
    [],
  )
  (object_id, resolved)
}

///|
fn require_structural_direct_object(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> Unit raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(_) =>
      raise structural_error(domain, owner, label + " must be a direct object")
    _ => ()
  }
}

///|
fn structural_dictionary(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise structural_error(domain, owner, label + " must be a dictionary")
  }
}

///|
fn structural_array(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) => values
    _ => raise structural_error(domain, owner, label + " must be an array")
  }
}

///|
fn structural_name(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ => raise structural_error(domain, owner, label + " must be a name")
  }
}

///|
fn structural_string(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ => raise structural_error(domain, owner, label + " must be a string")
  }
}

///|
fn structural_number(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> Double raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise structural_error(domain, owner, label + " must be a number")
  }
}

///|
fn structural_int(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> Int raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ => raise structural_error(domain, owner, label + " must be an integer")
  }
}

///|
fn structural_bool(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> Bool raise PdfDocumentError {
  match value {
    @objects.PdfObject::Boolean(value) => value
    _ => raise structural_error(domain, owner, label + " must be a boolean")
  }
}

///|
fn structural_ref(
  value : @objects.PdfObject,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.ObjectId raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => object_id
    _ =>
      raise structural_error(
        domain,
        owner,
        label + " must be an indirect reference",
      )
  }
}

///|
fn structural_optional_name(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  domain : StructuralDomain,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(structural_name(value, domain, owner, label))
    None => None
  }
}

///|
fn resolve_structural_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  domain : StructuralDomain,
  context : String,
) -> (@objects.ObjectId?, @objects.PdfDictionary) raise PdfDocumentError {
  let (object_id, resolved) = resolve_structural_object(
    file, value, domain, context,
  )
  (object_id, structural_dictionary(resolved, domain, object_id, context))
}

///|
fn resolve_structural_array(
  file : PdfFile,
  value : @objects.PdfObject,
  domain : StructuralDomain,
  context : String,
) -> (@objects.ObjectId?, Array[@objects.PdfObject]) raise PdfDocumentError {
  let (object_id, resolved) = resolve_structural_object(
    file, value, domain, context,
  )
  (object_id, structural_array(resolved, domain, object_id, context))
}
