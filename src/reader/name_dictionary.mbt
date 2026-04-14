///|
/// Resolves the optional Names entry in the Catalog dictionary as a name
/// dictionary.
pub fn PdfDocument::names_dict(
  self : PdfDocument,
) -> @objects.PdfDictionary? raise PdfDocumentError {
  match self.catalog.names_entry() {
    Some(value) => Some(resolve_names_dictionary_value(self.file, value))
    None => None
  }
}

///|
/// Returns the name-tree root for a Names dictionary category such as Dests,
/// AP, JavaScript, Pages, Templates, EmbeddedFiles, or AlternatePresentations.
pub fn PdfDocument::name_tree_root(
  self : PdfDocument,
  category : NameTreeCategory,
) -> @objects.PdfObject? raise PdfDocumentError {
  match self.names_dict() {
    Some(dict) => dict.get(name_tree_category_key(category))
    None => None
  }
}

///|
/// Looks up a string key in a Catalog Names dictionary name tree and returns
/// the mapped value, including Dests, AP, JavaScript, and Pages trees.
pub fn PdfDocument::lookup_name(
  self : PdfDocument,
  category : NameTreeCategory,
  key : Bytes,
) -> @objects.PdfObject? raise PdfDocumentError {
  match self.name_tree_root(category) {
    Some(root) => lookup_name_tree(self.file, root, key)
    None => None
  }
}

///|
/// Enumerates all key/value pairs in a Catalog name tree in exact byte-key
/// order. Exact lookup semantics are unchanged; enumeration reuses the same
/// node validation and cycle policy.
pub fn PdfDocument::name_tree_entries(
  self : PdfDocument,
  category : NameTreeCategory,
) -> Array[PdfNameTreeEntry] raise PdfDocumentError {
  match self.name_tree_root(category) {
    Some(root) => enumerate_name_tree(self.file, root)
    None => []
  }
}

///|
fn resolve_names_dictionary_value(
  file : PdfFile,
  value : @objects.PdfObject,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => dict
    @objects.PdfObject::Ref(object_id) => {
      let loaded = try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        value => value
      }
      match loaded {
        @objects.PdfObject::Dictionary(dict) => dict
        @objects.PdfObject::Null =>
          raise PdfDocumentError::InvalidNameTree(
            @objects.PdfName::new(b"Names"),
            "catalog /Names entry must be a dictionary",
          )
        _ =>
          raise PdfDocumentError::InvalidNameTree(
            @objects.PdfName::new(b"Names"),
            "catalog /Names entry must be a dictionary",
          )
      }
    }
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "catalog /Names entry must be a dictionary",
      )
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "catalog /Names entry must be a dictionary",
      )
  }
}

///|
fn lookup_name_tree(
  file : PdfFile,
  root : @objects.PdfObject,
  key : Bytes,
) -> @objects.PdfObject? raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  lookup_name_tree_object(file, root, key, seen)
}

///|
fn lookup_name_tree_object(
  file : PdfFile,
  node : @objects.PdfObject,
  key : Bytes,
  seen : Map[@objects.ObjectId, Bool],
) -> @objects.PdfObject? raise PdfDocumentError {
  match node {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "name tree cycle detected",
        )
      }
      seen[object_id] = true
      let loaded = try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        value => value
      }
      lookup_name_tree_object(file, loaded, key, seen)
    }
    @objects.PdfObject::Dictionary(dict) =>
      lookup_name_tree_dictionary(file, dict, key, seen)
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "name tree node must be a dictionary",
      )
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "name tree node must be a dictionary",
      )
  }
}

///|
fn lookup_name_tree_dictionary(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : Bytes,
  seen : Map[@objects.ObjectId, Bool],
) -> @objects.PdfObject? raise PdfDocumentError {
  let names_key = @objects.PdfName::new(b"Names")
  let kids_key = @objects.PdfName::new(b"Kids")
  let limits_key = @objects.PdfName::new(b"Limits")

  if should_prune_name_tree_node(dict, key, limits_key) {
    return None
  }

  match (dict.get(names_key), dict.get(kids_key)) {
    (Some(_), Some(_)) =>
      raise PdfDocumentError::InvalidNameTree(
        names_key, "name tree node must not contain both /Names and /Kids",
      )
    (Some(names_value), None) => lookup_name_tree_names(names_value, key)
    (None, Some(kids_value)) =>
      lookup_name_tree_kids(file, kids_value, key, seen)
    (None, None) =>
      raise PdfDocumentError::InvalidNameTree(
        names_key, "name tree node must have /Names or /Kids",
      )
  }
}

///|
fn should_prune_name_tree_node(
  dict : @objects.PdfDictionary,
  key : Bytes,
  limits_key : @objects.PdfName,
) -> Bool raise PdfDocumentError {
  match dict.get(limits_key) {
    Some(value) => {
      let (lower, upper) = try
        @common_data.validate_name_tree_limits(value)
      catch {
        error => raise name_tree_common_error(limits_key, error)
      } noraise {
        limits => limits
      }
      bytes_compare(key, lower) < 0 || bytes_compare(key, upper) > 0
    }
    None => false
  }
}

///|
fn lookup_name_tree_names(
  names_value : @objects.PdfObject,
  key : Bytes,
) -> @objects.PdfObject? raise PdfDocumentError {
  let entries = try @common_data.validate_name_tree_pairs(names_value) catch {
    error =>
      raise name_tree_common_error(@objects.PdfName::new(b"Names"), error)
  } noraise {
    values => values
  }
  let mut found : @objects.PdfObject? = None
  for entry in entries {
    if found is None && bytes_compare(entry.key, key) == 0 {
      found = Some(entry.value)
    }
  }
  found
}

///|
fn enumerate_name_tree(
  file : PdfFile,
  root : @objects.PdfObject,
) -> Array[PdfNameTreeEntry] raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  let entries : Array[PdfNameTreeEntry] = []
  enumerate_name_tree_object(file, root, seen, entries)
  sort_name_tree_entries(entries)
  reject_duplicate_name_tree_entries(entries)
  entries
}

///|
fn enumerate_name_tree_object(
  file : PdfFile,
  node : @objects.PdfObject,
  seen : Map[@objects.ObjectId, Bool],
  entries : Array[PdfNameTreeEntry],
) -> Unit raise PdfDocumentError {
  match node {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "name tree cycle detected",
        )
      }
      seen[object_id] = true
      let loaded = try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        value => value
      }
      enumerate_name_tree_object(file, loaded, seen, entries)
    }
    @objects.PdfObject::Dictionary(dict) =>
      enumerate_name_tree_dictionary(file, dict, seen, entries)
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "name tree node must be a dictionary",
      )
  }
}

///|
fn enumerate_name_tree_dictionary(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  seen : Map[@objects.ObjectId, Bool],
  entries : Array[PdfNameTreeEntry],
) -> Unit raise PdfDocumentError {
  let names_key = @objects.PdfName::new(b"Names")
  let kids_key = @objects.PdfName::new(b"Kids")
  match (dict.get(names_key), dict.get(kids_key)) {
    (Some(_), Some(_)) =>
      raise PdfDocumentError::InvalidNameTree(
        names_key, "name tree node must not contain both /Names and /Kids",
      )
    (Some(names_value), None) => enumerate_name_tree_names(names_value, entries)
    (None, Some(kids_value)) =>
      enumerate_name_tree_kids(file, kids_value, seen, entries)
    (None, None) =>
      raise PdfDocumentError::InvalidNameTree(
        names_key, "name tree node must have /Names or /Kids",
      )
  }
}

///|
fn enumerate_name_tree_names(
  names_value : @objects.PdfObject,
  entries : Array[PdfNameTreeEntry],
) -> Unit raise PdfDocumentError {
  let common_entries = try
    @common_data.validate_name_tree_pairs(names_value)
  catch {
    error =>
      raise name_tree_common_error(@objects.PdfName::new(b"Names"), error)
  } noraise {
    values => values
  }
  for entry in common_entries {
    entries.push(PdfNameTreeEntry::{ key: entry.key, value: entry.value })
  }
}

///|
fn enumerate_name_tree_kids(
  file : PdfFile,
  kids_value : @objects.PdfObject,
  seen : Map[@objects.ObjectId, Bool],
  entries : Array[PdfNameTreeEntry],
) -> Unit raise PdfDocumentError {
  let kids_array = match kids_value {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Kids"),
        "name tree /Kids entry must be an array",
      )
  }
  for kid in kids_array {
    match kid {
      @objects.PdfObject::Ref(object_id) => {
        if seen.contains(object_id) {
          raise PdfDocumentError::CycleDetected(
            object_id, "name tree cycle detected",
          )
        }
        seen[object_id] = true
        let loaded = try file.load_object(object_id) catch {
          error => raise PdfDocumentError::ReaderError(error)
        } noraise {
          value => value
        }
        enumerate_name_tree_object(file, loaded, seen, entries)
      }
      _ =>
        raise PdfDocumentError::InvalidNameTree(
          @objects.PdfName::new(b"Kids"),
          "name tree /Kids entries must be indirect references",
        )
    }
  }
}

///|
fn sort_name_tree_entries(entries : Array[PdfNameTreeEntry]) -> Unit {
  let mut index = 1
  while index < entries.length() {
    let current = entries[index]
    let mut slot = index
    while slot > 0 && bytes_compare(entries[slot - 1].key, current.key) > 0 {
      entries[slot] = entries[slot - 1]
      slot -= 1
    }
    entries[slot] = current
    index += 1
  }
}

///|
fn reject_duplicate_name_tree_entries(
  entries : Array[PdfNameTreeEntry],
) -> Unit raise PdfDocumentError {
  let mut index = 1
  while index < entries.length() {
    if bytes_compare(entries[index - 1].key, entries[index].key) == 0 {
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "name tree keys must be unique",
      )
    }
    index += 1
  }
}

///|
fn lookup_name_tree_kids(
  file : PdfFile,
  kids_value : @objects.PdfObject,
  key : Bytes,
  seen : Map[@objects.ObjectId, Bool],
) -> @objects.PdfObject? raise PdfDocumentError {
  let kids_key = @objects.PdfName::new(b"Kids")
  let kids_array = match kids_value {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        kids_key, "name tree /Kids entry must be an array",
      )
  }

  for kid in kids_array {
    let child_ref = match kid {
      @objects.PdfObject::Ref(object_id) => object_id
      _ =>
        raise PdfDocumentError::InvalidNameTree(
          kids_key, "name tree /Kids entries must be indirect references",
        )
    }

    if seen.contains(child_ref) {
      raise PdfDocumentError::CycleDetected(
        child_ref, "name tree cycle detected",
      )
    }

    seen[child_ref] = true
    let loaded = try file.load_object(child_ref) catch {
      error => raise PdfDocumentError::ReaderError(error)
    } noraise {
      value => value
    }
    match lookup_name_tree_object(file, loaded, key, seen) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn bytes_compare(left : Bytes, right : Bytes) -> Int {
  @common_data.compare_name_tree_keys(left, right)
}

///|
fn name_tree_category_key(category : NameTreeCategory) -> @objects.PdfName {
  match category {
    NameTreeCategory::Dests => @objects.PdfName::new(b"Dests")
    NameTreeCategory::AP => @objects.PdfName::new(b"AP")
    NameTreeCategory::JavaScript => @objects.PdfName::new(b"JavaScript")
    NameTreeCategory::Pages => @objects.PdfName::new(b"Pages")
    NameTreeCategory::Templates => @objects.PdfName::new(b"Templates")
    NameTreeCategory::EmbeddedFiles => @objects.PdfName::new(b"EmbeddedFiles")
    NameTreeCategory::AlternatePresentations =>
      @objects.PdfName::new(b"AlternatePresentations")
  }
}
