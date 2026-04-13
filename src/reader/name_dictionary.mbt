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
      let (lower, upper) = parse_name_tree_limits(value)
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
  let names_array = match names_value {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "name tree /Names entry must be an array",
      )
  }

  if names_array.length() % 2 != 0 {
    raise PdfDocumentError::InvalidNameTree(
      @objects.PdfName::new(b"Names"),
      "name tree /Names array must contain key/value pairs",
    )
  }

  let mut found : @objects.PdfObject? = None
  let mut index = 0
  while index < names_array.length() {
    let tree_key = match names_array[index] {
      @objects.PdfObject::String(bytes) => bytes
      _ =>
        raise PdfDocumentError::InvalidNameTree(
          @objects.PdfName::new(b"Names"),
          "name tree /Names keys must be strings",
        )
    }
    let tree_value = names_array[index + 1]
    if found is None && bytes_compare(tree_key, key) == 0 {
      found = Some(tree_value)
    }
    index += 2
  }
  found
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
fn parse_name_tree_limits(
  value : @objects.PdfObject,
) -> (Bytes, Bytes) raise PdfDocumentError {
  let limits_array = match value {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Limits"),
        "name tree /Limits entry must be an array",
      )
  }

  if limits_array.length() != 2 {
    raise PdfDocumentError::InvalidNameTree(
      @objects.PdfName::new(b"Limits"),
      "name tree /Limits entry must contain exactly two strings",
    )
  }

  let lower = match limits_array[0] {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Limits"),
        "name tree /Limits values must be strings",
      )
  }
  let upper = match limits_array[1] {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Limits"),
        "name tree /Limits values must be strings",
      )
  }

  if bytes_compare(lower, upper) > 0 {
    raise PdfDocumentError::InvalidNameTree(
      @objects.PdfName::new(b"Limits"),
      "name tree /Limits lower bound must not exceed upper bound",
    )
  }
  (lower, upper)
}

///|
fn bytes_compare(left : Bytes, right : Bytes) -> Int {
  let mut index = 0
  let left_length = left.length()
  let right_length = right.length()
  let limit = if left_length < right_length {
    left_length
  } else {
    right_length
  }

  while index < limit {
    let left_byte = left[index]
    let right_byte = right[index]
    if left_byte < right_byte {
      return -1
    } else if left_byte > right_byte {
      return 1
    }
    index += 1
  }

  if left_length < right_length {
    -1
  } else if left_length > right_length {
    1
  } else {
    0
  }
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
