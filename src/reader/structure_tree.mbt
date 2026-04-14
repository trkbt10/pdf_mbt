///|
pub fn PdfDocument::structure_tree(
  self : PdfDocument,
) -> PdfStructureTree? raise PdfDocumentError {
  match self.catalog.entry(structure_key(b"StructTreeRoot")) {
    None => None
    Some(root_value) => {
      let (root_object_id, root_dict) = structure_resolve_dictionary(
        self.file,
        root_value,
        "catalog /StructTreeRoot",
      )
      validate_structure_root_type(root_object_id, root_dict)
      let elements : Array[PdfStructureElement] = []
      let path : Array[@objects.ObjectId] = []
      let root_children = match root_dict.get(structure_key(b"K")) {
        Some(k_value) =>
          parse_structure_children(
            self.file,
            k_value,
            None,
            elements,
            path,
            true,
            root_object_id,
          )
        None => []
      }
      let id_tree_entries = match root_dict.get(structure_key(b"IDTree")) {
        Some(raw) => enumerate_name_tree(self.file, raw)
        None => []
      }
      let parent_tree_entries = match
        root_dict.get(structure_key(b"ParentTree")) {
        Some(raw) =>
          enumerate_number_tree(self.file, raw, structure_key(b"ParentTree"))
        None => []
      }
      let role_map = match root_dict.get(structure_key(b"RoleMap")) {
        Some(raw) => parse_structure_role_map(self.file, raw, root_object_id)
        None => Map::new()
      }
      let class_map = match root_dict.get(structure_key(b"ClassMap")) {
        Some(raw) => parse_structure_class_map(self.file, raw, root_object_id)
        None => []
      }
      let namespaces = match root_dict.get(structure_key(b"Namespaces")) {
        Some(raw) => parse_structure_namespaces(self.file, raw, root_object_id)
        None => []
      }
      Some(PdfStructureTree::{
        root_object_id,
        root_dict,
        root_children,
        elements,
        id_tree_entries,
        parent_tree_entries,
        parent_tree_next_key: match
          root_dict.get(structure_key(b"ParentTreeNextKey")) {
          Some(raw) =>
            Some(
              structure_int(raw, root_object_id, "structure /ParentTreeNextKey"),
            )
          None => None
        },
        role_map,
        class_map,
        namespaces,
        pronunciation_lexicons: parse_structure_object_list(
          root_dict.get(structure_key(b"PronunciationLexicon")),
        ),
        associated_files: root_dict.get(structure_key(b"AF")),
        document_language: self.document_language(),
        mark_info: self.mark_info(),
      })
    }
  }
}

///|
pub fn PdfStructureTree::elements(
  self : PdfStructureTree,
) -> Array[PdfStructureElement] {
  self.elements
}

///|
pub fn PdfStructureTree::element_by_id(
  self : PdfStructureTree,
  id : Bytes,
) -> PdfStructureElement? raise PdfDocumentError {
  for entry in self.id_tree_entries {
    if entry.key == id {
      let object_id = structure_ref(
        entry.value,
        self.root_object_id,
        "structure IDTree value",
      )
      for element in self.elements {
        if element.object_id == Some(object_id) {
          return Some(element)
        }
      }
      raise structure_error(
        Some(object_id),
        "IDTree value does not reference a parsed structure element",
      )
    }
  }
  for element in self.elements {
    if element.id == Some(id) {
      return Some(element)
    }
  }
  None
}

///|
pub fn PdfStructureTree::parent_for_object(
  self : PdfStructureTree,
  key : Int,
) -> PdfStructureParentLookup? raise PdfDocumentError {
  match structure_number_tree_entry(self.parent_tree_entries, key) {
    Some(entry) => Some(parent_lookup_from_value(self, entry.value))
    None => None
  }
}

///|
pub fn PdfStructureTree::parent_for_mcid(
  self : PdfStructureTree,
  struct_parents_key : Int,
  mcid : Int,
) -> PdfStructureParentLookup? raise PdfDocumentError {
  match
    structure_number_tree_entry(self.parent_tree_entries, struct_parents_key) {
    Some(entry) => {
      let array = match entry.value {
        @objects.PdfObject::Array(values) => values
        _ =>
          raise structure_error(
            self.root_object_id,
            "ParentTree marked-content value must be an array",
          )
      }
      if mcid < 0 || mcid >= array.length() {
        return None
      }
      Some(parent_lookup_from_value(self, array[mcid]))
    }
    None => None
  }
}

///|
fn validate_structure_root_type(
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> Unit raise PdfDocumentError {
  match dict.get(structure_key(b"Type")) {
    Some(value) => {
      let type_name = structure_name(value, object_id, "structure root /Type")
      if type_name != structure_key(b"StructTreeRoot") {
        raise structure_error(
          object_id, "structure root /Type must be /StructTreeRoot",
        )
      }
    }
    None => ()
  }
}

///|
fn parse_structure_children(
  file : PdfFile,
  value : @objects.PdfObject,
  page_ref : @objects.ObjectId?,
  elements : Array[PdfStructureElement],
  path : Array[@objects.ObjectId],
  root_context : Bool,
  root_object_id : @objects.ObjectId?,
) -> Array[PdfStructureChild] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) => {
      let children : Array[PdfStructureChild] = []
      for item in values {
        children.push(
          parse_structure_child(
            file, item, page_ref, elements, path, root_context, root_object_id,
          ),
        )
      }
      children
    }
    _ =>
      [
        parse_structure_child(
          file, value, page_ref, elements, path, root_context, root_object_id,
        ),
      ]
  }
}

///|
fn parse_structure_child(
  file : PdfFile,
  value : @objects.PdfObject,
  page_ref : @objects.ObjectId?,
  elements : Array[PdfStructureElement],
  path : Array[@objects.ObjectId],
  root_context : Bool,
  root_object_id : @objects.ObjectId?,
) -> PdfStructureChild raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) =>
      if root_context {
        PdfStructureChild::Diagnostic(
          structure_diagnostic(
            b"InvalidRootChild",
            "structure root /K cannot directly contain an MCID",
            None,
            Some(value),
          ),
        )
      } else {
        PdfStructureChild::Content(
          PdfStructureContentItem::MCID(PdfMarkedContentIdentifier::{
            mcid: number.to_int(),
            page_ref,
            raw_object: value,
          }),
        )
      }
    @objects.PdfObject::Dictionary(dict) =>
      parse_structure_dictionary_child(
        file,
        value,
        None,
        dict,
        page_ref,
        elements,
        path,
        root_object_id,
      )
    @objects.PdfObject::Ref(object_id) => {
      let loaded = structure_load_object(file, object_id)
      match loaded {
        @objects.PdfObject::Dictionary(dict) =>
          parse_structure_dictionary_child(
            file,
            loaded,
            Some(object_id),
            dict,
            page_ref,
            elements,
            path,
            root_object_id,
          )
        _ =>
          raise structure_error(
            Some(object_id),
            "structure child reference must resolve to a dictionary",
          )
      }
    }
    _ =>
      PdfStructureChild::Diagnostic(
        structure_diagnostic(
          b"InvalidChild",
          "structure /K child has unsupported shape",
          None,
          Some(value),
        ),
      )
  }
}

///|
fn parse_structure_dictionary_child(
  file : PdfFile,
  raw_object : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
  page_ref : @objects.ObjectId?,
  elements : Array[PdfStructureElement],
  path : Array[@objects.ObjectId],
  root_object_id : @objects.ObjectId?,
) -> PdfStructureChild raise PdfDocumentError {
  match dict.get(structure_key(b"Type")) {
    Some(@objects.PdfObject::Name(name)) if name == structure_key(b"MCR") =>
      PdfStructureChild::Content(
        PdfStructureContentItem::MCR(
          parse_marked_content_reference(dict, object_id, page_ref),
        ),
      )
    Some(@objects.PdfObject::Name(name)) if name == structure_key(b"OBJR") =>
      PdfStructureChild::Content(
        PdfStructureContentItem::OBJR(
          parse_object_reference_content(dict, object_id),
        ),
      )
    _ =>
      if dict.get(structure_key(b"MCID")) is Some(_) &&
        dict.get(structure_key(b"S")) is None {
        PdfStructureChild::Content(
          PdfStructureContentItem::MCR(
            parse_marked_content_reference(dict, object_id, page_ref),
          ),
        )
      } else {
        let index = parse_structure_element_dictionary(
          file, raw_object, object_id, dict, elements, path, root_object_id,
        )
        PdfStructureChild::Element(index, object_id)
      }
  }
}

///|
fn parse_structure_element_dictionary(
  file : PdfFile,
  _raw_object : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
  elements : Array[PdfStructureElement],
  path : Array[@objects.ObjectId],
  root_object_id : @objects.ObjectId?,
) -> Int raise PdfDocumentError {
  match object_id {
    Some(id) =>
      for existing in path {
        if existing == id {
          raise PdfDocumentError::CycleDetected(
            id, "structure element cycle detected",
          )
        }
      }
    None => ()
  }
  validate_structure_element_type(object_id, dict)
  let structure_type = match dict.get(structure_key(b"S")) {
    Some(value) => structure_name(value, object_id, "structure element /S")
    None => raise structure_error(object_id, "structure element is missing /S")
  }
  let parent = match dict.get(structure_key(b"P")) {
    Some(@objects.PdfObject::Ref(parent_ref)) =>
      if Some(parent_ref) == root_object_id {
        PdfStructureParent::Root
      } else {
        PdfStructureParent::Element(Some(parent_ref))
      }
    Some(value) => PdfStructureParent::Raw(value)
    None => raise structure_error(object_id, "structure element is missing /P")
  }
  let element_page_ref = match dict.get(structure_key(b"Pg")) {
    Some(value) =>
      Some(structure_ref(value, object_id, "structure element /Pg"))
    None => None
  }
  let accessibility = parse_accessibility_properties(dict, object_id)
  let attributes = match dict.get(structure_key(b"A")) {
    Some(value) =>
      parse_structure_attribute_objects(
        file, value, object_id, "structure element /A",
      )
    None => []
  }
  let class_refs = match dict.get(structure_key(b"C")) {
    Some(value) => parse_structure_class_refs(value, object_id)
    None => []
  }
  let namespace_ref = match dict.get(structure_key(b"NS")) {
    Some(value) =>
      Some(structure_ref(value, object_id, "structure element /NS"))
    None => None
  }
  let index = elements.length()
  let element = PdfStructureElement::{
    index,
    object_id,
    structure_type,
    parent,
    id: match dict.get(structure_key(b"ID")) {
      Some(value) =>
        Some(structure_string(value, object_id, "structure element /ID"))
      None => None
    },
    references: dict.get(structure_key(b"Ref")),
    page_ref: element_page_ref,
    children: [],
    attributes,
    class_refs,
    revision: structure_optional_int(
      dict,
      structure_key(b"R"),
      object_id,
      "structure element /R",
    ),
    title: structure_optional_string(
      dict,
      structure_key(b"T"),
      object_id,
      "structure element /T",
    ),
    language: structure_optional_string(
      dict,
      structure_key(b"Lang"),
      object_id,
      "structure element /Lang",
    ),
    accessibility,
    namespace_ref,
    associated_files: dict.get(structure_key(b"AF")),
    raw_dict: dict,
    diagnostics: [],
  }
  elements.push(element)
  let child_path = structure_child_path(path, object_id)
  let children = match dict.get(structure_key(b"K")) {
    Some(k_value) =>
      parse_structure_children(
        file, k_value, element_page_ref, elements, child_path, false, root_object_id,
      )
    None => []
  }
  elements[index] = PdfStructureElement::{
    index,
    object_id,
    structure_type,
    parent: element.parent,
    id: element.id,
    references: element.references,
    page_ref: element_page_ref,
    children,
    attributes: element.attributes,
    class_refs: element.class_refs,
    revision: element.revision,
    title: element.title,
    language: element.language,
    accessibility: element.accessibility,
    namespace_ref,
    associated_files: element.associated_files,
    raw_dict: dict,
    diagnostics: element.diagnostics,
  }
  index
}

///|
fn validate_structure_element_type(
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> Unit raise PdfDocumentError {
  match dict.get(structure_key(b"Type")) {
    Some(value) => {
      let type_name = structure_name(
        value, object_id, "structure element /Type",
      )
      if type_name != structure_key(b"StructElem") {
        raise structure_error(
          object_id, "structure element /Type must be /StructElem",
        )
      }
    }
    None => ()
  }
}

///|
fn structure_child_path(
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId?,
) -> Array[@objects.ObjectId] {
  let next : Array[@objects.ObjectId] = []
  for existing in path {
    next.push(existing)
  }
  match object_id {
    Some(id) => next.push(id)
    None => ()
  }
  next
}

///|
fn parse_marked_content_reference(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
  inherited_page_ref : @objects.ObjectId?,
) -> PdfMarkedContentReference raise PdfDocumentError {
  let mcid = match dict.get(structure_key(b"MCID")) {
    Some(value) => structure_int(value, owner, "marked-content reference /MCID")
    None =>
      raise structure_error(owner, "marked-content reference missing /MCID")
  }
  PdfMarkedContentReference::{
    mcid,
    page_ref: match dict.get(structure_key(b"Pg")) {
      Some(value) =>
        Some(structure_ref(value, owner, "marked-content reference /Pg"))
      None => inherited_page_ref
    },
    stream_ref: structure_optional_ref(
      dict,
      structure_key(b"Stm"),
      owner,
      "marked-content reference /Stm",
    ),
    stream_owner_ref: structure_optional_ref(
      dict,
      structure_key(b"StmOwn"),
      owner,
      "marked-content reference /StmOwn",
    ),
    raw_dict: dict,
  }
}

///|
fn parse_object_reference_content(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfObjectReferenceContent raise PdfDocumentError {
  let object_ref = match dict.get(structure_key(b"Obj")) {
    Some(value) => structure_ref(value, owner, "object reference /Obj")
    None => raise structure_error(owner, "object reference missing /Obj")
  }
  PdfObjectReferenceContent::{
    object_ref,
    page_ref: structure_optional_ref(
      dict,
      structure_key(b"Pg"),
      owner,
      "object reference /Pg",
    ),
    raw_dict: dict,
  }
}

///|
fn parent_lookup_from_value(
  tree : PdfStructureTree,
  value : @objects.PdfObject,
) -> PdfStructureParentLookup raise PdfDocumentError {
  let element_ref = match value {
    @objects.PdfObject::Ref(object_id) => Some(object_id)
    @objects.PdfObject::Dictionary(dict) =>
      find_structure_element_by_dict(tree.elements, dict)
    @objects.PdfObject::Null => None
    _ =>
      raise structure_error(
        tree.root_object_id,
        "ParentTree value must reference a structure element",
      )
  }
  PdfStructureParentLookup::{
    element_index: find_structure_element_index(tree.elements, element_ref),
    element_ref,
    raw_value: value,
  }
}

///|
fn find_structure_element_index(
  elements : Array[PdfStructureElement],
  object_id : @objects.ObjectId?,
) -> Int? {
  match object_id {
    Some(id) => {
      for element in elements {
        if element.object_id == Some(id) {
          return Some(element.index)
        }
      }
      None
    }
    None => None
  }
}

///|
fn find_structure_element_by_dict(
  elements : Array[PdfStructureElement],
  dict : @objects.PdfDictionary,
) -> @objects.ObjectId? {
  for element in elements {
    if element.raw_dict == dict {
      return element.object_id
    }
  }
  None
}

///|
fn structure_number_tree_entry(
  entries : Array[PdfNumberTreeEntry],
  key : Int,
) -> PdfNumberTreeEntry? {
  for entry in entries {
    if entry.key == key {
      return Some(entry)
    }
  }
  None
}

///|
fn parse_structure_object_list(
  value : @objects.PdfObject?,
) -> Array[@objects.PdfObject] {
  match value {
    Some(@objects.PdfObject::Array(values)) => values
    Some(raw) => [raw]
    None => []
  }
}
