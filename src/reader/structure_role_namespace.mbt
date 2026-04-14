///|
pub fn PdfStructureTree::namespaces(
  self : PdfStructureTree,
) -> Array[PdfStructureNamespace] {
  self.namespaces
}

///|
pub fn PdfStructureTree::resolve_structure_type(
  self : PdfStructureTree,
  element : PdfStructureElement,
) -> PdfResolvedStructureType raise PdfDocumentError {
  let role_map = match element.namespace_ref {
    Some(namespace_ref) => namespace_role_map(self.namespaces, namespace_ref)
    None => self.role_map
  }
  resolve_structure_name(
    element.structure_type,
    element.namespace_ref,
    role_map,
  )
}

///|
fn resolve_structure_name(
  original : @objects.PdfName,
  namespace_ref : @objects.ObjectId?,
  role_map : Map[@objects.PdfName, @objects.PdfName],
) -> PdfResolvedStructureType {
  let chain : Array[@objects.PdfName] = [original]
  let visited : Map[@objects.PdfName, Bool] = Map::new()
  visited[original] = true
  let mut current = original
  let mut cycle = false
  let mut done = false
  while !done {
    match role_map.get(current) {
      Some(next) =>
        if visited.contains(next) {
          chain.push(next)
          cycle = true
          done = true
        } else {
          chain.push(next)
          visited[next] = true
          current = next
        }
      None => done = true
    }
    if done && !cycle {
      match standard_structure_type(current) {
        Some(standard) =>
          return PdfResolvedStructureType::{
            original,
            namespace_ref,
            chain,
            standard_target: Some(standard),
            custom_terminal: None,
            cycle,
          }
        None => ()
      }
    }
  }
  PdfResolvedStructureType::{
    original,
    namespace_ref,
    chain,
    standard_target: None,
    custom_terminal: Some(current),
    cycle,
  }
}

///|
fn namespace_role_map(
  namespaces : Array[PdfStructureNamespace],
  namespace_ref : @objects.ObjectId,
) -> Map[@objects.PdfName, @objects.PdfName] {
  let role_map : Map[@objects.PdfName, @objects.PdfName] = Map::new()
  for ns in namespaces {
    if ns.object_id == Some(namespace_ref) {
      for entry in ns.role_map {
        role_map[entry.source] = entry.target
      }
    }
  }
  role_map
}

///|
fn parse_structure_role_map(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Map[@objects.PdfName, @objects.PdfName] raise PdfDocumentError {
  let (_, dict) = structure_resolve_dictionary(
    file, value, "structure /RoleMap",
  )
  let role_map : Map[@objects.PdfName, @objects.PdfName] = Map::new()
  for source, target in dict {
    role_map[source] = structure_name(
      target, owner, "structure /RoleMap target",
    )
  }
  role_map
}

///|
fn parse_structure_namespaces(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Array[PdfStructureNamespace] raise PdfDocumentError {
  let values = match value {
    @objects.PdfObject::Array(items) => items
    _ => raise structure_error(owner, "structure /Namespaces must be an array")
  }
  let namespaces : Array[PdfStructureNamespace] = []
  for item in values {
    let (object_id, dict) = structure_resolve_dictionary(
      file, item, "structure namespace",
    )
    namespaces.push(PdfStructureNamespace::{
      index: namespaces.length(),
      object_id,
      name: match dict.get(structure_key(b"NS")) {
        Some(raw) => Some(structure_string(raw, object_id, "namespace /NS"))
        None => None
      },
      schema: dict.get(structure_key(b"Schema")),
      role_map: match dict.get(structure_key(b"RoleMapNS")) {
        Some(raw) => parse_namespace_role_map(raw, object_id)
        None => []
      },
      raw_dict: dict,
    })
  }
  namespaces
}

///|
fn parse_namespace_role_map(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Array[PdfNamespaceRoleMapEntry] raise PdfDocumentError {
  let dict = match value {
    @objects.PdfObject::Dictionary(map) => map
    _ =>
      raise structure_error(owner, "namespace /RoleMapNS must be a dictionary")
  }
  let entries : Array[PdfNamespaceRoleMapEntry] = []
  for source, raw_target in dict {
    let (target, target_namespace_ref) = parse_namespace_role_target(
      raw_target, owner,
    )
    entries.push(PdfNamespaceRoleMapEntry::{
      source,
      target,
      target_namespace_ref,
      raw_target,
    })
  }
  entries
}

///|
fn parse_namespace_role_target(
  raw_target : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> (@objects.PdfName, @objects.ObjectId?) raise PdfDocumentError {
  match raw_target {
    @objects.PdfObject::Name(name) => (name, None)
    @objects.PdfObject::Array(values) => {
      if values.length() == 0 {
        raise structure_error(owner, "namespace role-map target array is empty")
      }
      let target = structure_name(values[0], owner, "namespace role-map target")
      let target_namespace_ref = if values.length() > 1 {
        Some(
          structure_ref(values[1], owner, "namespace role-map target namespace"),
        )
      } else {
        None
      }
      (target, target_namespace_ref)
    }
    _ =>
      raise structure_error(owner, "namespace role-map target must be a name")
  }
}
